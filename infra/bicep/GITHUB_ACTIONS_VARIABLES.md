# GitHub Actions: переменные и секреты для Azure (Bicep)

Ниже — **порядок действий**: сначала получаете значения в Azure / Entra, затем заносите их в GitHub. Разделение: **Variables** (некритичные строки) и **Secrets** (то, что не должно попадать в логи).

Путь в GitHub: **Repository → Settings → Secrets and variables → Actions**.

- Вкладка **Variables** → **New repository variable** (для каждого имени из таблицы).
- Вкладка **Secrets** → **New repository secret** (только для пунктов, помеченных как Secret).

---

## Нулевой шаг: только проверить, что GitHub «достучался» до Azure

Нужны **только три** Variable: `AZURE_SUBSCRIPTION_ID`, `AZURE_TENANT_ID`, `AZURE_CLIENT_ID` (как в шагах 1–3 ниже) + federated credential и роль у приложения.

**По шагам:**

1. Локально: `az login`, `az account set -s ...`, выпишите **subscription id** и **tenant id** (шаги 1–2 ниже).
2. В Entra: приложение + **Federated credential** (GitHub, ваш org/user, репо, ветка **`main`**) — шаг 3.2 ниже.
3. Выдайте этому приложению роль на подписку (например Contributor для песочницы) — шаг 3.3.
4. В GitHub → **Settings → Secrets and variables → Actions → Variables** создайте три переменные с **точными** именами.
5. Закоммитьте и запушьте файл **`.github/workflows/azure-connection-test.yml`** (уже в репозитории).
6. Откройте **Actions** → слева выберите **«Azure — connection test»**.
7. Нажмите **Run workflow** → зелёная ветка **main** → **Run workflow**.
8. Откройте появившийся **run** → дождитесь зелёного статуса.
9. В шаге **«Подписка активна»** в логе должна быть таблица `az account show` с вашей подпиской.

Если падает **Azure login** — снова проверьте federated credential (имя репо, org, **ветка main**) и что workflow запускаете с **main**. Если логин ок, а дальше **Forbidden** — смотрите роли приложения на подписке.

---

## Шаг 1. Подписка Azure — `AZURE_SUBSCRIPTION_ID` (Variable)

1. Установите [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), выполните `az login`.
2. Выберите нужную подписку: `az account set --subscription "<имя или id>"`.
3. Получите id:

   ```bash
   az account show --query id -o tsv
   ```

4. В GitHub создайте variable **`AZURE_SUBSCRIPTION_ID`** = скопированный GUID.

---

## Шаг 2. Каталог (tenant) — `AZURE_TENANT_ID` (Variable)

1. В том же сеансе CLI:

   ```bash
   az account show --query tenantId -o tsv
   ```

2. В GitHub создайте variable **`AZURE_TENANT_ID`** = этот GUID.

Альтернатива: портал **Microsoft Entra ID** → **Overview** → **Tenant ID**.

---

## Шаг 3. Приложение для CI (OIDC) — `AZURE_CLIENT_ID` (Variable)

Нужен **App registration** (сервисное приложение), с которым GitHub будет входить **без пароля**, через **federated credential** (OIDC).

### 3.1 Создать регистрацию приложения

1. Портал **Microsoft Entra ID** → **App registrations** → **New registration**.
2. Имя, например: `github-omniscope-bicep`.
3. После создания откройте приложение → поле **Application (client) ID** — это значение для GitHub.

### 3.2 Federated credential (связь GitHub → Azure)

Это **отдельный шаг после** создания приложения (3.1). Без federated credential GitHub **не сможет** выдать токен OIDC, и `azure/login` завершится ошибкой.

1. Откройте **то же** приложение: **Microsoft Entra ID** → **App registrations** → ваше приложение (например `github-omniscope-bicep`).
2. В меню слева: **Certificates & secrets** → вкладка **Federated credentials** → **Add credential**.  
   (В части порталов пункт **Federated credentials** также есть в левом меню приложения — можно открыть оттуда.)
3. **Credential type / scenario**: выберите сценарий вроде **GitHub Actions deploying Azure resources** (название может слегка отличаться в UI).
4. Заполните поля GitHub (должны **точно** совпасть с тем, откуда запускается workflow):
   - **Organization** — владелец репозитория на GitHub (`user` или `org`), **без** `https://`.
   - **Repository** — имя репо **как в URL** (`OmniScope_Cloud`, регистр важен, если так заведён репозиторий).
   - **Entity type** — для нашего workflow **`infra-bicep-what-if.yml`** удобнее **Branch** (не Environment), если в credential не задавали среду.
   - **GitHub branch name** — `main` или `master`, **та же ветка**, с которой вы запускаете Actions (и которая указана в federated credential).
5. **Credential details → Name** — обязательное имя credential (например `github-oidc-main`); **Description** можно оставить пустым. Поля **Issuer**, **Subject identifier** и **Audience** (`api://AzureADTokenExchange`) портал заполняет сам — их не копируют в GitHub.
6. Нажмите **Add** / сохраните credential.

**Что из обзора приложения куда класть (не путать):**

| Поле в портале (Overview приложения) | Куда в GitHub |
|--------------------------------------|---------------|
| **Application (client) ID** | Variable **`AZURE_CLIENT_ID`** (шаг 3.4) |
| **Directory (tenant) ID** | Variable **`AZURE_TENANT_ID`** (шаг 2; то же значение) |
| **Object ID** | **Не** копируйте в GitHub Variables для `azure/login` — это внутренний идентификатор объекта в Entra; для входа из Actions нужны **client id**, **tenant id**, **subscription id**. |

После сохранения в списке federated credentials появится строка с **Issuer** и **Subject** — их **не** нужно руками переносить в GitHub: `azure/login` подставляет их из контекста `github.token` при OIDC.

Подробнее: [Use the Azure Login action with OpenID Connect](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure).

### 3.3 Права на подписку (или RG)

У **service principal** приложения должна быть роль, достаточная для **deployment** и **what-if** на нужной области (часто **Contributor** на подписке для теста — сузьте до Resource Group в проде).

```bash
# client id из портала приложения
APP_ID="<AZURE_CLIENT_ID>"

az ad sp create --id "$APP_ID" 2>/dev/null || true

SUBSCRIPTION_ID="$(az account show --query id -o tsv)"

az role assignment create \
  --assignee "$APP_ID" \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"
```

Для продакшена лучше **отдельная подписка** или scope на конкретную RG.

### 3.4 Variable в GitHub

Создайте variable **`AZURE_CLIENT_ID`** = Application (client) ID из шага 3.1.

**Client secret не создавайте** — при OIDC он не нужен.

---

## Шаг 4. Параметры Bicep (Variables)

Эти значения передаются в `az deployment sub what-if` в workflow **`infra-bicep-what-if.yml`**.

| Имя в GitHub | Откуда взять | Пример |
|--------------|--------------|--------|
| **`BICEP_PREFIX`** | Ваш префикс имён ресурсов (уникальный в подписке) | `omniscope-obs-test` |
| **`BICEP_LOCATION`** | Регион ARM metadata / ресурсов | `westeurope` или `northeurope` |
| **`BICEP_ALERT_EMAIL`** | Почта для Action Group (обязательный параметр шаблона) | рабочий email |

Опционально (если не заданы, в workflow подставляются **`false`**):

| Имя | Назначение |
|-----|------------|
| **`BICEP_DEPLOY_AKS`** | `true` / `false` — поднимать ли AKS |
| **`BICEP_DEPLOY_ACR`** | `true` / `false` — создавать ли ACR (имеет смысл при AKS) |

---

## Шаг 5. Почта как Secret (по желанию)

Если не хотите светить email в Variables:

1. Удалите variable `BICEP_ALERT_EMAIL` (если создавали).
2. Создайте secret **`BICEP_ALERT_EMAIL`** с тем же значением.
3. В workflow уже предусмотрено: сначала берётся **secret**, иначе **variable**.

---

## Шаг 6. Проверка

1. Убедитесь, что все **Variables** из шагов 1–4 созданы (и Secret для почты — по желанию).
2. **Actions** → workflow **Infra — Bicep what-if (Azure)** → **Run workflow** (только `workflow_dispatch`).
3. При ошибке входа проверьте federated credential (ветка, org, имя репо) и роль на подписке.

---

## Сводная таблица имён

| Имя | Тип | Обязательно для what-if в CI |
|-----|-----|--------------------------------|
| `AZURE_SUBSCRIPTION_ID` | Variable | да |
| `AZURE_TENANT_ID` | Variable | да |
| `AZURE_CLIENT_ID` | Variable | да (OIDC) |
| `BICEP_PREFIX` | Variable | да |
| `BICEP_LOCATION` | Variable | да |
| `BICEP_ALERT_EMAIL` | Variable **или** Secret | да |
| `BICEP_DEPLOY_AKS` | Variable | нет (по умолчанию `false`) |
| `BICEP_DEPLOY_ACR` | Variable | нет (по умолчанию `false`) |

---

## Организационные variables

Если репозиторий в **организации**, те же имена можно задать на уровне **Org → Settings → Variables** и наследовать в репозитории (политика наследования настраивается отдельно). Для личного аккаунта достаточно **repository variables**.
