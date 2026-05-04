# Обзор и потоки данных {#observability}

OmniScope Cloud — эталонная система **Observability** для крупной финансовой организации в облаке **Azure** с использованием:

- Azure Native (Azure Monitor / AMA / Diagnostic Settings / Managed Prometheus / Application Insights)
- OSS-стека (Prometheus-совместимые источники, OpenSearch/Elasticsearch)
- OpenTelemetry (корреляция метрик/логов/трасс)
- Grafana (multi-datasource)
- Enterprise Alerting (Action Groups + каналы + ITSM)
- IaC (Terraform)

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
