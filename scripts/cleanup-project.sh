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
WAIT_DELETE="${WAIT_DELETE:-}"

if [[ "${WAIT_DELETE:-}" =~ ^(1|true|yes)$ ]]; then
  echo "WAIT_DELETE=true — дождёмся удаления RG (может занять несколько минут)."
else
  echo "Подсказка: полная очистка перед повторным deploy — WAIT_DELETE=true $0"
fi

if ! az group show --name "$RG_NAME" --output none 2>/dev/null; then
  echo "Resource group не найдена или уже удалена: $RG_NAME — очистка не нужна."
  exit 0
fi

echo "Deleting resource group: $RG_NAME"
az group delete --name "$RG_NAME" --yes --no-wait

if [[ "${WAIT_DELETE:-}" =~ ^(1|true|yes)$ ]]; then
  az group wait --name "$RG_NAME" --deleted || true
  echo "RG $RG_NAME удалена или команда wait завершена."
else
  echo "Deletion started (--no-wait). Status:"
  echo "  az group show -n \"$RG_NAME\" --query properties.provisioningState -o tsv"
  echo "Перед ./scripts/deploy-project.sh дождитесь статуса Deleting→отсутствует, иначе Bicep может упасть."
fi
