# Full Stack мониторинг (IaaS & PaaS) {#full-stack}

## VM / OS

- `Azure Monitor Agent (AMA)` собирает системные метрики и платформенные логи
- логи → Log Analytics
- метрики → Prometheus-совместимый путь до AMP (либо через встроенные integration, либо через OTel/node-exporter pipeline)

## PaaS

- `Diagnostic Settings` включаются для категорий `logs`, `metrics`, `audit`
- логи в Log Analytics
- метрики в AMP (либо через интеграции/экспорт, либо через единый OTel pipeline)

## K8s (AKS)

### Метрики

- `kube-state-metrics` + node exporter +/или Prometheus operator → метрики в AMP

### Логи stdout/stderr

- подход: логирование контейнеров в stdout/stderr
- collector (Fluent Bit/OTel Collector daemonset) читает контейнерные логи и отправляет в:
  - Log Analytics (hot)
  - (опционально) long-term ingestion в OpenSearch

## Serverless (Azure Functions)

Сигналы:

- latency/duration (p50/p95/p99)
- error rate (exceptions, non-2xx downstream)
- retry/throttle/cold-start индикаторы (насколько доступно)

Реализация:

- instrument через Application Insights и/или OpenTelemetry SDK
- логи runtime → Log Analytics
- трассы/зависимости → Application Insights (или OTel → AI)
