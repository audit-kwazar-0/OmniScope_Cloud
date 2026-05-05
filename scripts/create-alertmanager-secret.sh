#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-omniscope}"
ALERT_EMAIL_TO="${ALERT_EMAIL_TO:-tempb59@gmail.com}"
SMTP_FROM="${SMTP_FROM:-}"
SMTP_USERNAME="${SMTP_USERNAME:-}"
SMTP_PASSWORD="${SMTP_PASSWORD:-}"
SMTP_SMARTHOST="${SMTP_SMARTHOST:-smtp.gmail.com:587}"
ALERT_WEBHOOK_URL="${ALERT_WEBHOOK_URL:-}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

require_cmd kubectl

HAS_SMTP=true
if [[ -z "$SMTP_FROM" || -z "$SMTP_USERNAME" || -z "$SMTP_PASSWORD" ]]; then
  HAS_SMTP=false
fi
HAS_WEBHOOK=true
if [[ -z "$ALERT_WEBHOOK_URL" ]]; then
  HAS_WEBHOOK=false
fi

if [[ "$HAS_SMTP" == "false" && "$HAS_WEBHOOK" == "false" ]]; then
  echo "Provide at least one notification channel:" >&2
  echo "1) SMTP_FROM + SMTP_USERNAME + SMTP_PASSWORD" >&2
  echo "2) ALERT_WEBHOOK_URL" >&2
  exit 1
fi

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

TMP_CFG="$(mktemp /tmp/alertmanager-config.XXXXXX.yml)"
cleanup_tmp() {
  rm -f "$TMP_CFG"
}
trap cleanup_tmp EXIT

cat >"$TMP_CFG" <<EOF
global:
  resolve_timeout: 5m

route:
  receiver: omniscope-webhook
  group_by: ['alertname', 'namespace']
  group_wait: 10s
  group_interval: 1m
  repeat_interval: 30m

receivers:
EOF

if [[ "$HAS_SMTP" == "true" ]]; then
  cat >>"$TMP_CFG" <<EOF
  - name: omniscope-email
    email_configs:
      - to: '${ALERT_EMAIL_TO}'
        from: '${SMTP_FROM}'
        smarthost: '${SMTP_SMARTHOST}'
        auth_username: '${SMTP_USERNAME}'
        auth_password: '${SMTP_PASSWORD}'
        require_tls: true
        send_resolved: true
EOF
fi

if [[ "$HAS_WEBHOOK" == "true" ]]; then
  cat >>"$TMP_CFG" <<EOF
  - name: omniscope-webhook
    webhook_configs:
      - url: '${ALERT_WEBHOOK_URL}'
        send_resolved: true
EOF
else
  sed -i "s/receiver: omniscope-webhook/receiver: omniscope-email/" "$TMP_CFG"
fi

kubectl create secret generic alertmanager-config \
  --namespace "$NAMESPACE" \
  --from-file=alertmanager.yml="$TMP_CFG" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "alertmanager-config secret applied in namespace ${NAMESPACE}"
