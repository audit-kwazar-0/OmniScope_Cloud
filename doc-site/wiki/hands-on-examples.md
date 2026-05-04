# Примеры OpenTelemetry на AKS {#hands-on-examples}

В каталоге `examples/` — **collector-first** сценарий для кластера **Azure Kubernetes Service** (без Docker Compose):

- два Go-сервиса (**Gin** + `otelgin` / **HTTP-клиент** с `otelhttp`), OTLP/HTTP на Collector внутри кластера;
- манифесты **Kubernetes** (`examples/kubernetes/`): Jaeger, OpenTelemetry Collector, Deployments сервисов; образы приложений публикуются в **Azure Container Registry** (см. `examples/README.md`, `examples/docs/AKS-ACR-CICD.md`);
- в Bicep при необходимости создаётся **ACR** и выдаётся роль **AcrPull** kubelet-идентичности AKS (`infra/bicep`).

Полноразмерный эталон — апстрим [`open-telemetry/opentelemetry-demo`](https://github.com/open-telemetry/opentelemetry-demo): `make start`, UI на `localhost:8080`.
