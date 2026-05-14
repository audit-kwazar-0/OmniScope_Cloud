# OmniScope: 30/60/90 project plan

## 1) Project concept

OmniScope is an observability platform for Azure/AKS where metrics, logs, traces, and alerts work as one decision-making system.

Goal: shorten incident diagnosis time and make releases more predictable through a standardized monitoring and operations ring.

## 2) Target KPIs

### Reliability and operations
- MTTR for priority incidents: at least 30% reduction after baseline rollout.
- MTTD (time to detect): no more than 5 minutes for critical failures.
- Share of alerts with actionable context (dashboard + log/trace): 90%+.

### Observability coverage
- Services with OTel instrumentation: 100% for services in the release path.
- Services with a telemetry contract (metrics/logs/trace attributes): 100% for new services.
- Dashboards with SLI/SLO panels: at least one working dashboard per domain/team.

### Delivery quality
- IaC pipelines (`validate` + `what-if`) succeed in 95%+ of runs on `main`.
- Post-deploy smoke e2e: 100% of mandatory checks pass.
- Time to restore an environment from code (clean deploy): no more than 60 minutes.

## 3) Main risks and mitigations

### Risk 1: noisy alerts and alert fatigue
- **Symptom**: too many low-quality firings.
- **Mitigation**: unified severity rules, mandatory runbook links, weekly alert review.

### Risk 2: rising cost of telemetry storage/processing
- **Symptom**: high metric cardinality, excessive log volume.
- **Mitigation**: budgets/retention policy, filtering low-value logs, label/attribute hygiene.

### Risk 3: incomplete correlation between signals
- **Symptom**: hard to go from alert to root cause.
- **Mitigation**: standardize trace IDs/request IDs, Grafana data links, OTel conventions as a required contract.

### Risk 4: infrastructure drift
- **Symptom**: environment does not match the repository.
- **Mitigation**: IaC-only changes for core resources, regular `what-if`, PR-gated changes.

### Risk 5: reliance on manual steps
- **Symptom**: operations depend on one or two people’s tribal knowledge.
- **Mitigation**: runbook-first approach, short operational scenarios, evidence checklist per release.

## 4) First 30 days (Foundation)

### Goal
Run a stable baseline observability ring in a test AKS environment.

### Key outcomes
- Clean deploy of baseline infrastructure via Bicep completed.
- Working e2e path for `service-a` and `service-b`.
- Baseline dashboards and two key alerts (CPU and error ratio) enabled.
- `DEPLOYMENT_RUNBOOK` + `EVIDENCE` prepared and verified.

### Definition of ready
- Repeatable deploy/cleanup without hidden manual steps.
- The team can reproduce the scenario from documentation.

## 5) Next 60 days (Standardization)

### Goal
Standardize how new services connect and stabilize signal quality.

### Key outcomes
- Telemetry contract for apps (metrics/logs/traces/attributes).
- Dashboard/alert templates reused across services.
- Observability CI checks in the release path.
- Basic incident triage model aligned with the Action Group.

### Definition of ready
- A new service connects via template within a bounded time.
- Alerts give a clear next step and link to context.

## 6) Next 90 days (Hardening)

### Goal
Prepare the platform for production scenarios and team growth.

### Key outcomes
- Stronger security baseline (access, private scenarios, change audit).
- SLO-oriented panels and regular health review.
- Optimized telemetry cost and retention strategy.
- Formal postmortem and observability improvement loop.

### Definition of ready
- Platform runs stably under growing load.
- Measurable progress on MTTR/MTTD and signal quality.

## 7) Management rhythm

- Weekly: alert review, noisy signals, KPI status.
- Biweekly: revise 30/60/90 roadmap and priorities.
- Monthly: architecture review (observability coverage, cost, reliability).

## 8) Success at 90 days

- OmniScope is the standard observability path for target services.
- Operational decisions use correlated data, not manual hunting.
- Documentation, IaC, and runtime practices stay aligned and reproducible.
