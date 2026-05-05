# Alerts and Routing

Configured by `infra/bicep/modules/observability-base.bicep`.

## Alert rules

- Infra:
  - `*-ag-aks-cpu-high`
  - scheduled query over LAW / InsightsMetrics
- App:
  - `*-ag-streamforge-errors`
  - error ratio over `ContainerLogV2`

## Action Group

- Email receiver (required)
- Optional webhook receiver (for Teams simulation via `teamsWebhookUri`)

## Verification commands

```bash
az monitor scheduled-query list --resource-group "$RG" -o table
az monitor action-group list --resource-group "$RG" -o table
```
