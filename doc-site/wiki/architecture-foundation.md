# Архитектурный фундамент (Azure Native & OSS) {#architecture}

## Метрики

**Рекомендуемый источник метрик в единой модели: Azure Managed Prometheus (AMP).**

В него можно входить через:

- Prometheus scrape (например, внутри AKS)
- remote_write от Prometheus/OTel Collector
- (для части сигналов) экспорт/выравнивание из Azure Monitor metrics

## Логи

Двухконтурная схема:

- **Log Analytics Workspace** — “hot logs” (быстрый поиск, корреляция при расследовании)
- **OpenSearch/Elasticsearch** — “deep search” и long-term ретеншн

Практика:

1. включить `Diagnostic Settings` на ресурсы → отправка в Log Analytics
2. экспортировать данные из Log Analytics в long-term
3. ingestion pipeline нормализует поля (`service.name`, `trace_id`, severity и т.д.)
