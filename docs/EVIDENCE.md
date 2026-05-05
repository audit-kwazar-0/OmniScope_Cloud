# Evidence Guide (DoD)

Use this checklist to prove deployment and observability are operational.

## 1) IaC deployment succeeded

```bash
az deployment sub show --name "$DEPLOYMENT_NAME" \
  --query "{name:name,state:properties.provisioningState,outputs:properties.outputs}" -o json
```

Capture:
- `state: Succeeded`
- outputs include AKS, ACR, Grafana, EventHub IDs/URLs

## 2) AKS health

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

Capture:
- node Ready
- workloads in `omniscope` Running

## 3) Application e2e + traces

```bash
curl -s http://localhost:8081/hello-a && echo
curl -s http://localhost:8081/call-b && echo
```

Capture:
- successful JSON responses from both calls

In Application Insights:
- transaction search with chain `service-a /call-b -> service-b /hello-b`

## 4) Metrics in Grafana

Import dashboard JSON:
- `docs/grafana-dashboard.json`

PromQL quick checks:

```promql
sum(rate(omniscope_processed_messages_total[5m])) by (service)
```

```promql
sum(rate(omniscope_processing_errors_total[5m])) by (service)
```

Capture:
- non-zero processed rate after traffic
- error metric visible (non-zero or zero baseline)

## 5) Logs in LAW (+ OpenSearch pipeline path)

KQL:

```kusto
ContainerLogV2
| where TimeGenerated > ago(30m)
| where KubernetesNamespace == "omniscope"
| project TimeGenerated, KubernetesPodName, LogMessage
| order by TimeGenerated desc
```

```kusto
ContainerLogV2
| where TimeGenerated > ago(30m)
| where KubernetesNamespace == "omniscope"
| where LogMessage has "ERROR" or LogMessage matches regex @"\b5\d\d\b"
| project TimeGenerated, KubernetesPodName, LogMessage
| order by TimeGenerated desc
```

OpenSearch/Elastic query (after EventHub consumer setup):

```text
kubernetes.namespace_name:"omniscope" AND (log:"ERROR" OR http.status_code:[500 TO 599])
```

## 6) Alerts and action routing

```bash
az monitor scheduled-query list --resource-group "$RG" -o table
az monitor action-group list --resource-group "$RG" -o table
```

Expected alert rules:
- `<prefix>-ag-aks-cpu-high`
- `<prefix>-ag-omniscope-errors`

Expected action receivers:
- email
- optional webhook (if `teamsWebhookUri` is set)
