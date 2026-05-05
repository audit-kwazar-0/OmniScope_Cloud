#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BICEP_DIR="$ROOT_DIR/infra/bicep"

ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env.deploy}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-omniscope-full-$(date +%Y%m%d%H%M%S)}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

require_cmd az
require_cmd jq
require_cmd kubectl
require_cmd docker
require_cmd sed

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
else
  echo "Env file not found: $ENV_FILE" >&2
  echo "Copy .env.deploy.example to .env.deploy and adjust values." >&2
  exit 1
fi

AZ_LOCATION="${AZ_LOCATION:-westeurope}"
OMNISCOPE_PREFIX="${OMNISCOPE_PREFIX:-omniscope-aks-test}"
ALERT_EMAIL="${ALERT_EMAIL:-oncall@example.com}"
DEPLOY_AKS="${DEPLOY_AKS:-true}"
DEPLOY_ACR="${DEPLOY_ACR:-true}"
DEPLOY_MANAGED_PROMETHEUS="${DEPLOY_MANAGED_PROMETHEUS:-true}"
DEPLOY_LOG_EXPORT="${DEPLOY_LOG_EXPORT:-true}"
DEPLOY_AKS_DIAGNOSTICS="${DEPLOY_AKS_DIAGNOSTICS:-true}"
DEPLOY_ALERTMANAGER="${DEPLOY_ALERTMANAGER:-false}"
DEPLOY_GRAFANA_DASHBOARD="${DEPLOY_GRAFANA_DASHBOARD:-true}"
AKS_SYSTEM_VM_SIZE="${AKS_SYSTEM_VM_SIZE:-Standard_B2s_v2}"
AKS_SYSTEM_NODE_COUNT="${AKS_SYSTEM_NODE_COUNT:-1}"
STRESS_CPU_WORKERS="${STRESS_CPU_WORKERS:-2}"
SERVICE_A_TAG="${SERVICE_A_TAG:-latest}"
SERVICE_B_TAG="${SERVICE_B_TAG:-latest}"
ACR_NAME_OVERRIDE="${ACR_NAME_OVERRIDE:-}"
TEAMS_WEBHOOK_URI="${TEAMS_WEBHOOK_URI:-}"
SMTP_FROM="${SMTP_FROM:-}"
SMTP_USERNAME="${SMTP_USERNAME:-}"
SMTP_PASSWORD="${SMTP_PASSWORD:-}"
SMTP_SMARTHOST="${SMTP_SMARTHOST:-smtp.gmail.com:587}"
ALERT_WEBHOOK_URL="${ALERT_WEBHOOK_URL:-}"
KEYVAULT_NAME="${KEYVAULT_NAME:-}"
SMTP_PASSWORD_SECRET_NAME="${SMTP_PASSWORD_SECRET_NAME:-smtp-password}"
DEPLOY_LOKI="${DEPLOY_LOKI:-true}"
LOKI_AZURE_STORAGE_ACCOUNT="${LOKI_AZURE_STORAGE_ACCOUNT:-}"
LOKI_AZURE_STORAGE_CONTAINER="${LOKI_AZURE_STORAGE_CONTAINER:-loki-data}"
LOKI_AZURE_STORAGE_RESOURCE_GROUP="${LOKI_AZURE_STORAGE_RESOURCE_GROUP:-}"
GRAFANA_NAME_OVERRIDE="${GRAFANA_NAME_OVERRIDE:-}"
GRAFANA_DASHBOARD_PATH="${GRAFANA_DASHBOARD_PATH:-$ROOT_DIR/docs/grafana-dashboard.json}"
GRAFANA_ALERTING_DASHBOARD_PATH="${GRAFANA_ALERTING_DASHBOARD_PATH:-$ROOT_DIR/docs/grafana-alerting-dashboard.json}"
GRAFANA_PLATFORM_DASHBOARD_PATH="${GRAFANA_PLATFORM_DASHBOARD_PATH:-$ROOT_DIR/docs/grafana-platform-health-dashboard.json}"
GRAFANA_LOKI_DASHBOARD_PATH="${GRAFANA_LOKI_DASHBOARD_PATH:-$ROOT_DIR/docs/grafana-dashboard0.json}"
if [[ "$GRAFANA_DASHBOARD_PATH" != /* ]]; then
  GRAFANA_DASHBOARD_PATH="$ROOT_DIR/$GRAFANA_DASHBOARD_PATH"
fi
if [[ "$GRAFANA_ALERTING_DASHBOARD_PATH" != /* ]]; then
  GRAFANA_ALERTING_DASHBOARD_PATH="$ROOT_DIR/$GRAFANA_ALERTING_DASHBOARD_PATH"
fi
if [[ "$GRAFANA_PLATFORM_DASHBOARD_PATH" != /* ]]; then
  GRAFANA_PLATFORM_DASHBOARD_PATH="$ROOT_DIR/$GRAFANA_PLATFORM_DASHBOARD_PATH"
fi
if [[ "$GRAFANA_LOKI_DASHBOARD_PATH" != /* ]]; then
  GRAFANA_LOKI_DASHBOARD_PATH="$ROOT_DIR/$GRAFANA_LOKI_DASHBOARD_PATH"
fi

WANT_SMTP=false
if [[ "$DEPLOY_ALERTMANAGER" == "true" ]]; then
  if [[ -n "$SMTP_FROM" || -n "$SMTP_USERNAME" || -n "$SMTP_PASSWORD" ]]; then
    WANT_SMTP=true
  fi
fi

if [[ "$WANT_SMTP" == "true" ]]; then
  if [[ -z "$SMTP_FROM" || -z "$SMTP_USERNAME" ]]; then
    echo "SMTP_FROM and SMTP_USERNAME must be set when SMTP channel is enabled." >&2
    exit 1
  fi
  if [[ -z "$SMTP_PASSWORD" && -n "$KEYVAULT_NAME" && -n "$SMTP_PASSWORD_SECRET_NAME" ]]; then
    echo "Fetching SMTP password from Azure Key Vault..."
    SMTP_PASSWORD="$(az keyvault secret show --vault-name "$KEYVAULT_NAME" --name "$SMTP_PASSWORD_SECRET_NAME" --query value -o tsv)"
  fi
  if [[ -z "$SMTP_PASSWORD" || "$SMTP_PASSWORD" == "null" ]]; then
    echo "SMTP channel requested, but password is missing (set SMTP_PASSWORD or Key Vault secret)." >&2
    exit 1
  fi
fi

echo "[1/8] Azure preflight"
az account show -o table >/dev/null
az provider register --namespace Microsoft.OperationsManagement --wait >/dev/null

TMP_PARAMS="$(mktemp /tmp/omniscope-params.XXXXXX.json)"
cleanup_tmp() {
  rm -f "$TMP_PARAMS"
}
trap cleanup_tmp EXIT

echo "[2/8] Build deployment parameters"
jq \
  --arg prefix "$OMNISCOPE_PREFIX" \
  --arg location "$AZ_LOCATION" \
  --arg alertEmail "$ALERT_EMAIL" \
  --arg vmSize "$AKS_SYSTEM_VM_SIZE" \
  --arg acrOverride "$ACR_NAME_OVERRIDE" \
  --arg webhook "$TEAMS_WEBHOOK_URI" \
  --argjson deployAks "$DEPLOY_AKS" \
  --argjson deployAcr "$DEPLOY_ACR" \
  --argjson deployProm "$DEPLOY_MANAGED_PROMETHEUS" \
  --argjson deployLogExport "$DEPLOY_LOG_EXPORT" \
  --argjson deployAksDiagnostics "$DEPLOY_AKS_DIAGNOSTICS" \
  --argjson nodeCount "$AKS_SYSTEM_NODE_COUNT" \
  --argjson stressWorkers "$STRESS_CPU_WORKERS" \
  '.parameters.prefix.value = $prefix
   | .parameters.location.value = $location
   | .parameters.alertEmail.value = $alertEmail
   | .parameters.deployAks.value = $deployAks
   | .parameters.deployAcr.value = $deployAcr
   | .parameters.deployManagedPrometheus.value = $deployProm
   | .parameters.deployLogExport.value = $deployLogExport
   | .parameters.deployAksDiagnostics.value = $deployAksDiagnostics
   | .parameters.aksSystemVmSize.value = $vmSize
   | .parameters.aksSystemNodeCount.value = $nodeCount
   | .parameters.stressCpuWorkers.value = $stressWorkers
   | .parameters.acrNameOverride.value = $acrOverride
   | .parameters.teamsWebhookUri.value = $webhook' \
  "$BICEP_DIR/parameters.test-aks.json" > "$TMP_PARAMS"

echo "[3/8] Deploy infrastructure (Bicep)"
(
  cd "$BICEP_DIR"
  PARAMS_FILE="$TMP_PARAMS" DEPLOYMENT_NAME="$DEPLOYMENT_NAME" LOCATION="$AZ_LOCATION" ./deploy.sh deploy
)

echo "[4/8] Resolve deployment outputs"
OUTPUTS_JSON="$(az deployment sub show --name "$DEPLOYMENT_NAME" --query properties.outputs -o json)"
RG_NAME="$(jq -r '.resourceGroupName.value' <<<"$OUTPUTS_JSON")"
AKS_NAME="$(jq -r '.aksName.value' <<<"$OUTPUTS_JSON")"
ACR_LOGIN_SERVER="$(jq -r '.acrLoginServer.value' <<<"$OUTPUTS_JSON")"
GRAFANA_URL="$(jq -r '.grafanaUrl.value // empty' <<<"$OUTPUTS_JSON")"

if [[ -z "$RG_NAME" || "$RG_NAME" == "null" || -z "$AKS_NAME" || "$AKS_NAME" == "null" ]]; then
  echo "Failed to resolve RG/AKS outputs from deployment $DEPLOYMENT_NAME" >&2
  exit 1
fi

if [[ "$DEPLOY_LOKI" == "true" ]]; then
  LOKI_STORAGE_RG="$RG_NAME"
  if [[ -n "$LOKI_AZURE_STORAGE_RESOURCE_GROUP" ]]; then
    LOKI_STORAGE_RG="$LOKI_AZURE_STORAGE_RESOURCE_GROUP"
  fi
  if [[ -z "$LOKI_AZURE_STORAGE_ACCOUNT" ]]; then
    LOKI_AZURE_STORAGE_ACCOUNT="$(echo "${OMNISCOPE_PREFIX}loki$(echo "$RG_NAME" | md5sum | cut -c1-6)" | tr -cd 'a-z0-9' | cut -c1-24)"
  fi
  echo "Ensuring Loki Azure Storage account: $LOKI_AZURE_STORAGE_ACCOUNT"
  az storage account create     --name "$LOKI_AZURE_STORAGE_ACCOUNT"     --resource-group "$LOKI_STORAGE_RG"     --location "$AZ_LOCATION"     --sku Standard_LRS     --kind StorageV2     --allow-blob-public-access false >/dev/null
  LOKI_STORAGE_KEY="$(az storage account keys list --resource-group "$LOKI_STORAGE_RG" --account-name "$LOKI_AZURE_STORAGE_ACCOUNT" --query '[0].value' -o tsv)"
  az storage container create     --name "$LOKI_AZURE_STORAGE_CONTAINER"     --account-name "$LOKI_AZURE_STORAGE_ACCOUNT"     --account-key "$LOKI_STORAGE_KEY" >/dev/null
fi

echo "[5/8] Connect kubectl to AKS"
az aks get-credentials --resource-group "$RG_NAME" --name "$AKS_NAME" --overwrite-existing >/dev/null
kubectl get nodes

if [[ -z "$ACR_LOGIN_SERVER" || "$ACR_LOGIN_SERVER" == "null" ]]; then
  echo "ACR login server output is empty. Set DEPLOY_ACR=true or use public images." >&2
  exit 1
fi

echo "[6/8] Build and push service images"
ACR_NAME="${ACR_LOGIN_SERVER%%.azurecr.io}"
az acr login --name "$ACR_NAME"

docker build -t "${ACR_LOGIN_SERVER}/omniscope/service-a:${SERVICE_A_TAG}" "$ROOT_DIR/examples/services/service-a"
docker push "${ACR_LOGIN_SERVER}/omniscope/service-a:${SERVICE_A_TAG}"
docker build -t "${ACR_LOGIN_SERVER}/omniscope/service-b:${SERVICE_B_TAG}" "$ROOT_DIR/examples/services/service-b"
docker push "${ACR_LOGIN_SERVER}/omniscope/service-b:${SERVICE_B_TAG}"

echo "[7/8] Deploy workloads to AKS"
kubectl apply -f "$ROOT_DIR/examples/kubernetes/namespace.yaml"
kubectl apply -f "$ROOT_DIR/examples/kubernetes/otel/"
if [[ "$DEPLOY_LOKI" == "true" ]]; then
  kubectl -n omniscope create secret generic loki-storage \
    --from-literal=LOKI_S3_BUCKET="$LOKI_S3_BUCKET" \
    --from-literal=LOKI_S3_REGION="$LOKI_S3_REGION" \
    --from-literal=LOKI_S3_ENDPOINT="$LOKI_S3_ENDPOINT" \
    --from-literal=AWS_ACCESS_KEY_ID="$LOKI_AWS_ACCESS_KEY_ID" \
    --from-literal=AWS_SECRET_ACCESS_KEY="$LOKI_AWS_SECRET_ACCESS_KEY" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -f "$ROOT_DIR/examples/kubernetes/loki/"
  kubectl -n omniscope rollout status deploy/loki --timeout=300s
  kubectl -n omniscope rollout status daemonset/promtail --timeout=300s
fi
sed "s|__ACR_LOGIN_SERVER__|${ACR_LOGIN_SERVER}|g" "$ROOT_DIR/examples/kubernetes/apps/service-a.yaml" | \
  sed "s|:latest|:${SERVICE_A_TAG}|g" | kubectl apply -f -
sed "s|__ACR_LOGIN_SERVER__|${ACR_LOGIN_SERVER}|g" "$ROOT_DIR/examples/kubernetes/apps/service-b.yaml" | \
  sed "s|:latest|:${SERVICE_B_TAG}|g" | kubectl apply -f -
kubectl -n omniscope rollout status deploy/service-a --timeout=300s
kubectl -n omniscope rollout status deploy/service-b --timeout=300s

if [[ "$DEPLOY_ALERTMANAGER" == "true" ]]; then
  echo "Deploying Alertmanager resources..."
  if [[ -z "$ALERT_WEBHOOK_URL" ]]; then
    kubectl apply -f "$ROOT_DIR/examples/kubernetes/alertmanager/20-webhook-receiver.yaml"
    kubectl -n omniscope rollout status deploy/alert-webhook-receiver --timeout=180s
    ALERT_WEBHOOK_URL="http://alert-webhook-receiver.omniscope.svc.cluster.local:8080"
  fi
  ALERT_EMAIL_TO="$ALERT_EMAIL" \
  SMTP_FROM="$SMTP_FROM" \
  SMTP_USERNAME="$SMTP_USERNAME" \
  SMTP_PASSWORD="$SMTP_PASSWORD" \
  SMTP_SMARTHOST="$SMTP_SMARTHOST" \
  ALERT_WEBHOOK_URL="$ALERT_WEBHOOK_URL" \
  "$ROOT_DIR/scripts/create-alertmanager-secret.sh"
  kubectl apply -f "$ROOT_DIR/examples/kubernetes/alertmanager/10-alertmanager.yaml"
  kubectl -n omniscope rollout status deploy/alertmanager --timeout=300s
fi

if [[ "$DEPLOY_GRAFANA_DASHBOARD" == "true" ]]; then
  # shellcheck source=scripts/grafana-sync.sh disable=SC1091
  source "$ROOT_DIR/scripts/grafana-sync.sh"
  omniscope_grafana_dashboard_sync || exit 1
fi

echo "[8/8] Run smoke test"
kubectl -n omniscope run smoke-curl --rm -i --restart=Never --image=curlimages/curl --command -- sh -c \
  "curl -s http://service-a:8081/hello-a && echo && curl -s http://service-a:8081/call-b && echo && curl -s http://service-b:8082/hello-b && echo"

cat <<EOF

Deployment complete.
DEPLOYMENT_NAME=$DEPLOYMENT_NAME
RESOURCE_GROUP=$RG_NAME
AKS_NAME=$AKS_NAME
ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER
GRAFANA_URL=$GRAFANA_URL
EOF
