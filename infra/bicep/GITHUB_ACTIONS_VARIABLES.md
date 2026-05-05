# GitHub Actions: переменные и секреты для Azure (Bicep)

Ниже — **порядок действий**: сначала получаете значения в Azure / Entra, затем заносите их в GitHub. Разделение: **Variables** (некритичные строки) и **Secrets** (то, что не должно попадать в логи).

Путь в GitHub:

- **Repository** → **Settings** → **Secrets and variables** → **Actions** — общие **Variables** и **Secrets** репозитория.
- **Settings** → **Environments** → окружение **`bicep`** — опционально **Environment secrets** / **Environment variables** (изоляция, правила защиты, отдельные значения для prod/test).

Текущие workflow **`.github/workflows/azure-connection-test.yml`** и **`.github/workflows/infra-bicep-what-if.yml`** задают в job **`environment: bicep`**. Тогда в OIDC-токене subject вида **`repo:ORG/REPO:environment:bicep`** — в Entra обязателен federated credential на **Environment** с именем **`bicep`** (см. §3.2).

**Важно про слияние контекстов:** `secrets.AZURE_*` и `vars.BICEP_*` доступны job’у и из **repository**, и из **environment** `bicep` (при одинаковых именах обычно приоритет у более узкого уровня — [Variables](https://docs.github.com/en/actions/learn-github-actions/variables), [Secrets](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions)). Успешный **Azure — connection test** означает только: OIDC + три идентификатора Azure. Для **Infra — Bicep what-if** дополнительно нужны **Variables** `BICEP_PREFIX`, `BICEP_LOCATION` и почта `BICEP_ALERT_EMAIL` (variable или secret); для плана **с AKS и ACR** — ещё `BICEP_DEPLOY_AKS=true` и `BICEP_DEPLOY_ACR=true` **или** при ручном запуске what-if выберите в форме **deploy_aks / deploy_acr = true** (переопределение без смены Variables).

После **connection test** смотрите шаг **Preflight** — там предупреждения, если чего-то не хватает для what-if.

---

## Где кнопка **Run workflow** и почему её может не быть

1. **Откройте именно страницу одного workflow (не просто журнал всех запусков).**  
   - Вариант А: вкладка **Actions** → в **левой колонке** выберите строку с **названием workflow**, например **Azure — connection test** или **Manual — self-test (dispatch only)** → справа появится **Run workflow** и выбор ветки.  
   - Вариант Б (прямая ссылка): `https://github.com/<ORG>/<REPO>/actions/workflows/<имя-файла.yml>` — например `.../actions/workflows/run-pipeline.yml` (основной ручной пайплайн) или `.../actions/workflows/teardown-skeleton.yml`. На этой странице кнопка обычно справа **над списком** прошлых запусков.  
   Если вы остаетесь только на общем виде `/actions`, без выбора workflow слева, кнопка часто **не показывается**.
2. **Ручной запуск бывает только при `workflow_dispatch`.** Workflow только с `push` / `pull_request` / `schedule` не дают Run. Файлы **только** с `on: workflow_call` (например **Reusable — build & push**) в общем случае **не имеют** кнопки Run — их вызывает другой workflow.
3. **Файл с `workflow_dispatch` должен быть в default branch на GitHub.** Локально в Cursor YAML есть, но пока изменения не **push + merge в main** (или другой default branch), на сайте будет старая версия без кнопки.
4. **Права:** для Run нужен доступ с правом изменять Actions (обычно **Write** или **Maintain** для репозитория). При **Read** кнопки нет. В организации возможны ещё **политики org**.
5. **Actions отключены:** **Settings → Actions → General** — разрешён ли вообще **GitHub Actions** и не выключены ли отдельные workflow (рядом с именем есть «⋯» → disable).
6. **Форк:** в своём форке **Settings → Actions** часто нужно включить выполнение вручную.
7. **Мобильный клиент GitHub:** чрезвычайно упрощённый UI — кнопки Run там может не быть; открывайте репозиторий в браузере с ПК.

**Быстрая проверка:** после merge в default branch откройте **Run pipeline — Bicep & Azure** (файл `run-pipeline.yml`), выберите режим **bicep_validate** и нажмите **Run workflow**. Если кнопки нет — см. пункты про права, default branch и настройки Actions выше.

---

## Цепочка пайплайнов (OIDC → what-if → AKS в плане)

**Один ручной вход:** **Run pipeline — Bicep & Azure** (`.github/workflows/run-pipeline.yml`) — режимы `bicep_validate` → `azure_connection` → `subscription_what_if`. Старые отдельные workflow (**Azure — connection test**, **Infra — Bicep what-if**) можно оставить для привычки; логика what-if совпадает.

| Шаг | Workflow / режим | Что проверяется | Чего недостаточно для следующего шага |
|-----|------------------|-----------------|--------------------------------------|
| 1 | **Run pipeline** → `azure_connection` **или** **Azure — connection test** | Federated credential `environment:bicep`, `AZURE_*` **Secrets**, роль на подписку, `az account show` | — |
| 2 | **Run pipeline** → `subscription_what_if` **или** **Infra — Bicep what-if** | OIDC + параметры Bicep + `az deployment sub what-if` | Без `BICEP_*` упадёт на проверке конфигурации; без `deployAks=true` в плане **не появятся** AKS/ACR |
| 3 | Реальный деплой | Локально `./deploy.sh deploy` или отдельный CD (в репозитории пока только what-if, не `deployment sub create`) | Отдельное решение: approvals, другой workflow |

**Роль приложения (Entra) на подписку:** для what-if с AKS обычно нужна та же ширина прав, что и для создания ресурсов (часто **Contributor** на тестовую подписку; только **Reader** может не хватить для корректного what-if по сложным шаблонам). Плюс квоты подписки на compute / AKS в регионе `BICEP_LOCATION`.

---

## Нулевой шаг: проверка подключения к Azure (`Azure — connection test`)

1. Создайте окружение: **Settings → Environments → New environment** → имя **`bicep`** (строго так).
2. Внутри **bicep** → **Environment secrets** добавьте три секрета (имена **строго** как ниже):
   - `AZURE_SUBSCRIPTION_ID`
   - `AZURE_TENANT_ID`
   - `AZURE_CLIENT_ID` (это **Application (client) ID** приложения в Entra)
3. Значения возьмите из шагов 1–3 ниже (CLI или портал).
4. В Entra для этого приложения настройте **Federated credential** под **GitHub Environment** с именем **`bicep`** (см. §3.2 — вариант «Environment»). Если у вас был только credential на **ветку `main`**, добавьте **второй** credential на environment **`bicep`** — subject в токене будет другим.
5. Роль приложению на подписку — §3.3.
6. **Actions → Azure — connection test → Run workflow** (ветка обычно `main`). В логе шага **«Подписка активна»** — `az account show`.

**Альтернатива без Environment:** удалите из YAML строку `environment: bicep` и храните `AZURE_*` как **Repository Secrets**; federated credential в Entra тогда на **Branch** (см. §3.2). Для client/tenant/subscription **нельзя** использовать обычные Variables — только Secrets, иначе значения светятся в логах.

---

## Шаг 1. Подписка Azure — `AZURE_SUBSCRIPTION_ID` (Variable)

1. Установите [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), выполните `az login`.
2. Выберите нужную подписку: `az account set --subscription "<имя или id>"`.
3. Получите id:

   ```bash
   az account show --query id -o tsv
   ```

4. В GitHub добавьте значение как **Environment secret** `AZURE_SUBSCRIPTION_ID` в окружении **`bicep`** (или как repository Variable, если workflow без `environment:`).

---

## Шаг 2. Каталог (tenant) — `AZURE_TENANT_ID` (Variable)

1. В том же сеансе CLI:

   ```bash
   az account show --query tenantId -o tsv
   ```

2. В GitHub: **Environment secret** **`AZURE_TENANT_ID`** в **`bicep`** (или repository Variable).

Альтернатива: портал **Microsoft Entra ID** → **Overview** → **Tenant ID**.

---

## Шаг 3. Приложение для CI (OIDC) — `AZURE_CLIENT_ID` (Variable / Secret)

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
4. Заполните поля GitHub (должны **точно** совпасть с тем, как у вас настроены workflow и GitHub):

   **Вариант A — только ветка (без `environment:` в workflow)**  
   - **Entity type:** **Branch**  
   - **GitHub branch name:** `main` (или `master`)  
   - Плюс **Organization** и **Repository** как у вас на GitHub.

   **Вариант B — как в текущих workflow репозитория (`environment: bicep`)**  
   - **Entity type:** **Environment**  
   - **Environment name:** **`bicep`** (то же имя, что в GitHub **Settings → Environments**)  
   - **Organization** и **Repository** — как у вас на GitHub.  
   Subject в портале будет вида `repo:ORG/REPO:environment:bicep` — при несовпадении с реальным environment вход OIDC падает.

5. **Credential details → Name** — обязательное имя credential (например `github-oidc-env-bicep`); **Description** можно оставить пустым. Поля **Issuer**, **Subject identifier** и **Audience** (`api://AzureADTokenExchange`) портал заполняет сам — их не копируют в GitHub.
6. Нажмите **Add** / сохраните credential.

**Что из обзора приложения куда класть (не путать):**

| Поле в портале (Overview приложения) | Куда в GitHub (текущие workflow) |
|--------------------------------------|-------------------------------------|
| **Application (client) ID** | **Secret** **`AZURE_CLIENT_ID`** в Environment **`bicep`** (или Repository Variable, если без `environment:`) |
| **Directory (tenant) ID** | **Secret** **`AZURE_TENANT_ID`** в **`bicep`** (или Variable на уровне репо) |
| **Object ID** | **Не** используется в `azure/login` |

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

### 3.4 Куда записать идентификаторы в GitHub

Для workflow с **`environment: bicep`**: **Settings → Environments → bicep → Environment secrets** — три секрета `AZURE_SUBSCRIPTION_ID`, `AZURE_TENANT_ID`, `AZURE_CLIENT_ID` (значения из шагов 1–3 и client id приложения).

**Client secret не создавайте** — при OIDC он не нужен.

---

## Шаг 4. Параметры Bicep (Variables)

Передаются в **`infra-bicep-what-if.yml`**. Удобно задать их как **Environment variables** в **`bicep`** (тот же раздел, что и secrets): тогда `vars.BICEP_*` подтянутся в job с `environment: bicep`. Иначе — **Repository** → Actions → **Variables** с теми же именами.

| Имя | Откуда взять | Пример |
|-----|--------------|--------|
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

1. **Azure — connection test** — зелёный логин и `az account show`; в **Preflight** нет критичных предупреждений по `BICEP_*` (если дальше нужен what-if).
2. **Infra — Bicep what-if** → **Run workflow**: для плана с кластером выберите **deploy_aks = true** и **deploy_acr = true**, либо заранее задайте Variables `BICEP_DEPLOY_AKS` / `BICEP_DEPLOY_ACR`.
3. Ошибка входа: federated credential под subject **environment:bicep** (или другой дизайн — см. §3.2). Роль SP на подписку достаточная для ARM what-if с AKS.

---

## Сводная таблица имён (текущие workflow с `environment: bicep`)

| Имя | Где задать | Обязательно |
|-----|------------|-------------|
| `AZURE_SUBSCRIPTION_ID` | **Repository** или **Environment** `bicep` → **Secret** | да |
| `AZURE_TENANT_ID` | то же | да |
| `AZURE_CLIENT_ID` | то же (OIDC) | да |
| `BICEP_PREFIX` | Environment **или** repository **Variable** | да (what-if) |
| `BICEP_LOCATION` | Environment **или** repository **Variable** | да (what-if) |
| `BICEP_ALERT_EMAIL` | Environment/repository **Variable** или **Secret** | да (what-if) |
| `BICEP_DEPLOY_AKS` | Variable | нет (`false`) |
| `BICEP_DEPLOY_ACR` | Variable | нет (`false`) |

---

## Организационные variables

Если репозиторий в **организации**, те же имена можно задать на уровне **Org → Settings → Variables** и наследовать в репозитории (политика наследования настраивается отдельно). Для личного аккаунта достаточно **repository variables**.

---

## Ошибка `AADSTS700016: Application with identifier '…' was not found in the directory`

Значит **в указанном tenant нет** приложения с таким **Application (client) ID** (или в GitHub в secret попал не тот GUID).

1. Проверьте **`AZURE_TENANT_ID`**: это **Directory (tenant) ID** каталога, где создано **именно это** App registration (Entra → приложение → Overview).  
2. Проверьте **`AZURE_CLIENT_ID`**: только **Application (client) ID** с той же карточки, не Object ID и не id подписки.  
3. Локально: `az login --tenant "<TENANT_ID>"` затем `az ad app show --id "<CLIENT_ID>"` — если ошибка, пара tenant/client неверна или приложение в другом каталоге.

---

## Ошибка `AADSTS700213: No matching federated identity record found for presented assertion subject 'repo:…:environment:bicep'`

GitHub выдал токен с subject вида **`repo:ORG/REPO:environment:bicep`**, а в Entra **нет** federated credential с таким же subject (часто создан только credential на **ветку** `ref:refs/heads/main`).

1. Откройте **то же** App registration → **Federated credentials** → **Add credential**.  
2. Выберите **Entity type: Environment**, **Environment name: `bicep`**, **Organization** и **Repository** как в логе ошибки (должны совпасть с URL репозитория на GitHub).  
3. Сохраните. Старый credential на **Branch** можно оставить — для workflow с `environment: bicep` он не подставляется автоматически.
