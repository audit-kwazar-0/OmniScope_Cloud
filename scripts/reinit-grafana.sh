#!/usr/bin/env bash
# Recreate/update Managed Grafana datasource "Loki" (from current Loki LB IP)
# and re-import dashboards configured in .env.deploy (same as deploy-project step [7+]).
#
# Usage:
#   export OMNISCOPE_RESOURCE_GROUP=<your-rg>   # or RESOURCE_GROUP=
#   ./scripts/reinit-grafana.sh
# Or:
#   ./scripts/reinit-grafana.sh <resource-group-name>
#
# Optional:
#   GRAFANA_LOKI_RECREATE=true   # delete Loki datasource by name before create/update
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

require_cmd az
require_cmd jq
require_cmd kubectl

ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env.deploy}"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
else
  echo "Env file not found: $ENV_FILE" >&2
  exit 1
fi

# Paths and Grafana toggles (match deploy-project defaults)
GRAFANA_DASHBOARD_PATH="${GRAFANA_DASHBOARD_PATH:-docs/grafana-dashboard.json}"
GRAFANA_ALERTING_DASHBOARD_PATH="${GRAFANA_ALERTING_DASHBOARD_PATH:-docs/grafana-alerting-dashboard.json}"
GRAFANA_PLATFORM_DASHBOARD_PATH="${GRAFANA_PLATFORM_DASHBOARD_PATH:-docs/grafana-platform-health-dashboard.json}"
GRAFANA_LOKI_DASHBOARD_PATH="${GRAFANA_LOKI_DASHBOARD_PATH:-docs/grafana-dashboard0.json}"
if [[ "${GRAFANA_LOKI_LEGACY_DASHBOARD_PATH-unset}" == "unset" ]]; then
  GRAFANA_LOKI_LEGACY_DASHBOARD_PATH="$ROOT_DIR/docs/grafana-dashboard0-legacy.json"
fi
[[ "$GRAFANA_DASHBOARD_PATH" != /* ]] && GRAFANA_DASHBOARD_PATH="$ROOT_DIR/$GRAFANA_DASHBOARD_PATH"
[[ "$GRAFANA_ALERTING_DASHBOARD_PATH" != /* ]] && GRAFANA_ALERTING_DASHBOARD_PATH="$ROOT_DIR/$GRAFANA_ALERTING_DASHBOARD_PATH"
[[ "$GRAFANA_PLATFORM_DASHBOARD_PATH" != /* ]] && GRAFANA_PLATFORM_DASHBOARD_PATH="$ROOT_DIR/$GRAFANA_PLATFORM_DASHBOARD_PATH"
[[ "$GRAFANA_LOKI_DASHBOARD_PATH" != /* ]] && GRAFANA_LOKI_DASHBOARD_PATH="$ROOT_DIR/$GRAFANA_LOKI_DASHBOARD_PATH"
if [[ -n "$GRAFANA_LOKI_LEGACY_DASHBOARD_PATH" && "$GRAFANA_LOKI_LEGACY_DASHBOARD_PATH" != /* ]]; then
  GRAFANA_LOKI_LEGACY_DASHBOARD_PATH="$ROOT_DIR/$GRAFANA_LOKI_LEGACY_DASHBOARD_PATH"
fi

DEPLOY_GRAFANA_DASHBOARD="${DEPLOY_GRAFANA_DASHBOARD:-true}"
DEPLOY_LOKI="${DEPLOY_LOKI:-true}"
GRAFANA_ENSURE_AZURE_MONITOR_DS="${GRAFANA_ENSURE_AZURE_MONITOR_DS:-true}"
GRAFANA_AZURE_SUBSCRIPTION_ID="${GRAFANA_AZURE_SUBSCRIPTION_ID:-}"
GRAFANA_AZURE_MONITOR_DS_NAME="${GRAFANA_AZURE_MONITOR_DS_NAME:-Azure Monitor}"
GRAFANA_AZURE_MONITOR_RECREATE="${GRAFANA_AZURE_MONITOR_RECREATE:-false}"
GRAFANA_AZURE_MONITOR_AUTH_TYPE="${GRAFANA_AZURE_MONITOR_AUTH_TYPE:-currentuser}"
GRAFANA_AZURE_TENANT_ID="${GRAFANA_AZURE_TENANT_ID:-}"
GRAFANA_IMPORT_TIER_DASHBOARDS="${GRAFANA_IMPORT_TIER_DASHBOARDS:-true}"
GRAFANA_LOG_ANALYTICS_WORKSPACE_NAME="${GRAFANA_LOG_ANALYTICS_WORKSPACE_NAME:-omniscope-aks-test-law}"
GRAFANA_AKS_NAME="${GRAFANA_AKS_NAME:-}"
GRAFANA_TIER_DASHBOARD_PATHS="${GRAFANA_TIER_DASHBOARD_PATHS:-}"
GRAFANA_NAME_OVERRIDE="${GRAFANA_NAME_OVERRIDE:-}"
AZ_LOCATION="${AZ_LOCATION:-westeurope}"

RG_NAME="${OMNISCOPE_RESOURCE_GROUP:-${RESOURCE_GROUP:-}}"
if [[ -z "$RG_NAME" ]]; then
  RG_NAME="${1:-}"
fi
if [[ -z "$RG_NAME" || "$RG_NAME" == "-h" || "$RG_NAME" == "--help" ]]; then
  echo "Set OMNISCOPE_RESOURCE_GROUP or RESOURCE_GROUP in $ENV_FILE, or pass Azure resource group as first argument." >&2
  echo "Managed Grafana instance must live in this resource group." >&2
  exit 1
fi

AKS_NAME="${AKS_NAME_OVERRIDE:-}"
if [[ -z "$AKS_NAME" ]]; then
  mapfile -t _aks <<<"$(az aks list -g "$RG_NAME" --query "[].name" -o tsv)"
  if [[ ${#_aks[@]} -eq 0 ]]; then
    echo "No AKS cluster found in resource group $RG_NAME. Set AKS_NAME_OVERRIDE." >&2
    exit 1
  fi
  if [[ ${#_aks[@]} -gt 1 ]]; then
    echo "Multiple AKS clusters in $RG_NAME: ${_aks[*]}. Set AKS_NAME_OVERRIDE to one name." >&2
    exit 1
  fi
  AKS_NAME="${_aks[0]}"
fi

echo "Connecting kubectl → $RG_NAME / $AKS_NAME"
az aks get-credentials --resource-group "$RG_NAME" --name "$AKS_NAME" --overwrite-existing >/dev/null

export OMNISCOPE_ROOT_DIR="$ROOT_DIR"

# shellcheck source=grafana-sync.sh
source "$ROOT_DIR/scripts/grafana-sync.sh"

omniscope_grafana_dashboard_sync

echo "Grafana sync finished (Loki + Azure Monitor datasources + dashboard import). Open Managed Grafana → Connections → Data sources to verify."
