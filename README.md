# OmniScope Cloud

Azure-native observability playground for AKS with a practical SRE focus:

- Managed Grafana dashboards for NOC/executive/platform triage.
- Loki-based log workflow with 1-click drilldown.
- Azure Log Analytics (KQL) + Managed Prometheus (AMP) integration.
- IaC variants: Bicep, Terraform, Pulumi.

The target operating model is: **symptom -> scope -> evidence -> root cause**.

---

## What is implemented now

### Core platform

- AKS baseline deployment flows and sample workloads in `examples/`.
- Managed Grafana datasource sync in `scripts/grafana-sync.sh`:
  - Loki datasource.
  - Azure Monitor datasource.
  - Prometheus datasource awareness for tier dashboards.
- Tier dashboards imported via `scripts/reinit-grafana.sh` / `scripts/deploy-project.sh`.

### Dashboards in scope

- `docs/grafana-tier-a-executive.json`
- `docs/grafana-tier-b-noc.json`
- `docs/grafana-tier-c-workload.json`
- `docs/grafana-tier-c-red-metrics.json`
- `docs/grafana-tier-d-k8s-platform.json`
- `docs/grafana-tier-e-logs.json`
- `docs/grafana-tier-f-cost.json`
- `docs/grafana-dashboard0.json` (NOC Loki workspace)

### Recently stabilized

- Fixed KQL schema mismatches (`KubeEventType`, `KubeNodeInventory` columns).
- Added click-through flow from platform/NOC views to Loki NOC dashboard.
- Added RED metrics dashboard scaffold for Prometheus/AMP (`Tier C RED`).

---

## Phase roadmap (1 -> 4)

### Phase 1 - Unified NOC triage (implemented baseline)

Goal: 1-click drilldown from incident symptoms to logs.

- Tier A/B/D shows service/platform symptoms.
- Tier D table links into Loki NOC with preserved time range and object context.
- Loki NOC has namespace/app/pod filtering for fast triage.

Validation:

1. Open `Tier D -> Latest FailedScheduling`.
2. Click `Name` or `Namespace`.
3. Confirm redirect to `omniscope-noc-loki-v1` with prefilled vars and matching time window.

### Phase 2 - RED on AMP/Prometheus (in progress)

Goal: metric-based symptom detection for services.

- New dashboard: `OmniScope — Tier C — RED metrics (services)`.
- Includes Rate / Errors / Duration p95 and top offenders.
- Includes links from RED tables to Loki NOC.

Validation:

1. Ensure Prometheus datasource exists in Managed Grafana.
2. Run `./scripts/reinit-grafana.sh`.
3. Open `Tier C RED`; if no data, adapt metric names in queries:
   - expected: `http_server_request_duration_seconds_count`
   - expected: `http_server_request_duration_seconds_bucket`
   - labels: `service`, `namespace`, `status_code`.

### Phase 3 - Trace correlation (planned)

Goal: metric spike -> trace exemplar -> logs (Tempo/Loki).

Planned requirements:

- Tempo datasource configured in Managed Grafana.
- Exemplars in Prometheus metrics.
- Standard correlation keys: `trace_id`, `service`, `namespace`, `pod`.
- Trace-to-logs mapping in Tempo datasource.

### Phase 4 - Profile correlation (planned)

Goal: logs/trace -> CPU/memory hotspot in profile (Pyroscope).

Planned requirements:

- Pyroscope datasource.
- Correlated labels between traces/logs/profiles.
- One-click jump from error context to profile slice.

---

## Quick start

### End-to-end deploy

Use:

- `scripts/deploy-project.sh` for full setup.
- `scripts/reinit-grafana.sh` for datasource/dashboard resync only.

Config source:

- `.env.deploy` (see `.env.deploy.example`).

Typical flow:

```bash
cd /data/projects/OmniScope_Cloud
./scripts/reinit-grafana.sh
```

### Bicep baseline example

```bash
cd infra/bicep
az deployment sub create \
  --location westeurope \
  --template-file ./main.bicep \
  --parameters prefix="omniscope-obs-test" alertEmail="oncall@example.com"
```

---

## Troubleshooting guide

### Managed Grafana panel shows "No data"

Check:

- datasource auth mode and access rights.
- KQL table schema changes (`KubeEvents`, `KubeNodeInventory`).
- selected time range and cluster filter.
- whether metrics exist in AMP for RED queries.

### Tier dashboard skipped during import

`scripts/grafana-sync.sh` skips dashboards when required datasource is missing:

- `DS_AM` for KQL dashboards.
- `DS_LOKI` for Loki dashboards.
- `DS_PROMETHEUS` for RED Prometheus dashboards.

### RED dashboard empty

Most common reason: metric naming mismatch.

Adapt queries in `docs/grafana-tier-c-red-metrics.json` to your instrumentation schema.

### Cost control and drift guardrails

- Set Log Analytics / App Insights retention in IaC (`logAnalyticsRetentionDays`, `appInsightsRetentionDays`).
- Tune Loki retention and ingestion noise filters in `.env.deploy`:
  - `LOKI_RETENTION_HOURS`
  - `PROMTAIL_DROP_NAMESPACE_REGEX`
  - `PROMTAIL_DROP_CONTAINER_REGEX`
- Run schema/metrics drift checks after AKS upgrades:

```bash
./scripts/dashboard-regression-audit.sh
```

This script validates core KQL tables/columns used by Tier dashboards and alerts when RED metric assumptions change.

---

## Repository map

```text
OmniScope_Cloud/
├── docs/                 # Dashboards, runbooks, and project docs
├── examples/             # AKS sample apps and manifests
├── infra/                # Bicep / Terraform / Pulumi
├── scripts/              # Deploy and Grafana sync automation
├── tests/load/           # k6 baseline tests
└── doc-site/             # VitePress site
```

Key docs:

- `docs/README.md`
- `docs/DEPLOYMENT_RUNBOOK.md`
- `docs/LOAD_TEST_AND_SERVICE_MESH_VALIDATION.md`
- `docs/LOAD_TEST_BASELINE.md`
- `docs/EVIDENCE.md`

---

## Documentation site

- Live: [https://audit-kwazar-0.github.io/OmniScope_Cloud/](https://audit-kwazar-0.github.io/OmniScope_Cloud/)
- Source: `doc-site/`

Local preview:

```bash
cd doc-site
npm ci
npm run docs:dev
```

---

## Contributing

Read `CONTRIBUTING.md` before submitting changes.

## License

Released under `MIT` (`LICENSE`).
