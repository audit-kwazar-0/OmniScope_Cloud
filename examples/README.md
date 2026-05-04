# Примеры Observability для OmniScope Cloud

Здесь — **локальный минимальный стенд**, вдохновлённый подходами из:

- учебного репозитория `observability-zero-to-hero` (день 7: два Go-микросервиса + OTLP + Collector — см. ваш локальный clone),
- архитектурными идеями [`open-telemetry/opentelemetry-demo`](https://github.com/open-telemetry/opentelemetry-demo) (collector-first, единый OTLP ingestion).

Для продакшен-полигона OpenTelemetry используйте **официальный** репозиторий (тяжёлый, полный):

```bash
git clone https://github.com/open-telemetry/opentelemetry-demo.git
cd opentelemetry-demo
make start
# UI http://localhost:8080 — см. Makefile / README апстрима
```

## Что в этом каталоге

| Компонент | Назначение |
|-----------|------------|
| `otel-collector-config.yaml` | Приём OTLP (gRPC/HTTP), batch, экспорт трейсов в Jaeger, метрик — экспорт Prometheus |
| `prometheus.yml` | Скрапинг метрик с Collector (`:8889`) |
| `services/service-a`, `services/service-b` | Два Go-сервиса (Gin + `otelgin` / `otelhttp`), OTLP/HTTP на Collector |
| `docker-compose.yml` | Поднять всё одной командой |

## Запуск

Требования: Docker и Docker Compose v2.

```bash
cd examples
docker compose up --build
```

- Сервис A: http://localhost:8081/hello-a — вызов B: http://localhost:8081/call-b  
- Сервис B: http://localhost:8082/hello-b — вызов A: http://localhost:8082/call-a  
- Jaeger UI: http://localhost:16686  
- Prometheus UI: http://localhost:9090  

Остановка: `docker compose down`.

## Связка с нашим IaC в Azure

Бэкенды (Jaeger/Prometheus здесь — только для **локальной** отладки). В Azure ваш целевой контур — Application Insights / Managed Prometheus / Log Analytics / OpenSearch, как описано в `doc-site/`. Компонент **OpenTelemetry Collector** остаётся тем же паттерном: приложения шлют OTLP на Collector, дальше — экспортеры под ваш облачный стек.
