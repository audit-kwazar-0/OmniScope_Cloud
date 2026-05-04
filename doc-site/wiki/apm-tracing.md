# APM: Distributed Tracing {#apm}

## Application Insights + OpenTelemetry

Принципы:

- все сервисы используют OpenTelemetry SDK
- на входе/выходе HTTP/gRPC пропагация tracecontext
- OTel Collector делает enrichment (service.name, environment, version, k8s tags, resource ids)

Цепочка:

- Trace (OTLP) → OTel Collector → Application Insights
- Trace_id дублируется в логах (через корреляцию/инструментацию)
- Grafana/OpenSearch/Log Analytics используют `trace_id` для “следа”
