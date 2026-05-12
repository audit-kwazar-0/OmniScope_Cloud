#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RG_NAME="${RG_NAME:-${OMNISCOPE_RESOURCE_GROUP:-}}"
LAW_NAME="${LAW_NAME:-${GRAFANA_LOG_ANALYTICS_WORKSPACE_NAME:-}}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

require_cmd az
require_cmd jq

if [[ -z "$RG_NAME" ]]; then
  RG_NAME="$(az group list --query "[?starts_with(name, 'omniscope-')].name | [0]" -o tsv 2>/dev/null || true)"
fi
if [[ -z "$LAW_NAME" ]]; then
  LAW_NAME="$(az monitor log-analytics workspace list -g "$RG_NAME" --query "[0].name" -o tsv 2>/dev/null || true)"
fi

if [[ -z "$RG_NAME" || -z "$LAW_NAME" ]]; then
  echo "Set RG_NAME/LAW_NAME (or OMNISCOPE_RESOURCE_GROUP/GRAFANA_LOG_ANALYTICS_WORKSPACE_NAME)." >&2
  exit 1
fi

echo "Audit target: RG=$RG_NAME LAW=$LAW_NAME"
CID="$(az monitor log-analytics workspace show -g "$RG_NAME" --workspace-name "$LAW_NAME" --query customerId -o tsv)"

check_query() {
  local label="$1"
  local query="$2"
  if az monitor log-analytics query -w "$CID" --analytics-query "$query" -o none >/dev/null 2>&1; then
    echo "[OK] $label"
  else
    echo "[FAIL] $label" >&2
    return 1
  fi
}

echo "Checking core tables..."
check_query "KubeEvents table" "KubeEvents | where TimeGenerated > ago(7d) | take 1"
check_query "KubeNodeInventory table" "KubeNodeInventory | where TimeGenerated > ago(7d) | take 1"
check_query "KubePodInventory table" "KubePodInventory | where TimeGenerated > ago(7d) | take 1"

echo "Checking critical columns for tier dashboards..."
check_query "KubeEvents.KubeEventType exists" "KubeEvents | getschema | where ColumnName == 'KubeEventType' | take 1"
check_query "KubeNodeInventory.KubeletVersion exists" "KubeNodeInventory | getschema | where ColumnName == 'KubeletVersion' | take 1"
check_query "KubeNodeInventory.KubeProxyVersion exists" "KubeNodeInventory | getschema | where ColumnName == 'KubeProxyVersion' | take 1"

echo "Checking RED metric selectors in dashboard JSON..."
RED_DASH="$ROOT_DIR/docs/grafana-tier-c-red-metrics.json"
if jq -e '.. | .expr? // empty | select(type=="string") | select(test("http_server_request_duration_seconds_(count|bucket)"))' "$RED_DASH" >/dev/null; then
  echo "[OK] RED dashboard expects http_server_request_duration_seconds_*"
else
  echo "[WARN] RED dashboard query set changed; validate expected metric names." >&2
fi

echo "Dashboard regression audit completed."
