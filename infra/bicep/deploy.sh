#!/usr/bin/env bash
# Deploy / validate OmniScope Bicep at subscription scope.
# Usage:
#   ./deploy.sh validate              # bicep build only (no Azure call)
#   ./deploy.sh what-if               # dry-run against subscription (needs az login)
#   ./deploy.sh deploy                # create deployment
#   ./deploy.sh deploy-debug          # same + --debug on Azure CLI
#
# Env:
#   PARAMS_FILE   path to parameters JSON (default: ./parameters.local.json if exists, else ./parameters.example.json)
#   DEPLOYMENT_NAME  ARM deployment name (default: omniscope-bicep-<timestamp>)
#   LOCATION      Azure region for metadata (default: westeurope or value from params file — here fixed via CLI)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

MODE="${1:-validate}"
PARAMS_FILE="${PARAMS_FILE:-}"
if [[ -z "$PARAMS_FILE" ]]; then
  if [[ -f "$SCRIPT_DIR/parameters.local.json" ]]; then
    PARAMS_FILE="$SCRIPT_DIR/parameters.local.json"
  else
    PARAMS_FILE="$SCRIPT_DIR/parameters.example.json"
  fi
fi

if [[ ! -f "$PARAMS_FILE" ]]; then
  echo "Parameters file not found: $PARAMS_FILE" >&2
  echo "Copy parameters.example.json to parameters.local.json and set alertEmail, prefix, location." >&2
  exit 1
fi

TEMPLATE="$SCRIPT_DIR/main.bicep"
LOCATION="${LOCATION:-westeurope}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-omniscope-bicep-$(date +%Y%m%d%H%M%S)}"

echo "[deploy.sh] mode=$MODE params=$PARAMS_FILE deployment=$DEPLOYMENT_NAME location=$LOCATION"

validate() {
  az bicep build --file "$TEMPLATE"
  echo "[deploy.sh] bicep build OK"
}

what_if() {
  validate
  az deployment sub what-if \
    --location "$LOCATION" \
    --name "$DEPLOYMENT_NAME" \
    --template-file "$TEMPLATE" \
    --parameters "@$PARAMS_FILE" \
    --no-pretty-print
}

deploy() {
  local debug_flag=()
  if [[ "${1:-}" == "--debug" ]]; then
    debug_flag=(--debug)
  fi
  validate
  az deployment sub create "${debug_flag[@]}" \
    --location "$LOCATION" \
    --name "$DEPLOYMENT_NAME" \
    --template-file "$TEMPLATE" \
    --parameters "@$PARAMS_FILE"
}

case "$MODE" in
  validate)
    validate
    ;;
  what-if)
    what_if
    ;;
  deploy)
    deploy
    echo "[deploy.sh] show deployment: az deployment sub show --name $DEPLOYMENT_NAME"
    ;;
  deploy-debug)
    deploy --debug
    ;;
  *)
    echo "Usage: $0 validate|what-if|deploy|deploy-debug" >&2
    exit 1
    ;;
esac
