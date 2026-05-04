# Grafana: multi-datasource {#grafana}

## Концепция “Observability Overview”

Один главный дашборд с фильтрами:

- `env`, `region`, `service`, `resource_type`
- (для AKS) `namespace`, `pod`

Блоки панелей:

- Service Health: error rate, latency, saturation (AMP/Azure Metrics)
- Infra/Platform: CPU/mem/disk/net (AMP + Azure Monitor)
- Logs: top exceptions/messages (OpenSearch) + drill-down в Log Analytics
- Traces: ссылки на views Application Insights + корреляция по `trace_id`
- Correlation: “одна кнопка” от метрики/лога к трассе

## Multi-datasource

Grafana подключает:

- Azure Monitor (logs/search)
- AMP (Prometheus metrics)
- OpenSearch (deep search)
- Application Insights (traces)
