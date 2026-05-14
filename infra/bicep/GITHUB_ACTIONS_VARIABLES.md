# GitHub Actions: variables and secrets for Azure (Bicep)

Below is the **recommended order**: first obtain values in Azure / Entra, then store them in GitHub. Split between **Variables** (non-sensitive strings) and **Secrets** (must not appear in logs).

Paths in GitHub:

- **Repository** → **Settings** → **Secrets and variables** → **Actions** — repository-wide **Variables** and **Secrets**.
- **Settings** → **Environments** → environment **`bicep`** — optional **Environment secrets** / **Environment variables** (isolation, protection rules, separate prod/test values).

Workflows **`.github/workflows/azure-connection-test.yml`** and **`.github/workflows/infra-bicep-what-if.yml`** set **`environment: bicep`** on the job. The OIDC token subject is then **`repo:ORG/REPO:environment:bicep`** — Entra must have a federated credential for **Environment** named **`bicep`** (see Section 3.2).

**Context merging:** `secrets.AZURE_*` and `vars.BICEP_*` are visible to the job from both **repository** and **environment** `bicep` (when names collide, the narrower scope usually wins — [Variables](https://docs.github.com/en/actions/learn-github-actions/variables), [Secrets](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions)). A successful **Azure — connection test** only proves: OIDC + three Azure identifiers. For **Infra — Bicep what-if** you also need **Variables** `BICEP_PREFIX`, `BICEP_LOCATION`, and email `BICEP_ALERT_EMAIL` (variable or secret); for a plan **with AKS and ACR** — also `BICEP_DEPLOY_AKS=true` and `BICEP_DEPLOY_ACR=true` **or** when running what-if manually pick **deploy_aks / deploy_acr = true** in the form (override without changing Variables).

After **connection test**, read the **Preflight** step — it warns if something is missing for what-if.

---

## Where **Run workflow** is and why it might be missing

1. **Open the page for a single workflow (not only the list of all runs).**  
   - Option A: **Actions** tab → in the **left column** pick a **workflow name**, e.g. **Azure — connection test** or **Manual — self-test (dispatch only)** → **Run workflow** and branch selector appear on the right.  
   - Option B (direct URL): `https://github.com/<ORG>/<REPO>/actions/workflows/<workflow-file.yml>` — e.g. `.../actions/workflows/run-pipeline.yml` (main manual pipeline) or `.../actions/workflows/teardown-skeleton.yml`. On that page the button is usually **above** the list of past runs.  
   If you stay only on `/actions` without selecting a workflow on the left, the button often **does not show**.
2. **Manual runs require `workflow_dispatch`.** Workflows with only `push` / `pull_request` / `schedule` do not offer Run. Files with **only** `on: workflow_call` (e.g. **Reusable — build & push**) generally **have no** Run button — another workflow calls them.
3. **The file with `workflow_dispatch` must be on the default branch on GitHub.** You may have the YAML locally in Cursor, but until changes are **pushed + merged to main** (or your default branch), the site shows an older version without the button.
4. **Permissions:** Run requires permission to change Actions (usually **Write** or **Maintain**). With **Read** there is no button. Organizations may add **org policies**.
5. **Actions disabled:** **Settings → Actions → General** — check that **GitHub Actions** is allowed and individual workflows are not disabled (**⋯** → disable).
6. **Forks:** in your fork, **Settings → Actions** often needs manual enablement.
7. **Mobile GitHub:** very simplified UI — Run may be missing; use a desktop browser.

**Quick check:** after merge to default branch open **Run pipeline — Bicep & Azure** (`run-pipeline.yml`), choose mode **bicep_validate**, click **Run workflow**. If there is no button, see permissions, default branch, and Actions settings above.

---

## Pipeline chain (OIDC → what-if → AKS in plan)

**Single manual entry:** **Run pipeline — Bicep & Azure** (`.github/workflows/run-pipeline.yml`) — modes `bicep_validate` → `azure_connection` → `subscription_what_if`. Older standalone workflows (**Azure — connection test**, **Infra — Bicep what-if**) can stay for familiarity; what-if logic matches.

| Step | Workflow / mode | What is verified | What is missing for the next step |
|------|-----------------|------------------|-------------------------------------|
| 1 | **Run pipeline** → `azure_connection` **or** **Azure — connection test** | Federated credential `environment:bicep`, `AZURE_*` **Secrets**, role on subscription, `az account show` | — |
| 2 | **Run pipeline** → `subscription_what_if` **or** **Infra — Bicep what-if** | OIDC + Bicep parameters + `az deployment sub what-if` | Without `BICEP_*` fails configuration check; without `deployAks=true` in plan **AKS/ACR do not appear** |
| 3 | Real deploy | Locally `./deploy.sh deploy` or separate CD (this repo currently only what-if, not `deployment sub create`) | Separate decision: approvals, another workflow |

**Entra app role on subscription:** what-if with AKS usually needs the same breadth as create (often **Contributor** on a test subscription; **Reader** alone may be insufficient for complex templates). Plus subscription quotas for compute / AKS in `BICEP_LOCATION`.

---

## Step zero: verify Azure connection (`Azure — connection test`)

1. Create environment: **Settings → Environments → New environment** → name **`bicep`** (exactly).
2. Inside **bicep** → **Environment secrets** add three secrets (names **exactly** as below):
   - `AZURE_SUBSCRIPTION_ID`
   - `AZURE_TENANT_ID`
   - `AZURE_CLIENT_ID` (this is the app’s **Application (client) ID** in Entra)
3. Take values from steps 1–3 below (CLI or portal).
4. In Entra for that app configure **Federated credential** for **GitHub Environment** named **`bicep`** (see Section 3.2, “Environment” variant). If you only had a credential on **branch `main`**, add a **second** credential for environment **`bicep`** — the token subject differs.
5. Grant the app a role on the subscription — Section 3.3.
6. **Actions → Azure — connection test → Run workflow** (branch usually `main`). In the log, step **“Subscription active”** runs `az account show`.

**Alternative without Environment:** remove `environment: bicep` from the YAML and store `AZURE_*` as **Repository Secrets**; federated credential in Entra is then on **Branch** (Section 3.2). For client/tenant/subscription **do not** use plain Variables — only Secrets, or values leak in logs.

---

## Step 1. Azure subscription — `AZURE_SUBSCRIPTION_ID` (Variable)

1. Install [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), run `az login`.
2. Select subscription: `az account set --subscription "<name or id>"`.
3. Get id:

   ```bash
   az account show --query id -o tsv
   ```

4. In GitHub add the value as **Environment secret** `AZURE_SUBSCRIPTION_ID` in **`bicep`** (or as repository Variable if the workflow has no `environment:`).

---

## Step 2. Directory (tenant) — `AZURE_TENANT_ID` (Variable)

1. In the same CLI session:

   ```bash
   az account show --query tenantId -o tsv
   ```

2. In GitHub: **Environment secret** **`AZURE_TENANT_ID`** in **`bicep`** (or repository Variable).

Alternative: portal **Microsoft Entra ID** → **Overview** → **Tenant ID**.

---

## Step 3. CI app (OIDC) — `AZURE_CLIENT_ID` (Variable / Secret)

You need an **App registration** (service principal) that GitHub uses to sign in **without a password**, via **federated credential** (OIDC).

### 3.1 Create app registration

1. Portal **Microsoft Entra ID** → **App registrations** → **New registration**.
2. Name, e.g.: `github-omniscope-bicep`.
3. After creation open the app → **Application (client) ID** — that is the value for GitHub.

### 3.2 Federated credential (GitHub → Azure link)

This is a **separate step after** creating the app (3.1). Without a federated credential GitHub **cannot** issue an OIDC token and `azure/login` fails.

1. Open the **same** app: **Microsoft Entra ID** → **App registrations** → your app (e.g. `github-omniscope-bicep`).
2. Left menu: **Certificates & secrets** → **Federated credentials** tab → **Add credential**.  
   (In some portals **Federated credentials** is also in the app left menu.)
3. **Credential type / scenario**: choose something like **GitHub Actions deploying Azure resources** (UI wording may vary).
4. Fill GitHub fields (must **exactly** match your workflows and repo):

   **Option A — branch only (no `environment:` in workflow)**  
   - **Entity type:** **Branch**  
   - **GitHub branch name:** `main` (or `master`)  
   - Plus **Organization** and **Repository** as on GitHub.

   **Option B — as in this repo’s workflows (`environment: bicep`)**  
   - **Entity type:** **Environment**  
   - **Environment name:** **`bicep`** (same as GitHub **Settings → Environments**)  
   - **Organization** and **Repository** as on GitHub.  
   Portal subject looks like `repo:ORG/REPO:environment:bicep` — if it does not match the real environment, OIDC login fails.

5. **Credential details → Name** — required credential name (e.g. `github-oidc-env-bicep`); **Description** can be empty. **Issuer**, **Subject identifier**, and **Audience** (`api://AzureADTokenExchange`) are filled by the portal — do not copy them to GitHub.
6. Click **Add** / save.

**Mapping app overview fields to GitHub (do not mix up):**

| Portal field (app Overview) | Where in GitHub (current workflows) |
|-----------------------------|--------------------------------------|
| **Application (client) ID** | **Secret** **`AZURE_CLIENT_ID`** in Environment **`bicep`** (or Repository Variable without `environment:`) |
| **Directory (tenant) ID** | **Secret** **`AZURE_TENANT_ID`** in **`bicep`** (or repo-level Variable) |
| **Object ID** | **Not** used by `azure/login` |

After save, the federated credentials list shows **Issuer** and **Subject** — you **do not** manually copy them to GitHub: `azure/login` derives them from `github.token` at OIDC time.

More: [Use the Azure Login action with OpenID Connect](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure).

### 3.3 Subscription (or RG) permissions

The app’s **service principal** needs a role sufficient for **deployment** and **what-if** on the target scope (often **Contributor** on the subscription for test — narrow to Resource Group in prod).

```bash
# client id from app portal
APP_ID="<AZURE_CLIENT_ID>"

az ad sp create --id "$APP_ID" 2>/dev/null || true

SUBSCRIPTION_ID="$(az account show --query id -o tsv)"

az role assignment create \
  --assignee "$APP_ID" \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"
```

For production prefer a **dedicated subscription** or scope to a specific RG.

### 3.4 Where to store identifiers in GitHub

For workflows with **`environment: bicep`**: **Settings → Environments → bicep → Environment secrets** — three secrets `AZURE_SUBSCRIPTION_ID`, `AZURE_TENANT_ID`, `AZURE_CLIENT_ID` (values from steps 1–3 and the app’s client id).

**Do not create a client secret** — not needed with OIDC.

---

## Step 4. Bicep parameters (Variables)

Passed to **`infra-bicep-what-if.yml`**. Convenient to set as **Environment variables** in **`bicep`** (same section as secrets): then `vars.BICEP_*` load in jobs with `environment: bicep`. Otherwise — **Repository** → Actions → **Variables** with the same names.

| Name | Source | Example |
|------|--------|---------|
| **`BICEP_PREFIX`** | Your resource name prefix (unique in subscription) | `omniscope-obs-test` |
| **`BICEP_LOCATION`** | ARM metadata / resource region | `westeurope` or `northeurope` |
| **`BICEP_ALERT_EMAIL`** | Email for Action Group (required template parameter) | work email |

Optional (if unset, workflows default to **`false`**):

| Name | Purpose |
|------|---------|
| **`BICEP_DEPLOY_AKS`** | `true` / `false` — deploy AKS |
| **`BICEP_DEPLOY_ACR`** | `true` / `false` — create ACR (meaningful with AKS) |

---

## Step 5. Email as Secret (optional)

If you do not want the email in Variables:

1. Remove variable `BICEP_ALERT_EMAIL` if you created it.
2. Create secret **`BICEP_ALERT_EMAIL`** with the same value.
3. Workflows already prefer **secret**, then **variable**.

---

## Step 6. Verification

1. **Azure — connection test** — green login and `az account show`; **Preflight** has no blocking warnings for `BICEP_*` (if you need what-if next).
2. **Infra — Bicep what-if** → **Run workflow**: for a plan with cluster pick **deploy_aks = true** and **deploy_acr = true**, or set Variables `BICEP_DEPLOY_AKS` / `BICEP_DEPLOY_ACR` ahead of time.
3. Login errors: federated credential for subject **environment:bicep** (or your chosen design — Section 3.2). SP role on subscription sufficient for ARM what-if with AKS.

---

## Name summary (current workflows with `environment: bicep`)

| Name | Where to set | Required |
|------|--------------|----------|
| `AZURE_SUBSCRIPTION_ID` | **Repository** or Environment **`bicep`** → **Secret** | yes |
| `AZURE_TENANT_ID` | same | yes |
| `AZURE_CLIENT_ID` | same (OIDC) | yes |
| `BICEP_PREFIX` | Environment **or** repository **Variable** | yes (what-if) |
| `BICEP_LOCATION` | Environment **or** repository **Variable** | yes (what-if) |
| `BICEP_ALERT_EMAIL` | Environment/repository **Variable** or **Secret** | yes (what-if) |
| `BICEP_DEPLOY_AKS` | Variable | no (`false`) |
| `BICEP_DEPLOY_ACR` | Variable | no (`false`) |

---

## Organization-level variables

If the repo is in an **organization**, you can define the same names under **Org → Settings → Variables** and inherit into repos (inheritance policy is separate). For a personal account, **repository variables** are enough.

---

## Error `AADSTS700016: Application with identifier '…' was not found in the directory`

The **tenant you specified does not contain** an app with that **Application (client) ID** (or GitHub has the wrong GUID).

1. Check **`AZURE_TENANT_ID`**: **Directory (tenant) ID** of the directory where this **exact** app registration lives (Entra → app → Overview).  
2. Check **`AZURE_CLIENT_ID`**: only **Application (client) ID** from the same blade — not Object ID, not subscription id.  
3. Locally: `az login --tenant "<TENANT_ID>"` then `az ad app show --id "<CLIENT_ID>"` — if it errors, tenant/client is wrong or the app is in another directory.

---

## Error `AADSTS700213: No matching federated identity record found for presented assertion subject 'repo:…:environment:bicep'`

GitHub issued a token with subject **`repo:ORG/REPO:environment:bicep`**, but Entra has **no** federated credential with that subject (often only a **branch** credential `ref:refs/heads/main` exists).

1. Open the **same** App registration → **Federated credentials** → **Add credential**.  
2. Choose **Entity type: Environment**, **Environment name: `bicep`**, **Organization** and **Repository** as in the error log (must match the GitHub repo URL).  
3. Save. You can keep the old **Branch** credential — workflows with `environment: bicep` do not use it automatically.
