# Bicep - Observability Test Platform

Deploys a minimal Azure Observability foundation:

- Resource Group
- Log Analytics Workspace
- Application Insights (linked to Log Analytics)
- Azure Monitor Action Group (email receiver)
- **Optional**: AKS cluster with Container Insights (OMS agent) wired to the Log Analytics workspace
- **Optional**: **Azure Container Registry (ACR)** and **AcrPull** role for the AKS kubelet (so nodes can pull private images without imagePullSecrets for that registry)
- **Optional**: test CPU load workload (`polinux/stress`) deployed to `loadtest` namespace via a `deploymentScript`

## Prerequisites

- Azure CLI installed
- Authenticated session: `az login`

## Deploy & debug (скрипт)

1. Скопируйте параметры и подставьте свой e-mail и префикс:

   ```bash
   cp parameters.example.json parameters.local.json
   # отредактируйте parameters.local.json (файл в .gitignore)
   ```

2. Команды из каталога `infra/bicep/`:

   | Команда | Действие |
   |---------|----------|
   | `./deploy.sh validate` | Только `az bicep build` (без Azure) |
   | `./deploy.sh what-if` | Сухой прогон против текущей подписки (`az login` обязателен) |
   | `./deploy.sh deploy` | Развёртывание `az deployment sub create` |
   | `./deploy.sh deploy-debug` | То же с `--debug` у Azure CLI |

   Переменные окружения: `PARAMS_FILE`, `LOCATION`, `DEPLOYMENT_NAME`.

В **Cursor / VS Code**: Command Palette → **Tasks: Run Task** → пункты **Bicep: …**.

В **CI**:

- [`.github/workflows/azure-connection-test.yml`](../../.github/workflows/azure-connection-test.yml) — **минимальная проверка** OIDC: только вход в Azure и `az account show` (см. «Нулевой шаг» в [`GITHUB_ACTIONS_VARIABLES.md`](./GITHUB_ACTIONS_VARIABLES.md)).
- [`.github/workflows/infra-bicep.yml`](../../.github/workflows/infra-bicep.yml) — `az bicep build` при изменениях в `infra/bicep/` (без Azure).
- [`.github/workflows/infra-bicep-what-if.yml`](../../.github/workflows/infra-bicep-what-if.yml) — вручную **What-If** в подписке (OIDC). Список Variables/Secrets: **[`GITHUB_ACTIONS_VARIABLES.md`](./GITHUB_ACTIONS_VARIABLES.md)**.

## Deploy (вручную через CLI)

Example:

```bash
az deployment sub create \
  --location westeurope \
  --template-file ./main.bicep \
  --parameters \
    prefix="omniscope-obs-test" \
    alertEmail="oncall@example.com"
```

С файлом параметров:

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
- `acrNameOverride`: optional ACR name (letters and digits only, 5–50 chars, globally unique). If empty, a name is derived from `uniqueString`
- `aksSystemVmSize`: VM size for AKS system pool (default `Standard_D4s_v5`)
- `aksSystemNodeCount`: node count for AKS system pool (default `2`)
- `stressCpuWorkers`: CPU workers for `polinux/stress` (default `4`)
- `loadTestDeployTag`: change this string if you want to re-run the post-install `kubectl apply`

### Outputs (when AKS / ACR are deployed)

- `acrLoginServer`, `acrName` — use with `docker tag` / `docker push` and with [`examples/kubernetes/`](../examples/kubernetes/) manifests (`__ACR_LOGIN_SERVER__` placeholder).

### Notes

- The load test is intentionally noisy (CPU stress). Keep it in non-prod subscriptions/resource groups.
- The template creates a **User Assigned Identity** used only by the post-install `deploymentScript` and grants it **Azure Kubernetes Service Contributor Role** on the AKS cluster resource (needed for admin kubeconfig + `kubectl apply`).

