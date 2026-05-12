# shellcheck shell=bash
# Grafana dashboard import + Loki + Azure Monitor datasource (Azure Managed Grafana).
# Sourced by deploy-project.sh and reinit-grafana.sh.

omniscope_grafana_dashboard_sync() {
  local PROM_DS_UID LOKI_DS_UID LOKI_EXTERNAL_IP LOKI_DS_NAME LOKI_DEF LOKI_DS_EXISTS
  local TEMPO_DS_UID PYRO_DS_UID
  local TMP_GRAFANA_JSON DASHBOARD_FILE is_loki_dash _lp
  local AM_NAME AM_DEF AM_EXISTS SUBSCRIPTION_ID AM_AUTH TENANT_ID

  if [[ "$DEPLOY_GRAFANA_DASHBOARD" != "true" ]]; then
    return 0
  fi

  echo "Managed Grafana: import dashboards / ensure Loki + Azure Monitor datasources..."
  local GRAFANA_NAME="$GRAFANA_NAME_OVERRIDE"
  if [[ -z "$GRAFANA_NAME" ]]; then
    GRAFANA_NAME="$(az resource list -g "$RG_NAME" --resource-type Microsoft.Dashboard/grafana --query "[0].name" -o tsv)"
  fi
  if [[ -z "$GRAFANA_NAME" || "$GRAFANA_NAME" == "null" ]]; then
    echo "Managed Grafana resource not found in $RG_NAME (set GRAFANA_NAME_OVERRIDE)." >&2
    return 1
  fi

  if ! az grafana data-source list --resource-group "$RG_NAME" --name "$GRAFANA_NAME" --output none 2>/dev/null; then
    echo "Managed Grafana API access denied. Assign role Grafana Admin to your identity on the Grafana resource (Bicep can set this via grafanaAdminObjectId)." >&2
    return 1
  fi

  PROM_DS_UID="$(az grafana data-source list --resource-group "$RG_NAME" --name "$GRAFANA_NAME" --query "[?type=='prometheus']|[0].uid" -o tsv)"

  if [[ "${GRAFANA_ENSURE_AZURE_MONITOR_DS:-true}" == "true" ]]; then
    SUBSCRIPTION_ID="${GRAFANA_AZURE_SUBSCRIPTION_ID:-}"
    if [[ -z "$SUBSCRIPTION_ID" ]]; then
      SUBSCRIPTION_ID="$(az account show --query id -o tsv 2>/dev/null || true)"
    fi
    if [[ -z "$SUBSCRIPTION_ID" ]]; then
      echo "Azure Monitor datasource: subscription id not found (set GRAFANA_AZURE_SUBSCRIPTION_ID or run az login)." >&2
    else
      AM_NAME="${GRAFANA_AZURE_MONITOR_DS_NAME:-Azure Monitor}"
      # Managed Grafana + Entra: "currentuser" matches UI "Current user" (queries use the signed-in identity).
      # Use "msi" after Bicep grants Monitoring Reader to Grafana MSI (see observability-base.bicep).
      AM_AUTH="${GRAFANA_AZURE_MONITOR_AUTH_TYPE:-currentuser}"
      TENANT_ID="${GRAFANA_AZURE_TENANT_ID:-}"
      if [[ -z "$TENANT_ID" ]]; then
        TENANT_ID="$(az account show --query tenantId -o tsv 2>/dev/null || true)"
      fi
      AM_DEF="$(jq -cn --arg n "$AM_NAME" --arg sid "$SUBSCRIPTION_ID" --arg auth "$AM_AUTH" --arg tid "$TENANT_ID" \
        '{name:$n,type:"grafana-azure-monitor-datasource",access:"proxy",jsonData:({azureAuthType:$auth,subscriptionId:$sid,cloudName:"azuremonitor"} + (if ($tid|length > 0) then {tenantId:$tid} else {} end))}')"
      if [[ "${GRAFANA_AZURE_MONITOR_RECREATE:-false}" == "true" ]]; then
        if az grafana data-source show --resource-group "$RG_NAME" --name "$GRAFANA_NAME" --data-source "$AM_NAME" &>/dev/null; then
          echo "Deleting existing Azure Monitor datasource for clean recreate (GRAFANA_AZURE_MONITOR_RECREATE=true)..."
          az grafana data-source delete --resource-group "$RG_NAME" --name "$GRAFANA_NAME" --data-source "$AM_NAME" >/dev/null
        fi
      fi
      AM_EXISTS="$(az grafana data-source list --resource-group "$RG_NAME" --name "$GRAFANA_NAME" --query "[?name=='${AM_NAME}']|length(@)" -o tsv)"
      if [[ "$AM_EXISTS" == "1" ]]; then
        az grafana data-source update --resource-group "$RG_NAME" --name "$GRAFANA_NAME" --data-source "$AM_NAME" --definition "$AM_DEF" >/dev/null
      else
        az grafana data-source create --resource-group "$RG_NAME" --name "$GRAFANA_NAME" --definition "$AM_DEF" >/dev/null
      fi
      echo "Azure Monitor datasource configured in Grafana: $AM_NAME (auth=$AM_AUTH, subscription $SUBSCRIPTION_ID)."
    fi
  fi

  if [[ "${GRAFANA_ENSURE_TEMPO_DS:-true}" == "true" ]]; then
    local TEMPO_DS_NAME TEMPO_URL TEMPO_DEF TEMPO_EXISTS
    TEMPO_DS_NAME="${GRAFANA_TEMPO_DS_NAME:-Tempo}"
    TEMPO_URL="${GRAFANA_TEMPO_URL:-http://tempo.omniscope.svc.cluster.local:3200}"
    TEMPO_DEF="$(jq -cn --arg n "$TEMPO_DS_NAME" --arg url "$TEMPO_URL" \
      '{name:$n,type:"tempo",access:"proxy",url:$url,jsonData:{httpMethod:"GET",serviceMap:{datasourceUid:""}}}')"
    TEMPO_EXISTS="$(az grafana data-source list --resource-group "$RG_NAME" --name "$GRAFANA_NAME" --query "[?name=='${TEMPO_DS_NAME}']|length(@)" -o tsv)"
    if [[ "$TEMPO_EXISTS" == "1" ]]; then
      az grafana data-source update --resource-group "$RG_NAME" --name "$GRAFANA_NAME" --data-source "$TEMPO_DS_NAME" --definition "$TEMPO_DEF" >/dev/null
    else
      az grafana data-source create --resource-group "$RG_NAME" --name "$GRAFANA_NAME" --definition "$TEMPO_DEF" >/dev/null
    fi
    TEMPO_DS_UID="$(az grafana data-source list --resource-group "$RG_NAME" --name "$GRAFANA_NAME" \
      --query "[?type=='tempo' && name=='${TEMPO_DS_NAME}']|[0].uid" -o tsv)"
  fi

  if [[ "${GRAFANA_ENSURE_PYROSCOPE_DS:-true}" == "true" ]]; then
    local PYRO_DS_NAME PYRO_URL PYRO_DEF PYRO_EXISTS
    PYRO_DS_NAME="${GRAFANA_PYROSCOPE_DS_NAME:-Pyroscope}"
    PYRO_URL="${GRAFANA_PYROSCOPE_URL:-http://pyroscope.omniscope.svc.cluster.local:4040}"
    PYRO_DEF="$(jq -cn --arg n "$PYRO_DS_NAME" --arg url "$PYRO_URL" \
      '{name:$n,type:"grafana-pyroscope-datasource",access:"proxy",url:$url,jsonData:{}}')"
    PYRO_EXISTS="$(az grafana data-source list --resource-group "$RG_NAME" --name "$GRAFANA_NAME" --query "[?name=='${PYRO_DS_NAME}']|length(@)" -o tsv)"
    if [[ "$PYRO_EXISTS" == "1" ]]; then
      az grafana data-source update --resource-group "$RG_NAME" --name "$GRAFANA_NAME" --data-source "$PYRO_DS_NAME" --definition "$PYRO_DEF" >/dev/null
    else
      az grafana data-source create --resource-group "$RG_NAME" --name "$GRAFANA_NAME" --definition "$PYRO_DEF" >/dev/null
    fi
  fi

  LOKI_DS_UID=""
  if [[ "$DEPLOY_LOKI" == "true" ]]; then
    LOKI_EXTERNAL_IP="$(kubectl -n omniscope get svc loki -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
    if [[ -z "$LOKI_EXTERNAL_IP" ]]; then
      echo "Loki LoadBalancer IP is not ready. Skipping Loki datasource/dashboard import." >&2
    else
      LOKI_DS_NAME="${GRAFANA_LOKI_DS_NAME:-Loki}"
      LOKI_DEF="$(jq -cn --arg n "$LOKI_DS_NAME" --arg url "http://${LOKI_EXTERNAL_IP}:3100" --arg tempo "${TEMPO_DS_UID:-}" \
        '{name:$n,type:"loki",access:"proxy",url:$url,jsonData:{maxLines:1000,derivedFields:[{name:"TraceID",matcherRegex:"(?:trace_id|traceId|traceID)\"?[:= ]\"?([A-Fa-f0-9]{16,32})",url:"$${__value.raw}"}]}}
         | if ($tempo|length) > 0 then .jsonData.derivedFields[0].datasourceUid = $tempo else . end')"
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
    if [[ -n "$LOKI_EXTERNAL_IP" && ( -z "$LOKI_DS_UID" || "$LOKI_DS_UID" == "null" ) ]]; then
      echo "Failed to create or read Loki datasource in Managed Grafana (check API errors above)." >&2
      return 1
    fi
  fi

  local -a LOKI_DASH_PATHS=("$GRAFANA_LOKI_DASHBOARD_PATH")
  if [[ -n "${GRAFANA_LOKI_LEGACY_DASHBOARD_PATH:-}" && -f "$GRAFANA_LOKI_LEGACY_DASHBOARD_PATH" ]]; then
    if [[ "$GRAFANA_LOKI_LEGACY_DASHBOARD_PATH" != "$GRAFANA_LOKI_DASHBOARD_PATH" ]]; then
      LOKI_DASH_PATHS+=("$GRAFANA_LOKI_LEGACY_DASHBOARD_PATH")
    fi
  elif [[ -n "${GRAFANA_LOKI_LEGACY_DASHBOARD_PATH:-}" ]]; then
    echo "Legacy Loki dashboard path set but file missing, skip: $GRAFANA_LOKI_LEGACY_DASHBOARD_PATH" >&2
  fi

  local -a DASH_IMPORT_ORDER=(
    "$GRAFANA_DASHBOARD_PATH"
    "$GRAFANA_ALERTING_DASHBOARD_PATH"
    "$GRAFANA_PLATFORM_DASHBOARD_PATH"
  )
  DASH_IMPORT_ORDER+=("${LOKI_DASH_PATHS[@]}")

  for DASHBOARD_FILE in "${DASH_IMPORT_ORDER[@]}"; do
    is_loki_dash=false
    for _lp in "${LOKI_DASH_PATHS[@]}"; do
      if [[ "$DASHBOARD_FILE" == "$_lp" ]]; then
        is_loki_dash=true
        break
      fi
    done

    if [[ "${OBSERVABILITY_LOKI_ONLY:-false}" == "true" && "$is_loki_dash" == "false" ]]; then
      if [[ "${GRAFANA_IMPORT_PROMETHEUS_DASHBOARDS_IN_LOKI_MODE:-false}" != "true" ]]; then
        echo "OBSERVABILITY_LOKI_ONLY=true — skipping Prometheus-oriented dashboard: $DASHBOARD_FILE"
        continue
      fi
    fi

    if [[ ! -f "$DASHBOARD_FILE" ]]; then
      echo "Dashboard file not found: $DASHBOARD_FILE" >&2
      return 1
    fi

    TMP_GRAFANA_JSON="$(mktemp /tmp/omniscope-dashboard.XXXXXX.json)"
    if [[ "$is_loki_dash" == "true" ]]; then
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

  if [[ "${GRAFANA_IMPORT_TIER_DASHBOARDS:-true}" != "true" ]]; then
    return 0
  fi

  local R="${OMNISCOPE_ROOT_DIR:-}"
  if [[ -z "$R" && -z "${GRAFANA_TIER_DASHBOARD_PATHS:-}" ]]; then
    echo "Tier dashboards: set OMNISCOPE_ROOT_DIR (export from deploy/reinit) or GRAFANA_TIER_DASHBOARD_PATHS to absolute paths." >&2
    return 0
  fi

  local AM_DS_NAME="${GRAFANA_AZURE_MONITOR_DS_NAME:-Azure Monitor}"
  AM_DS_UID="$(az grafana data-source list --resource-group "$RG_NAME" --name "$GRAFANA_NAME" \
    --query "[?type=='grafana-azure-monitor-datasource' && name=='${AM_DS_NAME}']|[0].uid" -o tsv)"
  PROM_DS_UID="$(az grafana data-source list --resource-group "$RG_NAME" --name "$GRAFANA_NAME" \
    --query "[?type=='prometheus']|[0].uid" -o tsv)"
  local TEMPO_DS_NAME="${GRAFANA_TEMPO_DS_NAME:-Tempo}"
  TEMPO_DS_UID="$(az grafana data-source list --resource-group "$RG_NAME" --name "$GRAFANA_NAME" \
    --query "[?type=='tempo' && name=='${TEMPO_DS_NAME}']|[0].uid" -o tsv)"
  local PYRO_DS_NAME="${GRAFANA_PYROSCOPE_DS_NAME:-Pyroscope}"
  PYRO_DS_UID="$(az grafana data-source list --resource-group "$RG_NAME" --name "$GRAFANA_NAME" \
    --query "[?type=='grafana-pyroscope-datasource' && name=='${PYRO_DS_NAME}']|[0].uid" -o tsv)"
  local TIER_SUB="${GRAFANA_AZURE_SUBSCRIPTION_ID:-}"
  if [[ -z "$TIER_SUB" ]]; then
    TIER_SUB="$(az account show --query id -o tsv 2>/dev/null || true)"
  fi
  local LAW_W="${GRAFANA_LOG_ANALYTICS_WORKSPACE_NAME:-omniscope-aks-test-law}"
  local LAW_ARM=""
  if [[ -n "$TIER_SUB" ]]; then
    LAW_ARM="/subscriptions/${TIER_SUB}/resourceGroups/${RG_NAME}/providers/Microsoft.OperationalInsights/workspaces/${LAW_W}"
  fi
  local AKS_RES="${GRAFANA_AKS_NAME:-}"
  if [[ -z "$AKS_RES" ]]; then
    AKS_RES="$(az aks list -g "$RG_NAME" --query "[0].name" -o tsv 2>/dev/null || true)"
  fi

  local -a TIER_FILES
  if [[ -n "${GRAFANA_TIER_DASHBOARD_PATHS:-}" ]]; then
    read -r -a TIER_FILES <<<"$GRAFANA_TIER_DASHBOARD_PATHS"
  else
    TIER_FILES=(
      "$R/docs/grafana-tier-a-executive.json"
      "$R/docs/grafana-tier-b-noc.json"
      "$R/docs/grafana-tier-c-workload.json"
      "$R/docs/grafana-tier-c-red-metrics.json"
      "$R/docs/grafana-tier-c-traces-profiles.json"
      "$R/docs/grafana-tier-d-k8s-platform.json"
      "$R/docs/grafana-tier-e-logs.json"
      "$R/docs/grafana-tier-f-cost.json"
    )
  fi

  local tier_f
  for tier_f in "${TIER_FILES[@]}"; do
    if [[ "$tier_f" != /* ]]; then
      if [[ -z "$R" ]]; then
        echo "Tier dashboard path must be absolute if OMNISCOPE_ROOT_DIR is unset: $tier_f" >&2
        continue
      fi
      tier_f="$R/${tier_f}"
    fi
    if [[ ! -f "$tier_f" ]]; then
      echo "Tier dashboard file not found, skip: $tier_f" >&2
      continue
    fi
    if grep -q '\${DS_LOKI}' "$tier_f" && [[ -z "$LOKI_DS_UID" || "$LOKI_DS_UID" == "null" ]]; then
      echo "Tier dashboard needs Loki datasource, skip: $tier_f" >&2
      continue
    fi
    if grep -q '\${DS_AM}' "$tier_f" && [[ -z "$AM_DS_UID" || "$AM_DS_UID" == "null" ]]; then
      echo "Tier dashboard needs Azure Monitor datasource, skip: $tier_f" >&2
      continue
    fi
    if [[ -z "$LAW_ARM" ]] && grep -q '__LOG_ANALYTICS_ARM_ID__' "$tier_f"; then
      echo "Tier dashboard needs subscription id / Log Analytics ARM id, skip: $tier_f" >&2
      continue
    fi
    if grep -q '\${DS_PROMETHEUS}' "$tier_f" && [[ -z "$PROM_DS_UID" || "$PROM_DS_UID" == "null" ]]; then
      echo "Tier dashboard needs Prometheus datasource, skip: $tier_f" >&2
      continue
    fi
    if grep -q '\${DS_TEMPO}' "$tier_f" && [[ -z "$TEMPO_DS_UID" || "$TEMPO_DS_UID" == "null" ]]; then
      echo "Tier dashboard needs Tempo datasource, skip: $tier_f" >&2
      continue
    fi
    if grep -q '\${DS_PYROSCOPE}' "$tier_f" && [[ -z "$PYRO_DS_UID" || "$PYRO_DS_UID" == "null" ]]; then
      echo "Tier dashboard needs Pyroscope datasource, skip: $tier_f" >&2
      continue
    fi

    TMP_GRAFANA_JSON="$(mktemp /tmp/omniscope-tier-dash.XXXXXX.json)"
    sed -e "s|__LOG_ANALYTICS_ARM_ID__|${LAW_ARM}|g" \
      -e "s|__AKS_NAME__|${AKS_RES}|g" \
      -e "s|__RESOURCE_GROUP__|${RG_NAME}|g" \
      "$tier_f" | jq --arg am "${AM_DS_UID:-}" --arg loki "${LOKI_DS_UID:-}" --arg prom "${PROM_DS_UID:-}" --arg tempo "${TEMPO_DS_UID:-}" --arg pyro "${PYRO_DS_UID:-}" '
      def patch_ds:
        walk(
          if type == "object" and has("datasource") and (.datasource | type) == "object" and (.datasource | has("uid")) then
            .datasource.uid |= if . == "${DS_AM}" then $am elif . == "${DS_LOKI}" then $loki elif . == "${DS_PROMETHEUS}" then $prom elif . == "${DS_TEMPO}" then $tempo elif . == "${DS_PYROSCOPE}" then $pyro else . end
          else . end
        );
      patch_ds
      | if (.templating? != null) and (.templating.list? != null) then
          .templating.list = (.templating.list | map(
              if has("datasource") and (.datasource | type) == "object" and (.datasource | has("uid"))
              then .datasource.uid |= if . == "${DS_AM}" then $am elif . == "${DS_LOKI}" then $loki elif . == "${DS_PROMETHEUS}" then $prom elif . == "${DS_TEMPO}" then $tempo elif . == "${DS_PYROSCOPE}" then $pyro else . end
              else . end
            ))
        else . end
      | del(.__inputs)
    ' >"$TMP_GRAFANA_JSON"

    az grafana dashboard import \
      --resource-group "$RG_NAME" \
      --name "$GRAFANA_NAME" \
      --definition "$TMP_GRAFANA_JSON" \
      --overwrite true >/dev/null
    rm -f "$TMP_GRAFANA_JSON"
    echo "Imported tier dashboard: $tier_f"
  done
}
