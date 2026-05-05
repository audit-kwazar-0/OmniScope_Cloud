# OmniScope on Azure — Documentation

This documentation is rebuilt from current code and deployment behavior in this repository.

Project narrative (philosophy + implementation story):
- `docs/PROJECT_STORY.md`

## 1. What this project deploys

Infrastructure is deployed via Bicep (`infra/bicep`) at subscription scope:

- Resource Group
- Log Analytics Workspace (LAW)
- Application Insights (workspace-based)
- Action Group (email + optional webhook)
- Azure Monitor Workspace (Managed Prometheus) — optional
- Azure Managed Grafana — optional
- Event Hub namespace + event hub + LAW Data Export — optional
- AKS cluster with:
  - Azure CNI overlay
  - dedicated VNet + subnets (`aks`, `private-endpoints`)
  - OMS/Container Insights enabled
  - optional post-deploy CPU stress workload (`loadtest`)
- AKS control-plane diagnostics to LAW (`kube-apiserver`, `kube-audit`, etc.) — optional
- ACR + AcrPull assignment for AKS kubelet — optional

Application layer (`examples/`) includes two Go services:

- `service-a`
- `service-b`

Both are instrumented with OpenTelemetry and emit:

- traces (OTLP)
- metrics, including custom counters:
  - `streamforge_processed_messages_total`
  - `streamforge_processing_errors_total`

## 2. Repository map

- IaC entrypoint: `infra/bicep/main.bicep`
- IaC modules:
  - `infra/bicep/modules/observability-base.bicep`
  - `infra/bicep/modules/aks.bicep`
  - `infra/bicep/modules/aks-diagnostics.bicep`
  - `infra/bicep/modules/acr.bicep`
  - `infra/bicep/modules/acr-kubelet-pull.bicep`
- Deploy helper: `infra/bicep/deploy.sh`
- Test profile params: `infra/bicep/parameters.test-aks.json`
- App manifests:
  - `examples/kubernetes/apps/service-a.yaml`
  - `examples/kubernetes/apps/service-b.yaml`
  - `examples/kubernetes/otel/*`
  - `examples/kubernetes/gateway/*` (optional Gateway API)

## 3. Deployment protocol

See detailed runbook: `docs/DEPLOYMENT_RUNBOOK.md`.

Short version:

1. Deploy infra from `infra/bicep`.
2. Build and push service images to ACR.
3. Apply Kubernetes manifests to AKS.
4. Validate pods, service connectivity, traces, metrics, and alerts.

## 4. CI/CD workflows (GitHub Actions)

- `azure-connection-test.yml`  
  OIDC login validation against Azure + preflight checks for required Bicep vars.

- `infra-bicep.yml`  
  Pure Bicep compile check (`az bicep build`) on infra changes.

- `infra-bicep-what-if.yml`  
  Manual `what-if` against Azure subscription using OIDC, with dispatch overrides for `deployAks` and `deployAcr`.

## 5. Observability model

- **Metrics**: Managed Prometheus + Managed Grafana (optional via params)
- **Logs**: LAW as primary store; optional export to Event Hub for OpenSearch/Elastic pipeline
- **Traces/APM**: Application Insights via OTel
- **Alerts**:
  - infra CPU condition (scheduled query)
  - app error ratio condition (scheduled query)
  - routed to Action Group

## 6. Validation checklist

See full evidence checklist and screenshot plan: `docs/EVIDENCE.md`.

Grafana import template (rebuilt):
- `docs/grafana-dashboard.json`

Core runtime checks:

```bash
kubectl get nodes
kubectl -n omniscope get pods
```

App e2e checks:

```bash
curl -s http://localhost:8081/hello-a
curl -s http://localhost:8081/call-b
```

