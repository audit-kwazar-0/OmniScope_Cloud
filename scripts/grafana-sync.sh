# shellcheck shell=bash
# Grafana dashboard import + Loki datasource (Azure Managed Grafana).
# Sourced by deploy-project.sh and reinit-grafana.sh.

omniscope_grafana_dashboard_sync() {
  local PROM_DS_UID LOKI_DS_UID LOKI_EXTERNAL_IP LOKI_DS_NAME LOKI_DEF LOKI_DS_EXISTS
  local TMP_GRAFANA_JSON DASHBOARD_FILE

  if [[ "$DEPLOY_GRAFANA_DASHBOARD" != "true" ]]; then
    return 0
  fi

  echo "Managed Grafana: import dashboards / ensure Loki datasource..."
  local GRAFANA_NAME="$GRAFANA_NAME_OVERRIDE"
  if [[ -z "$GRAFANA_NAME" ]]; then
    GRAFANA_NAME="$(az resource list -g "$RG_NAME" --resource-type Microsoft.Dashboard/grafana --query "[0].name" -o tsv)"
  fi
  if [[ -z "$GRAFANA_NAME" || "$GRAFANA_NAME" == "null" ]]; then
    echo "Managed Grafana resource not found in $RG_NAME (set GRAFANA_NAME_OVERRIDE)." >&2
    return 1
  fi

  PROM_DS_UID="$(az grafana data-source list --resource-group "$RG_NAME" --name "$GRAFANA_NAME" --query "[?type=='prometheus']|[0].uid" -o tsv)"
  LOKI_DS_UID=""
  if [[ "$DEPLOY_LOKI" == "true" ]]; then
    LOKI_EXTERNAL_IP="$(kubectl -n omniscope get svc loki -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
    if [[ -z "$LOKI_EXTERNAL_IP" ]]; then
      echo "Loki LoadBalancer IP is not ready. Skipping Loki datasource/dashboard import." >&2
    else
      LOKI_DS_NAME="${GRAFANA_LOKI_DS_NAME:-Loki}"
      LOKI_DEF="$(jq -cn --arg n "$LOKI_DS_NAME" --arg url "http://${LOKI_EXTERNAL_IP}:3100" \
        '{name:$n,type:"loki",access:"proxy",url:$url,jsonData:{maxLines:1000}}')"
      if [[ "${GRAFANA_LOKI_RECREATE:-false}" == "true" ]]; then
        if az grafana data-source show --resource-group "$RG_NAME" --name "$GRAFANA_NAME" --data-source "$LOKI_DS_NAME" &>/dev/null; then
          echo "Deleting existing Loki datasource for clean recreate (GRAFANA_LOKI_RECREATE=true)..."
          az grafana data-source delete --resource-group "$RG_NAME" --name "$GRAFANA_NAME" --data-source "$LOKI_DS_NAME" >/dev/null
        fi
      fi
      LOKI_DS_EXISTS="$(az grafana data-source list --resource-group "$RG_NAME" --name "$GRAFANA_NAME" --query "[?name=='${LOKI_DS_NAME}']|length(@)" -o tsv)"
      if [[ "$LOKI_DS_EXISTS" == "1" ]]; then
        az grafana data-source update --resource-group "$RG_NAME" --name "$GRAFANA_NAME" --data-source "$LOKI_DS_NAME" --definition "$LOKI_DEF" >/dev/null
      else
        az grafana data-source create --resource-group "$RG_NAME" --name "$GRAFANA_NAME" --definition "$LOKI_DEF" >/dev/null
      fi
      LOKI_DS_UID="$(az grafana data-source list --resource-group "$RG_NAME" --name "$GRAFANA_NAME" \
        --query "[?type=='loki' && name=='${LOKI_DS_NAME}']|[0].uid" -o tsv)"
    fi
  fi

  for DASHBOARD_FILE in "$GRAFANA_DASHBOARD_PATH" "$GRAFANA_ALERTING_DASHBOARD_PATH" "$GRAFANA_PLATFORM_DASHBOARD_PATH" "$GRAFANA_LOKI_DASHBOARD_PATH"; do
    if [[ ! -f "$DASHBOARD_FILE" ]]; then
      echo "Dashboard file not found: $DASHBOARD_FILE" >&2
      return 1
    fi
    TMP_GRAFANA_JSON="$(mktemp /tmp/omniscope-dashboard.XXXXXX.json)"
    if [[ "$DASHBOARD_FILE" == "$GRAFANA_LOKI_DASHBOARD_PATH" ]]; then
      if [[ -z "$LOKI_DS_UID" || "$LOKI_DS_UID" == "null" ]]; then
        echo "Skipping Loki dashboard import because Loki datasource is unavailable."
        rm -f "$TMP_GRAFANA_JSON"
        continue
      fi
      jq --arg ds "$LOKI_DS_UID" '
        del(.__inputs)
        | .templating.list = (.templating.list | map(
            if has("datasource")
            then .datasource.uid = $ds
            else .
            end
          ))
        | .panels = (.panels | map(
            if has("datasource")
            then .datasource.uid = $ds
            else .
            end
          ))
      ' "$DASHBOARD_FILE" > "$TMP_GRAFANA_JSON"
    else
      if [[ -z "$PROM_DS_UID" || "$PROM_DS_UID" == "null" ]]; then
        echo "Skipping Prometheus dashboard import ($DASHBOARD_FILE) because Prometheus datasource is unavailable."
        rm -f "$TMP_GRAFANA_JSON"
        continue
      fi
      jq --arg ds "$PROM_DS_UID" '
        del(.__inputs)
        | .panels = (.panels | map(
            if has("datasource")
            then .datasource.uid = $ds
            else .
            end
          ))
      ' "$DASHBOARD_FILE" > "$TMP_GRAFANA_JSON"
    fi
    az grafana dashboard import \
      --resource-group "$RG_NAME" \
      --name "$GRAFANA_NAME" \
      --definition "$TMP_GRAFANA_JSON" \
      --overwrite true >/dev/null
    rm -f "$TMP_GRAFANA_JSON"
  done
}
