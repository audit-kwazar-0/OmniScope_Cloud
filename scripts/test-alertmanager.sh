#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-omniscope}"
ALERTMANAGER_URL="${ALERTMANAGER_URL:-http://alertmanager.${NAMESPACE}.svc.cluster.local:9093}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

require_cmd kubectl

kubectl -n "$NAMESPACE" run alert-test --rm -i --restart=Never --image=curlimages/curl --command -- sh -c "
cat <<'EOF' >/tmp/alerts.json
[
  {
    \"labels\": {
      \"alertname\": \"OmniScopeSyntheticAlert\",
      \"severity\": \"warning\",
      \"namespace\": \"${NAMESPACE}\",
      \"service\": \"service-a\"
    },
    \"annotations\": {
      \"summary\": \"Synthetic alert from test-alertmanager.sh\",
      \"description\": \"End-to-end notification flow test\"
    },
    \"generatorURL\": \"https://omniscope.local/test\"
  }
]
EOF
curl -sS -XPOST -H 'Content-Type: application/json' --data @/tmp/alerts.json ${ALERTMANAGER_URL}/api/v2/alerts
"

echo "Synthetic alert sent to ${ALERTMANAGER_URL}"
echo "Check webhook receiver logs:"
echo "kubectl -n ${NAMESPACE} logs deploy/alert-webhook-receiver --tail=100"
