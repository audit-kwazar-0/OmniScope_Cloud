# Azure Access (OmniScope_Cloud)

How the project currently authenticates against Azure, what is required on the
caller side, and what files hold what.

> **TL;DR** — OmniScope assumes you are already logged in to the Azure CLI as a
> user (or via a Service Principal) with rights to deploy ARM/Bicep templates,
> create RoleAssignments, and read Entra info. There is **no** dedicated
> credentials file; `az` is the source of truth.

---

## 1. Authentication model

`scripts/deploy-project.sh` performs a single hard-required preflight:

```bash
az account show -o table >/dev/null
```

If that fails, the script exits. Everything downstream (`az deployment sub
create`, `az ad signed-in-user show`, `az grafana ...`, `kubectl ...`) reuses
the cached Azure CLI session.

That means there are **two supported authentication modes**:

| Mode                | When to use                              | How to authenticate                                                   |
| ------------------- | ---------------------------------------- | --------------------------------------------------------------------- |
| Interactive (user)  | Local development, demo deployments      | `az login` (opens browser) → `az account set --subscription <id>`     |
| Service Principal   | CI/CD, repeatable shared environments    | `az login --service-principal -u <APP_ID> -p <SECRET> --tenant <TID>` |

Either way, after login, the same scripts work — they only read `az account
show` and use built-in Azure CLI auth.

---

## 2. Required Azure permissions

The deployment program (Bicep template under `infra/bicep/`) creates:

- Resource Group, AKS managed cluster, ACR.
- Log Analytics workspace, Application Insights, Action Group.
- Optionally: Azure Monitor Workspace, Azure Managed Grafana, Event Hubs.
- Several **`Microsoft.Authorization/roleAssignments`** (AcrPull for kubelet,
  Grafana Admin for the deployer, etc.).

Minimum role set on the target subscription:

| Role                          | Why it is needed                                                          |
| ----------------------------- | ------------------------------------------------------------------------- |
| `Contributor`                 | Create the RG, AKS, ACR, AMW, AMG, LAW, App Insights.                     |
| `User Access Administrator`   | Create `roleAssignments` (AcrPull, Grafana Admin).                        |

Tenant-level: ability to read `az ad signed-in-user show` (default for all
authenticated users; relevant only when `DEPLOY_MANAGED_PROMETHEUS=true` and
`GRAFANA_ADMIN_OBJECT_ID` is left empty — the script then auto-fills the
Grafana Admin from the current user).

---

## 3. Configuration files

```text
OmniScope_Cloud/
├── .env.deploy           # local, gitignored — real values for THIS workstation
├── .env.deploy.example   # tracked — schema/template for .env.deploy
└── .gitignore            # rule: .env*  (so .env.deploy is never committed)
```

**`.env.deploy` is project-config, NOT Azure credentials.** It only stores:

- Subscription-level "intent" — `AZ_LOCATION`, `OMNISCOPE_PREFIX`, `ALERT_EMAIL`.
- Deploy toggles — `DEPLOY_AKS`, `DEPLOY_MANAGED_PROMETHEUS`, `DEPLOY_LOKI`, …
- Names that must be unique per subscription — `KEYVAULT_NAME`,
  `ACR_NAME_OVERRIDE`, `OMNISCOPE_RESOURCE_GROUP`.
- Knobs for Grafana/Loki/dashboards.

Azure auth itself lives **outside** the file, in the Azure CLI's token cache
(`~/.azure/`).

---

## 4. Bootstrap on a fresh machine

```bash
# 1. Install Azure CLI (Linux example).
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# 2. Log in.
az login                                    # opens browser
az account set --subscription "<sub-id>"
az account show -o table                    # sanity-check

# 3. Prepare the project config.
cp .env.deploy.example .env.deploy
$EDITOR .env.deploy                         # fill OMNISCOPE_PREFIX, ALERT_EMAIL, …

# 4. Deploy.
./scripts/deploy-project.sh
```

---

## 5. CI/CD authentication (recommended for shared envs)

OmniScope's scripts are SP-friendly out of the box because they only depend on
Azure CLI:

```bash
# Inside a CI step.
az login --service-principal \
  --username  "$ARM_CLIENT_ID" \
  --password  "$ARM_CLIENT_SECRET" \
  --tenant    "$ARM_TENANT_ID"

az account set --subscription "$ARM_SUBSCRIPTION_ID"

./scripts/deploy-project.sh
```

Store `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`,
`ARM_SUBSCRIPTION_ID` in the CI's secret store (GitHub Actions secrets,
Azure DevOps Library, …). Never commit them.

---

## 6. Related project

The companion repo
[`azure-game-performance-engine`](../../azure-game-performance-engine/) follows
the same authentication pattern but goes one level deeper: it uses **Pulumi**
(not Bicep + `az deployment`), which means the same SP also needs to be
exported to ARM_* env vars *before* `pulumi up` (Pulumi's azure-native provider
reads them directly, not via the `az` cache).

See: [`azure-game-performance-engine/docs/AZURE_ACCESS.md`](../../azure-game-performance-engine/docs/AZURE_ACCESS.md)
for the Pulumi-specific extra step.
