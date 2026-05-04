# Bicep - Observability Test Platform

Deploys a minimal Azure Observability foundation:

- Resource Group
- Log Analytics Workspace
- Application Insights (linked to Log Analytics)
- Azure Monitor Action Group (email receiver)
- **Optional**: AKS cluster with Container Insights (OMS agent) wired to the Log Analytics workspace
- **Optional**: test CPU load workload (`polinux/stress`) deployed to `loadtest` namespace via a `deploymentScript`

## Prerequisites

- Azure CLI installed
- Authenticated session: `az login`

## Deploy

Example:

```bash
az deployment sub create \
  --location westeurope \
  --template-file ./main.bicep \
  --parameters \
    prefix="omniscope-obs-test" \
    alertEmail="oncall@example.com"
```

### Parameters

- `prefix`: naming prefix
- `location`: Azure region (default `westeurope`)
- `alertEmail`: required email receiver for Action Group
- `logAnalyticsRetentionDays`: default `30`
- `appInsightsRetentionDays`: default `90`
- `deployAks`: deploy AKS + sample load workload (default `true`)
- `aksSystemVmSize`: VM size for AKS system pool (default `Standard_D4s_v5`)
- `aksSystemNodeCount`: node count for AKS system pool (default `2`)
- `stressCpuWorkers`: CPU workers for `polinux/stress` (default `4`)
- `loadTestDeployTag`: change this string if you want to re-run the post-install `kubectl apply`

### Notes

- The load test is intentionally noisy (CPU stress). Keep it in non-prod subscriptions/resource groups.
- The template creates a **User Assigned Identity** used only by the post-install `deploymentScript` and grants it **Azure Kubernetes Service Contributor Role** on the AKS cluster resource (needed for admin kubeconfig + `kubectl apply`).

