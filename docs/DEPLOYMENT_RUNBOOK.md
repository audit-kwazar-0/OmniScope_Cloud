# Deployment Runbook

## 0. Fast path (full project deploy)

From repo root:

```bash
cp .env.deploy.example .env.deploy
# edit .env.deploy (at minimum: ALERT_EMAIL)
./scripts/deploy-project.sh
```

What this script does:
1. Azure preflight + provider registration.
2. Bicep infra deployment (`infra/bicep/deploy.sh deploy`).
3. Resolves deployment outputs (RG/AKS/ACR).
4. Builds and pushes `omniscope/service-a` and `omniscope/service-b`.
5. Applies Kubernetes manifests.
6. Imports `docs/grafana-dashboard.json` into Managed Grafana (optional, enabled by default).
7. Runs in-cluster smoke test.

Cleanup:

```bash
./scripts/cleanup-project.sh
```

Enable in-cluster Alertmanager (optional):
- Set `DEPLOY_ALERTMANAGER=true` in `.env.deploy`
- Provide `SMTP_FROM`, `SMTP_USERNAME`, `SMTP_PASSWORD` (Gmail app password recommended)
- Run `./scripts/deploy-project.sh` again (or apply only alertmanager resources)

Grafana dashboard auto-import settings:
- `DEPLOY_GRAFANA_DASHBOARD=true`
- `GRAFANA_DASHBOARD_PATH=docs/grafana-dashboard.json`
- optional `GRAFANA_NAME_OVERRIDE=<managed-grafana-name>`

## 1. Prerequisites

- Azure CLI authenticated: `az login`
- `kubectl`, Docker installed
- Correct subscription selected: `az account show -o table`
- Provider registration (once per subscription):

```bash
az provider register --namespace Microsoft.OperationsManagement --wait
```

## 2. Deploy infrastructure (Bicep)

From repo root:

```bash
cd infra/bicep
jq '.parameters.alertEmail.value = "you@example.com"' parameters.test-aks.json > /tmp/omniscope-test-params.json
export PARAMS_FILE=/tmp/omniscope-test-params.json
export DEPLOYMENT_NAME="omniscope-fulltest-$(date +%Y%m%d%H%M)"
./deploy.sh deploy
```

Get outputs:

```bash
az deployment sub show --name "$DEPLOYMENT_NAME" --query "properties.outputs" -o json
```

## 3. Connect kubectl

```bash
RG="omniscope-aks-test-rg"
AKS="omniscope-aks-test-aks"
az aks get-credentials --resource-group "$RG" --name "$AKS" --overwrite-existing
kubectl get nodes
```

## 4. Build and push service images

```bash
cd examples
ACR_LOGIN_SERVER="<acrLoginServer>"   # from deployment output
az acr login --name "${ACR_LOGIN_SERVER%%.azurecr.io}"

docker build -t "${ACR_LOGIN_SERVER}/omniscope/service-a:latest" services/service-a
docker push "${ACR_LOGIN_SERVER}/omniscope/service-a:latest"

docker build -t "${ACR_LOGIN_SERVER}/omniscope/service-b:latest" services/service-b
docker push "${ACR_LOGIN_SERVER}/omniscope/service-b:latest"
```

## 5. Deploy to AKS

From repo root:

```bash
kubectl apply -f examples/kubernetes/namespace.yaml
kubectl apply -f examples/kubernetes/otel/

sed "s|__ACR_LOGIN_SERVER__|${ACR_LOGIN_SERVER}|g" examples/kubernetes/apps/service-a.yaml | kubectl apply -f -
sed "s|__ACR_LOGIN_SERVER__|${ACR_LOGIN_SERVER}|g" examples/kubernetes/apps/service-b.yaml | kubectl apply -f -

kubectl -n omniscope rollout status deploy/service-a --timeout=240s
kubectl -n omniscope rollout status deploy/service-b --timeout=240s
kubectl -n omniscope get pods,svc
```

## 6. Smoke test

In-cluster test:

```bash
kubectl -n omniscope run smoke-curl --rm -i --restart=Never --image=curlimages/curl --command -- sh -c \
  "curl -s http://service-a:8081/hello-a && echo && curl -s http://service-a:8081/call-b && echo && curl -s http://service-b:8082/hello-b && echo"
```

Expected:
- `/hello-a` returns hello from service-a
- `/call-b` returns payload from service-b via service-a
- `/hello-b` returns hello from service-b

## 7. Optional Gateway API

If controller is installed:

```bash
kubectl apply -f examples/kubernetes/gateway/
kubectl -n omniscope get gateway,httproute
```

Set correct `gatewayClassName` in `examples/kubernetes/gateway/10-gateway.yaml`.

## 8. Optional Alertmanager (in-cluster)

Create/update SMTP-backed config Secret:

```bash
SMTP_FROM="your-sender@gmail.com" \
SMTP_USERNAME="your-sender@gmail.com" \
SMTP_PASSWORD="app-password" \
ALERT_EMAIL_TO="tempb59@gmail.com" \
./scripts/create-alertmanager-secret.sh
```

Deploy Alertmanager:

```bash
kubectl apply -f examples/kubernetes/alertmanager/10-alertmanager.yaml
kubectl -n omniscope rollout status deploy/alertmanager --timeout=240s
kubectl -n omniscope get svc alertmanager
```

## 9. Cleanup

```bash
az group delete --name omniscope-aks-test-rg --yes --no-wait
az group show -n omniscope-aks-test-rg --query properties.provisioningState -o tsv
```
