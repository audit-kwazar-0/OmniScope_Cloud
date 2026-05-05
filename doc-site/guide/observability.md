# Observability Model

## Metrics

- Source: AKS + OTel metrics
- Store: Azure Monitor Workspace (Managed Prometheus)
- Viz: Managed Grafana

Custom app metrics emitted by services:

- `omniscope_processed_messages_total`
- `omniscope_processing_errors_total`

## Logs

- Primary: Log Analytics Workspace
- Export path: LAW Data Export -> Event Hub
- Downstream: OpenSearch/Elastic consumer (outside current repo)

KQL baseline:

```kusto
ContainerLogV2
| where TimeGenerated > ago(30m)
| where KubernetesNamespace == "omniscope"
| project TimeGenerated, KubernetesPodName, LogMessage
| order by TimeGenerated desc
```

## Traces / APM

- App instrumentation: OpenTelemetry SDK in `service-a` and `service-b`
- Export: OTLP -> OTel Collector -> Application Insights
- Trace chain target: `service-a /call-b -> service-b /hello-b`
