#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
K6_SCRIPT="${K6_SCRIPT:-$ROOT_DIR/tests/load/k6-omniscope.js}"
BASE_URL="${BASE_URL:-http://localhost:8081}"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/tests/load/results}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d%H%M%S)}"
SUMMARY_FILE="$OUT_DIR/k6-summary-$RUN_ID.json"
BASELINE_FILE="${BASELINE_FILE:-$ROOT_DIR/tests/load/baseline.json}"
COMPARE_BASELINE="${COMPARE_BASELINE:-true}"
ALLOW_REGRESSION_PERCENT="${ALLOW_REGRESSION_PERCENT:-10}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

require_cmd k6
require_cmd jq

if [[ ! -f "$K6_SCRIPT" ]]; then
  echo "k6 script not found: $K6_SCRIPT" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

echo "Running load test against $BASE_URL"
echo "Summary file: $SUMMARY_FILE"

K6_SUMMARY_EXPORT="$SUMMARY_FILE" k6 run -e BASE_URL="$BASE_URL" "$K6_SCRIPT"

echo "Collecting metrics from summary..."
P95_MS="$(jq '.metrics.http_req_duration.values["p(95)"] // 0' "$SUMMARY_FILE")"
P99_MS="$(jq '.metrics.http_req_duration.values["p(99)"] // 0' "$SUMMARY_FILE")"
ERROR_RATE="$(jq '.metrics.http_req_failed.values.rate // 0' "$SUMMARY_FILE")"
RPS="$(jq '.metrics.http_reqs.values.rate // 0' "$SUMMARY_FILE")"

cat <<EOF
Load test summary
- p95: ${P95_MS} ms
- p99: ${P99_MS} ms
- error rate: ${ERROR_RATE}
- requests/sec: ${RPS}
EOF

if [[ "$COMPARE_BASELINE" == "true" && -f "$BASELINE_FILE" ]]; then
  BASE_P95="$(jq '.p95_ms // 0' "$BASELINE_FILE")"
  if awk "BEGIN { exit !($BASE_P95 > 0) }"; then
    LIMIT="$(awk -v b="$BASE_P95" -v p="$ALLOW_REGRESSION_PERCENT" 'BEGIN { print b * (1 + p/100) }')"
    if awk "BEGIN { exit !($P95_MS > $LIMIT) }"; then
      echo "Regression detected: p95 ${P95_MS} ms exceeds baseline limit ${LIMIT} ms" >&2
      exit 1
    fi
    echo "Baseline check passed (baseline p95=${BASE_P95} ms, limit=${LIMIT} ms)."
  fi
fi

LATEST_FILE="$OUT_DIR/k6-summary-latest.json"
cp "$SUMMARY_FILE" "$LATEST_FILE"

echo "Done. Latest summary: $LATEST_FILE"
