#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env.deploy}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

require_cmd az

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

OMNISCOPE_PREFIX="${OMNISCOPE_PREFIX:-omniscope-aks-test}"
RG_NAME="${RG_NAME_OVERRIDE:-${OMNISCOPE_PREFIX}-rg}"

echo "About to delete resource group: $RG_NAME"
az group delete --name "$RG_NAME" --yes --no-wait
echo "Deletion started. Check status with:"
echo "az group show -n \"$RG_NAME\" --query properties.provisioningState -o tsv"
