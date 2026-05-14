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

OMNISCOPE_IAC="${OMNISCOPE_IAC:-bicep}"
PULUMI_STACK="${PULUMI_STACK:-dev}"

if [[ "$OMNISCOPE_IAC" == "pulumi" ]] && command -v pulumi >/dev/null 2>&1; then
  if ( cd "$ROOT_DIR/infra/pulumi" && pulumi stack select "$PULUMI_STACK" >/dev/null 2>&1 ); then
    echo "OMNISCOPE_IAC=pulumi — running pulumi destroy --yes --stack $PULUMI_STACK"
    ( cd "$ROOT_DIR/infra/pulumi" && pulumi destroy --yes --stack "$PULUMI_STACK" ) || true
  else
    echo "Pulumi stack $PULUMI_STACK not found — skipping pulumi destroy."
  fi
fi

OMNISCOPE_PREFIX="${OMNISCOPE_PREFIX:-omniscope-aks-test}"
RG_NAME="${RG_NAME_OVERRIDE:-${OMNISCOPE_PREFIX}-rg}"
WAIT_DELETE="${WAIT_DELETE:-}"

if [[ "${WAIT_DELETE:-}" =~ ^(1|true|yes)$ ]]; then
  echo "WAIT_DELETE=true — waiting for RG deletion (may take several minutes)."
else
  echo "Tip: full cleanup before redeploy — WAIT_DELETE=true $0"
fi

if ! az group show --name "$RG_NAME" --output none 2>/dev/null; then
  echo "Resource group not found or already deleted: $RG_NAME — nothing to clean up."
  exit 0
fi

echo "Deleting resource group: $RG_NAME"
az group delete --name "$RG_NAME" --yes --no-wait

if [[ "${WAIT_DELETE:-}" =~ ^(1|true|yes)$ ]]; then
  az group wait --name "$RG_NAME" --deleted || true
  echo "RG $RG_NAME deleted or wait command finished."
else
  echo "Deletion started (--no-wait). Status:"
  echo "  az group show -n \"$RG_NAME\" --query properties.provisioningState -o tsv"
  echo "Before ./scripts/deploy-project.sh wait until Deleting is gone; otherwise redeploy may fail."
fi
