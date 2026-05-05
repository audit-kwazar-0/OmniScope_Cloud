# IaC (Bicep)

## Entry point

- `infra/bicep/main.bicep` (subscription scope)

## Modules

- `observability-base.bicep`
  - LAW
  - Application Insights
  - Action Group
  - Azure Monitor Workspace + Managed Grafana (optional)
  - Event Hub + LAW Data Export (optional)
  - scheduled query alerts
- `aks.bicep`
  - VNet + subnets
  - AKS cluster
  - OMS addon
  - optional loadtest deployment script
- `aks-diagnostics.bicep`
  - AKS control-plane diagnostic settings to LAW
- `acr.bicep`
  - Azure Container Registry
- `acr-kubelet-pull.bicep`
  - AcrPull assignment for AKS kubelet identity

## Key parameters

- `deployAks`
- `deployAcr`
- `deployAksDiagnostics`
- `deployManagedPrometheus`
- `deployLogExport`
- `teamsWebhookUri`
- `aksSystemVmSize`
- `aksSystemNodeCount`

## Local commands

```bash
cd infra/bicep
./deploy.sh validate
./deploy.sh what-if
./deploy.sh deploy
```
