# Pulumi — OmniScope Azure parity stack

TypeScript program that mirrors [`infra/bicep/main.bicep`](../bicep/main.bicep):

- Resource group, Log Analytics, Application Insights, Action Group (+ optional Teams webhook)
- Scheduled query alerts (CPU, container error ratio)
- Optional Azure Monitor workspace + Managed Grafana
- Optional Event Hub namespace, hub, and LAW data export tables
- Optional AKS (VNet, system pool, overlay Azure CNI, Container Insights + **Azure Policy** + **Key Vault Secrets Provider** add-ons when enabled, deployer MSI + **AKS Contributor** for that identity only)
- Optional Managed Grafana **Grafana Admin** role assignment when `omniscope:grafanaAdminObjectId` is set
- Optional ACR (**Basic**) and kubelet **AcrPull** on that registry
- Optional AKS control-plane **diagnostic settings** to LAW

## One-shot deploy from repo root

With `OMNISCOPE_IAC=pulumi` and `PULUMI_STACK` set in `.env.deploy`, [`scripts/deploy-project.sh`](../../scripts/deploy-project.sh) runs `pulumi up` in this directory, then builds images, applies Kubernetes manifests, and runs the smoke test — same as the Bicep path.

## Not in IaC here (difference from Bicep)

The Bicep module [`modules/aks.bicep`](../bicep/modules/aks.bicep) runs an **Azure CLI deployment script** to apply `loadtest`/CPU stress manifests. That step is intentionally **not** recreated in Pulumi. Use CI, [`scripts/deploy-project.sh`](../../scripts/deploy-project.sh) after `pulumi up`, or local `kubectl apply` if you need the same workload.

## Prerequisites

- Node.js and `npm ci` in this directory
- `pulumi` CLI (and a Pulumi backend if not using default)
- Azure auth (`az login` or environment suitable for `@pulumi/azure-native`)

## Bootstrap

```bash
cd infra/pulumi
npm ci

pulumi stack init dev   # or use an existing stack
pulumi config set omniscope:prefix omniscope-aks-test --stack dev
pulumi config set omniscope:alertEmail oncall@example.com --stack dev
# optional overrides (defaults match main.bicep):
# pulumi config set omniscope:location westeurope
# pulumi config set omniscope:deployManagedPrometheus true
# pulumi config set omniscope:deployLogExport true
# pulumi config set omniscope:deployAks true
# pulumi config set omniscope:deployAcr true
# pulumi config set omniscope:deployAksDiagnostics true
# pulumi config set omniscope:enableAzurePolicyAddon true --stack dev
# pulumi config set omniscope:enableKeyVaultSecretsProvider true --stack dev
# pulumi config set omniscope:grafanaAdminObjectId "<Entra object id>" --stack dev
# pulumi config set omniscope:teamsWebhookUri 'https://...' --secret

pulumi up --stack dev
```

## Outputs (same names as Bicep `main.bicep`)

After `pulumi up`:

```bash
pulumi stack output --json --stack dev
```

Use the JSON to export `RESOURCE_GROUP`, `AKS_NAME`, `ACR_LOGIN_SERVER`, LAW id, Grafana URL, etc., for **`scripts/deploy-project.sh`**, instead of parsing `az deployment sub show`:

```bash
eval "$(pulumi stack output --json --stack dev | jq -r '
  "export RG_NAME=\(.resourceGroupName)",
  "export AKS_NAME=\(.aksName)",
  "export ACR_LOGIN_SERVER=\(.acrLoginServer)",
  "export LOG_ANALYTICS_WORKSPACE_ID=\(.logAnalyticsWorkspaceId)",
  "export GRAFANA_URL=\(.grafanaUrl)"
' | grep -v null)"
```

Adjust variable names to match what your `.env.deploy` expects.

## Provider note

Uses the **`omniscope` config namespace** (see [`Pulumi.yaml`](./Pulumi.yaml) `config:` keys), e.g. `omniscope:prefix`, not bare `prefix`.
