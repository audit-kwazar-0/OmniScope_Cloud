# Обзор платформы

Документация построена по текущей реализации в репозитории `OmniScope_Cloud`.

## Что разворачивается

- AKS (Azure CNI overlay, VNet/subnets)
- Log Analytics Workspace + Application Insights
- Azure Monitor Workspace (Managed Prometheus) + Managed Grafana
- Event Hub + LAW Data Export (путь в OpenSearch/Elastic pipeline)
- Alert rules + Action Group
- ACR + AcrPull для AKS kubelet
- Контрольные workload'ы в AKS (`service-a`, `service-b`, OTel collector, Jaeger)

## Поток данных

```mermaid
flowchart LR
  U[Client] --> A[service-a]
  A --> B[service-b]
  A --> OTel[OTel Collector]
  B --> OTel
  OTel --> AI[Application Insights]
  OTel --> LAW[Log Analytics Workspace]
  AKS[AKS + control plane] --> LAW
  AKS --> AMW[Azure Monitor Workspace]
  AMW --> GRAF[Managed Grafana]
  LAW --> EH[Event Hub Export]
  EH --> OS[OpenSearch/Elastic pipeline]
  LAW --> ALR[Scheduled Query Rules]
  ALR --> AG[Action Group]
```

## Где смотреть в коде

- IaC entry: `infra/bicep/main.bicep`
- Bicep modules: `infra/bicep/modules/*`
- App manifests: `examples/kubernetes/*`
- Services: `examples/services/service-a`, `examples/services/service-b`
