# OmniScope Cloud Observability (PZU) — Эталон

Этот документ описывает эталонную систему Observability для крупной финансовой организации в облаке Azure с использованием:
- Azure Native (Azure Monitor / AMA / Diagnostic Settings / Managed Prometheus / Application Insights)
- OSS-стека (Prometheus-совместимые источники, OpenSearch/Elasticsearch)
- OpenTelemetry (корреляция метрик/логов/трасс)
- Grafana (multi-datasource)
- Enterprise Alerting (Action Groups + каналы + ITSM)
- IaC (Terraform)

<a id="observability"></a>

## Architecture overview

### Потоки данных (Data Flow)

```mermaid
flowchart LR
  subgraph Azure["Azure Resources (IaaS/PaaS/AKS/Serverless)"]
    AMA["Azure Monitor Agent (VM/OS)"]
    DSET["Diagnostic Settings (PaaS + платформенные логи)"]
    KSM["K8s: kube-state-metrics/node-exporter + app metrics"]
    KLOGS["K8s logs: stdout/stderr pipeline (Fluent Bit/OTel logs)"]
    OTF["Functions: OTel/AI instrumentation + runtime signals"]
  end

  subgraph Core["Observability Core"]
    AMP["Azure Managed Prometheus (AMP)"]
    LAW["Log Analytics Workspace (hot + быстрый поиск)"]
    OTelC["OpenTelemetry Collector (OTLP ingress/egress + enrichment)"]
    AI["Application Insights (traces + dependencies)"]
    OS["OpenSearch/Elasticsearch (long-term + deep search)"]
    GRA["Grafana (multi-datasource dashboards)"]
  end

  subgraph LongTermExport["Экспорт в long-term"]
    EXP["Экспорт из Log Analytics (EventHub/Storage/Sink)"]
    ING["Ingestion в OpenSearch (pipelines + ILM)"]
  end

  Azure -->|metrics| AMP
  Azure -->|logs (hot)| LAW
  Azure -->|OTLP traces/metrics| OTelC
  OTelC -->|metrics| AMP
  OTelC -->|traces| AI
  LAW --> EXP --> ING --> OS

  AMP --> GRA
  LAW --> GRA
  OS --> GRA
  AI --> GRA
```

## Unified data contract (как обеспечиваем корреляцию)

Минимальный контракт контекстов (лейблы/поля), чтобы строить “след” по инциденту:

- `environment` (`prod`, `stage`, `dev`)
- `service.name` (единое имя сервиса)
- `service.version` (версия)
- `resource_id` (Azure resource id)
- `region`
- Для K8s: `k8s_cluster`, `namespace`, `pod`, `container`
- Для трасс: `trace_id` (и пропагация W3C tracecontext)

## 1) Архитектурный фундамент (Azure Native & OSS)

<a id="architecture"></a>

### Метрики

**Рекомендуемый источник метрик в единой модели: Azure Managed Prometheus (AMP).**

В него можно входить через:
- Prometheus scrape (например, внутри AKS)
- remote_write от Prometheus/OTel Collector
- (для части сигналов) экспорт/выравнивание из Azure Monitor metrics

### Логи

Двухконтурная схема:
- **Log Analytics Workspace** — “hot logs” (быстрый поиск, корреляция при расследовании)
- **OpenSearch/Elasticsearch** — “deep search” и long-term ретеншн

Практика:
1) включить `Diagnostic Settings` на ресурсы → отправка в Log Analytics  
2) экспортировать данные из Log Analytics в long-term  
3) ingestion pipeline нормализует поля (`service.name`, `trace_id`, severity и т.д.)

## 2) Автоматическая регистрация новых ресурсов мониторингом (Azure API подход)

<a id="auto-registration"></a>

Для enterprise-масштаба рекомендуем стандартный механизм: **Azure Policy** + (при необходимости) **Event Grid/Functions**.

### Путь A (primary): Azure Policy (DeployIfNotExists)

Идея:
- назначить policy assignment на уровень Subscription / Management Group
- policy автоматически создает/включает `Diagnostic Settings` и маршрутизацию в нужные sink’и
- политика применяется к новым ресурсам и к ресурсам при изменениях (если включить соответствующие параметры)

### Путь B (secondary): Event-driven (Activity Log → Event Grid → Function)

Если нужно “регистрировать” не только Diagnostic Settings, но и, например:
- автоматическое связывание ресурсов с ITSM командами/assignment groups
- обновление конфигурации OTel routing

Тогда:
- подписка на события изменений через Activity Log → Event Grid
- Azure Function читает event, затем через Resource Graph получает сведения о ресурсе
- Function выполняет идемпотентные операции (создание связей/метаданных/вызов ARM REST при необходимости)

## 3) Full Stack мониторинг (IaaS & PaaS)

<a id="full-stack"></a>

### VM / OS
- `Azure Monitor Agent (AMA)` собирает системные метрики и платформенные логи
- логи → Log Analytics
- метрики → Prometheus-совместимый путь до AMP (либо через встроенные integration, либо через OTel/node-exporter pipeline)

### PaaS
- `Diagnostic Settings` включаются для категорий `logs`, `metrics`, `audit`
- логи в Log Analytics
- метрики в AMP (либо через интеграции/экспорт, либо через единый OTel pipeline)

## 4) K8s (AKS)

### Метрики
- `kube-state-metrics` + node exporter +/или Prometheus operator → метрики в AMP

### Логи stdout/stderr
- подход: логирование контейнеров в stdout/stderr
- collector (Fluent Bit/OTel Collector daemonset) читает контейнерные логи и отправляет в:
  - Log Analytics (hot)
  - (опционально) long-term ingestion в OpenSearch

## 5) Serverless (Azure Functions)

Сигналы:
- latency/duration (p50/p95/p99)
- error rate (exceptions, non-2xx downstream)
- retry/throttle/cold-start индикаторы (насколько доступно)

Реализация:
- instrument через Application Insights и/или OpenTelemetry SDK
- логи runtime → Log Analytics
- трассы/зависимости → Application Insights (или OTel → AI)

## 6) APM: Distributed Tracing (Application Insights + OpenTelemetry)

<a id="apm"></a>

Принципы:
- все сервисы используют OpenTelemetry SDK
- на входе/выходе HTTP/gRPC пропагация tracecontext
- OTel Collector делает enrichment (service.name, environment, version, k8s tags, resource ids)

Цепочка:
- Trace (OTLP) → OTel Collector → Application Insights
- Trace_id дублируется в логах (через корреляцию/инструментацию)
- Grafana/OpenSearch/Log Analytics используют `trace_id` для “следа”

## 7) Visualization: единый Grafana dashboard (multi-datasource)

<a id="grafana"></a>

### Концепция “Observability Overview”
Один главный дашборд с фильтрами:
- `env`, `region`, `service`, `resource_type`
- (для AKS) `namespace`, `pod`

Блоки панелей:
- Service Health: error rate, latency, saturation (AMP/Azure Metrics)
- Infra/Platform: CPU/mem/disk/net (AMP + Azure Monitor)
- Logs: top exceptions/messages (OpenSearch) + drill-down в Log Analytics
- Traces: ссылки на views Application Insights + корреляция по `trace_id`
- Correlation: “одна кнопка” от метрики/лога к трассе

### Multi-datasource
Grafana подключает:
- Azure Monitor (logs/search)
- AMP (Prometheus metrics)
- OpenSearch (deep search)
- Application Insights (traces)

## 8) Integrations & Alerting (Enterprise level)

<a id="alerting-itsm"></a>

### Схема оповещений
- единые rules в Azure Monitor Alerts и/или Grafana Alerting (в зависимости от политики)
- маршрутизация через `Action Group`
- каналы: MS Teams, Email, SMS через шлюзы
- RBAC ограничивает доступ к правилам/дашбордам (Azure AD groups)

### ITSM: автоматическое создание инцидентов

Паттерн:
1) Logic App получает payload алерта (from Action Group / webhook)
2) нормализует данные (severity, service, environment, fingerprints)
3) вызывает ITSM API:
   - ServiceNow: создание Incident
   - Jira: создание Issue
4) хранит `external incident key` для идемпотентности

Минимальный пример полей Incident (концептуально):
- `short_description`: `${service} ${alert_name} @ ${environment}`
- `severity`: mapping из severity алерта
- `assignment_group`: по tags/service owner
- `symptoms`: топ-лог-линии + ссылка на Grafana panel
- `source`: rule id / dashboard link

## 9) IaC через Terraform (модульная структура + Diagnostic Settings)

<a id="iac-terraform"></a>

### Структура модулей

```text
terraform/
  modules/
    observability-core/
      log-analytics/
      managed-prometheus/
      open-search/
      application-insights/
      otel/
      grafana/
    policy-diagnostics/
    alerting/
      action-groups/
      logic-apps-itsm/
  envs/
    prod/
      main.tf
      subscription.tfvars
```

### Diagnostic Settings для “всех типов ресурсов”

В Terraform сложнее “покрыть все resource types” без инвентаризации и учёта изменений.
Рекомендация: **Azure Policy** вместо ручного перечисления.

Концептуальный пример policy skeleton (idea):

```json
{
  "mode": "All",
  "policyRule": {
    "if": {
      "field": "type",
      "in": [
        "Microsoft.Compute/virtualMachines",
        "Microsoft.Web/sites",
        "Microsoft.Sql/servers",
        "Microsoft.ContainerService/managedClusters"
      ]
    },
    "then": {
      "effect": "DeployIfNotExists",
      "details": {
        "type": "Microsoft.Insights/diagnosticSettings",
        "deployment": {
          "properties": {
            "workspaceId": "<log-analytics-id>",
            "eventhubAuthRuleId": "<optional-eventhub-id>"
          }
        }
      }
    }
  }
}
```

## 10) Образовательная часть: план воркшопа

<a id="workshop"></a>

### Цель воркшопа
Дать сотрудникам понимание:
- чем `Observability` отличается от `Monitoring`
- как “ездить” по дашбордам и находить причину
- как алерт превращается в инцидент ITSM

### План (1 день)
1) Observability vs Monitoring (30 мин)
2) Как строится расследование (Detect → Diagnose → Resolve) (45 мин)
3) Практика: дашборды Grafana + drill-down в Log Analytics/OpenSearch (60 мин)
4) Практика: алерт → Logic App → ITSM incident (45 мин)
5) Закрепление + FAQ (20 мин)

<a id="hands-on-examples"></a>

## Примеры (OpenTelemetry) на **AKS** в этом репозитории

В каталоге `examples/` — **collector-first** сценарий для кластера **Azure Kubernetes Service** (без Docker Compose):

- два Go-сервиса (**Gin** + `otelgin` / **HTTP-клиент** с `otelhttp`), OTLP/HTTP на Collector внутри кластера;
- манифесты **Kubernetes** (`examples/kubernetes/`): Jaeger, OpenTelemetry Collector, Deployments сервисов; образы приложений публикуются в **Azure Container Registry** (см. `examples/README.md`, `examples/docs/AKS-ACR-CICD.md`);
- в Bicep при необходимости создаётся **ACR** и выдаётся роль **AcrPull** kubelet-идентичности AKS (`infra/bicep`).

Полноразмерный эталон — апстрим [`open-telemetry/opentelemetry-demo`](https://github.com/open-telemetry/opentelemetry-demo): `make start`, UI на `localhost:8080`.

## Appendix: quick-start for operators (cheat-sheet)

1) Сначала смотрим `Grafana Overview` по `service/env`
2) Находим симптомы (метрики) → корреляция с логами (OpenSearch/Log Analytics)
3) Переходим к трассам по `trace_id` → идентификация upstream/downstream
4) Создаём/насылаем инцидент (автоматически через ITSM интеграцию)

---

Если нужно, расширю документацию отдельными страницами (AKS specifics, OTel Collector config templates, policy sample с `DeployIfNotExists` параметрами, terraform skeleton под ваш subscription layout).

