# Pulumi - Observability Test Platform (Azure)

Deploys a minimal “observability base”:
- Resource Group
- Log Analytics Workspace
- Application Insights (linked to Log Analytics)
- Azure Monitor Action Group (email receiver)

## Prerequisites
- Node.js installed
- Logged-in Azure credentials (e.g. via `az login`)

## Configure stack

```bash
pulumi config set prefix omniscope-obs-test
pulumi config set location westeurope
pulumi config set alertEmail oncall@example.com
pulumi config set logAnalyticsRetentionDays 30
pulumi config set appInsightsRetentionDays 90
```

Run:

```bash
pulumi up
```

