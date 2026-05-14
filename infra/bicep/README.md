# Bicep - Observability Test Platform

Deploys a minimal Azure Observability foundation:

- Resource Group
- Log Analytics Workspace
- Application Insights (linked to Log Analytics)
- Azure Monitor Action Group (email receiver)
- **Optional**: AKS cluster with Container Insights (OMS agent) wired to the Log Analytics workspace
- **Optional**: **Azure Container Registry (ACR)** and **AcrPull** role for the AKS kubelet (so nodes can pull private images without imagePullSecrets for that registry)
- **Optional**: Azure Monitor Workspace (Managed Prometheus) + Azure Managed Grafana
- **Optional**: LAW Data Export to Event Hub for OpenSearch/Elastic ingestion pipeline
- **Optional**: test CPU load workload (`polinux/stress`) deployed to `loadtest` namespace via a `deploymentScript`

## Prerequisites

- Azure CLI installed
- Authenticated session: `az login`

## Deploy & debug (script)

1. Copy parameters and set your email and prefix:

   ```bash
   cp parameters.example.json parameters.local.json
   # edit parameters.local.json (file is in .gitignore)
   ```

   For **test AKS + ACR** (single node `Standard_B2s_v2`, lighter stress load) you can start from the ready profile and copy into `parameters.local.json` if needed:

   ```bash
   cp parameters.test-aks.json parameters.local.json
   # set your alertEmail and optionally prefix / region
   ```

2. Commands from `infra/bicep/`:

   | Command | Action |
   |---------|--------|
   | `./deploy.sh validate` | `az bicep build` only (no Azure) |
   | `./deploy.sh what-if` | Dry run against current subscription (`az login` required) |
   | `./deploy.sh deploy` | `az deployment sub create` |
   | `./deploy.sh deploy-debug` | Same with `--debug` on Azure CLI |

   Environment variables: `PARAMS_FILE`, `LOCATION`, `DEPLOYMENT_NAME`.

In **Cursor / VS Code**: Command Palette → **Tasks: Run Task** → **Bicep: …** tasks.

In **CI**:

- [`.github/workflows/azure-connection-test.yml`](../../.github/workflows/azure-connection-test.yml) — OIDC + `az account show` and **Preflight** (hints for `BICEP_*` before what-if; see [`GITHUB_ACTIONS_VARIABLES.md`](./GITHUB_ACTIONS_VARIABLES.md)).
- [`.github/workflows/infra-bicep.yml`](../../.github/workflows/infra-bicep.yml) — `az bicep build` on changes under `infra/bicep/` (no Azure).
- [`.github/workflows/infra-bicep-what-if.yml`](../../.github/workflows/infra-bicep-what-if.yml) — manual **What-If** (OIDC); you can pick **deploy_aks / deploy_acr = true** without changing Variables. Name list: **[`GITHUB_ACTIONS_VARIABLES.md`](./GITHUB_ACTIONS_VARIABLES.md)**.

## Deploy (manual CLI)

Example:

```bash
az deployment sub create \
  --location westeurope \
  --template-file ./main.bicep \
  --parameters \
    prefix="omniscope-obs-test" \
    alertEmail="oncall@example.com"
```

With a parameters file:

```bash
az deployment sub create \
  --location westeurope \
  --name omniscope-deploy-1 \
  --template-file ./main.bicep \
  --parameters @parameters.local.json
```

### Parameters

- `prefix`: naming prefix
- `location`: Azure region (default `westeurope`)
- `alertEmail`: required email receiver for Action Group
- `logAnalyticsRetentionDays`: default `30`
- `appInsightsRetentionDays`: default `90`
- `deployAks`: deploy AKS + sample load workload (default `true`)
- `deployAcr`: when `true` and `deployAks` is `true`, create **ACR** and assign **AcrPull** to the cluster kubelet (default `true`)
- `deployAksDiagnostics`: when `true` and `deployAks` is `true`, enable AKS control-plane diagnostics to LAW (`kube-apiserver`, `kube-audit`, etc.) (default `true`)
- `enableAzurePolicyAddon`: enable AKS Azure Policy addon (default `false`)
- `enableKeyVaultSecretsProvider`: enable AKS Key Vault CSI addon (default `false`)
- `keyVaultSecretRotationEnabled`: enable Key Vault CSI secret rotation (default `true`)
- `keyVaultRotationPollInterval`: Key Vault CSI rotation poll interval (default `2m`)
- `deployManagedPrometheus`: deploy Azure Monitor Workspace + Managed Grafana (default `true`)
- `grafanaAdminObjectId`: optional Entra **object id** (user, group, or SPN) granted **Grafana Admin** on Managed Grafana so `az grafana` and the UI work without manual RBAC. Leave empty to skip (then assign the role manually in Azure Portal).
- `grafanaAdminPrincipalType`: `User`, `Group`, or `ServicePrincipal` (default `User`) — must match `grafanaAdminObjectId`.
- `deployLogExport`: deploy LAW Data Export to Event Hub (for OpenSearch/Elastic downstream) (default `true`)
- `teamsWebhookUri`: optional webhook URL for Action Group simulation (MS Teams)
- `acrNameOverride`: optional ACR name (letters and digits only, 5–50 chars, globally unique). If empty, a name is derived from `uniqueString`
- `aksSystemVmSize`: VM size for AKS system pool (default `Standard_D4s_v5`)
- `aksSystemNodeCount`: node count for AKS system pool (default `2`)
- `stressCpuWorkers`: CPU workers for `polinux/stress` (default `4`)
- `loadTestDeployTag`: change this string if you want to re-run the post-install `kubectl apply`

### Outputs (when AKS / ACR are deployed)

- `acrLoginServer`, `acrName` — use with `docker tag` / `docker push` and with [`examples/kubernetes/`](../examples/kubernetes/) manifests (`__ACR_LOGIN_SERVER__` placeholder).
- `grafanaUrl`, `azureMonitorWorkspaceId` — Managed Prometheus/Grafana integration endpoints.
- `eventHubId` — export entry point for OpenSearch/Elastic ingestion.
- `vnetId`, `privateEndpointsSubnetId` — network references for private endpoint extension.

### Notes

- **Managed Grafana + Azure Monitor:** Bicep enables **system-assigned identity** on Managed Grafana and assigns **Monitoring Reader** on the deployment **resource group** (for **MSI** auth). `scripts/grafana-sync.sh` provisions the **Azure Monitor** datasource; by default it uses **`azureAuthType: currentuser`** (same as Grafana UI *Current user*, works with Entra sign-in). Set `GRAFANA_AZURE_MONITOR_AUTH_TYPE=msi` in `.env.deploy` when MSI RBAC is applied and you want queries to run as the Grafana managed identity.
- **Istio control:** service mesh enablement is managed by `scripts/deploy-project.sh` via `az aks mesh enable` (`ENABLE_ISTIO_MESH=true`) to keep deployment idempotent with existing clusters.
- If Bicep fails with **RoleAssignmentExists** on Managed Grafana, you already have **Grafana Admin** for the same principal at that scope (e.g. created manually with `az role assignment create`). Remove the duplicate assignment on the Grafana resource, then redeploy — or rely on the existing assignment and temporarily omit `grafanaAdminObjectId` from the template (set to empty and remove the `grafanaAdminAssignment` resource) if you maintain RBAC only by hand.
- The load test is intentionally noisy (CPU stress). Keep it in non-prod subscriptions/resource groups.
- The template creates a **User Assigned Identity** used only by the post-install `deploymentScript` and grants it **Azure Kubernetes Service Contributor Role** on the AKS cluster resource (needed for admin kubeconfig + `kubectl apply`).
- **New subscriptions:** register `Microsoft.OperationsManagement` before first AKS with Container Insights: `az provider register --namespace Microsoft.OperationsManagement --wait`.
- **VM SKU:** some regions/subscriptions no longer offer `Standard_B2s` for AKS; `parameters.test-aks.json` uses **`Standard_B2s_v2`** (see Azure error `aks/quotas-skus-regions` if deploy fails on node size).

