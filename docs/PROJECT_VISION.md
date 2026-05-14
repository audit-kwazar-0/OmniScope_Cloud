# OmniScope: vision for the future project

## Why OmniScope exists

OmniScope is intended as a unified cloud observability platform for product and platform teams.  
The core idea: the team should see system state in real time and move quickly from symptom to root cause without juggling a dozen disconnected tools.

The project addresses three practical goals:

1. **Faster diagnosis** — lower MTTR by correlating metrics, logs, and traces.
2. **Predictable releases** — observability is part of delivery, not bolted on afterward.
3. **One operational standard** — shared templates for IaC, dashboards, alerts, and runbooks.

## Project philosophy

### 1) Observability by default
Every new service in the cluster should automatically land in one pipeline:
- metrics,
- logs,
- traces,
- alerts.

### 2) Infrastructure as product
The platform is a product for internal teams.  
That means it has:
- a version,
- a roadmap,
- SLA/SLO,
- documentation and supported scenarios.

### 3) Everything as code
Anything that can be versioned should live in the repository:
- infrastructure (Bicep),
- Kubernetes manifests,
- dashboard templates,
- alert rules,
- runbooks and evidence.

### 4) Correlation first
Observability only pays off when signals are linked:
- metric → log → trace,
- alert → dashboard → runbook,
- incident → reproducible validation scenario.

## Target architecture

### Platform layer (Azure)
- AKS as the single runtime environment.
- LAW as the primary log layer.
- Application Insights as APM/tracing backend.
- Azure Monitor Workspace + Managed Grafana as the metrics layer.
- Event Hub export path for OpenSearch/Elastic deep-search and long-term forensic scenarios.

### Workload layer (Kubernetes)
- Services deploy into one namespace/ring with mandatory telemetry conventions.
- OTel Collector acts as the telemetry control plane.
- Gateway API/Ingress as the single entry point.

### Operations layer
- Alert rules for infrastructure and application SLIs.
- Action Group (email/webhook) and integration with incident workflows.
- Runbook-driven operations.

## Implementation principles

1. **Incremental delivery**: working MVP first, then hardening.
2. **No magic defaults**: all critical parameters are documented.
3. **Fail with context**: an alert without context (dashboard/logs/trace) is incomplete.
4. **Security baseline**: secrets outside git, least privilege, auditable changes.
5. **Cost awareness**: control cardinality, retention, and signal frequency.

## Roadmap (high level)

### Phase 1 — Foundation
- Baseline IaC (AKS + LAW + App Insights + Grafana/Prometheus + alerts).
- Reference services and end-to-end smoke checks.

### Phase 2 — Standardization
- Telemetry contract for all services.
- Template approach for dashboards/alerts.
- CI gates: validate + what-if + trace-based smoke.

### Phase 3 — Production hardening
- Access policies, private endpoint scenarios, compliance practices.
- Incident workflow and postmortem templates.
- Capacity/cost optimization and SLO governance.

### Phase 4 — Platform scale
- Onboarding new teams as self-service.
- Multi-environment / multi-cluster operating model.
- Regular quality review of observability coverage.

## Definition of success

OmniScope succeeds when:

- any service can attach to the observability ring via a standard template,
- incidents can be triaged end-to-end in minutes, not hours,
- infrastructure and monitoring are reproducible from code,
- documentation stays current and supports day-to-day team work.
