# OmniScope Cloud - Infra (Azure Observability Test Platform)

This folder contains three equivalent Infrastructure-as-Code (IaC) implementations for a minimal, test-only Azure Observability platform:

1. `bicep/` (Azure Bicep / ARM)
2. `pulumi/` (Pulumi, TypeScript)
3. `terraform/` (Terraform / azurerm)

The “base” resources created in all three implementations:
- Resource Group
- Log Analytics Workspace
- Application Insights (linked to Log Analytics)
- Azure Monitor Action Group (email receiver)

For a **local OpenTelemetry hands-on stack** (two Go services + Collector + Jaeger + Prometheus), see `../examples/` in this repository.

After you deploy the base, you can extend it with:
- Azure Managed Prometheus (AMP)
- OTel Collector / pipelines / DCR
- Grafana (self-hosted or Azure Managed Grafana)
- Long-term storage & ingestion (OpenSearch/Elasticsearch)
- Diagnostic Settings policies for “all relevant resource types”

## Common parameters

- `prefix`: naming prefix (e.g. `omniscope-obs-test`)
- `location`: Azure region (e.g. `westeurope`)
- `alertEmail`: email address for Action Group notifications
- `logAnalyticsRetentionDays`: Log Analytics retention (default 30)
- `appInsightsRetentionDays`: App Insights retention (default 90)

