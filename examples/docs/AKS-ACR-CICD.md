# AKS, Azure Container Registry (ACR), and Azure Repos

This document explains how **Azure Container Registry** relates to **Azure Kubernetes Service (AKS)**, how **build and deploy** typically work, and how **Azure Repos** (Git in **Azure DevOps**) fits in.

---

## 1. ACR ↔ AKS (artifact registry and the cluster)

| Concept | Role |
|--------|------|
| **ACR** | Private **OCI registry** (Docker/OCI images). Stores your built images (`service-a`, `service-b`, …). |
| **AKS** | Runs **Pods** whose containers reference `image: <registry>/<repo>:<tag>`. |
| **Pull** | Each node must be **allowed** to pull from ACR. That is not automatic: you attach identity + **AcrPull** (or equivalent) to the **kubelet** managed identity used by the node pool. |

**In this repository**, Bicep can create an ACR next to your RG, deploy AKS, then assign **AcrPull** on that registry to the cluster **kubelet** identity (`infra/bicep/main.bicep` + `modules/acr-kubelet-pull.bicep`). After that, manifests can use `image: <youracr>.azurecr.io/omniscope-service-a:1.0.0` without embedding registry credentials in Kubernetes Secrets (for this pull path).

**Alternatives** (not in Bicep here, but common):

- `az aks attach-acr --name <aks> --resource-group <rg> --acr <acrNameOrId>` (same AcrPull wiring, CLI-driven).
- **Workload Identity** / **imagePullSecrets** for other pull models (different registries, cross-tenant, etc.).

---

## 2. Build & deploy (high-level flow)

```text
┌─────────────────┐     ┌──────────────┐     ┌─────────┐     ┌─────┐
│  Azure Repos    │────▶│ CI pipeline  │────▶│   ACR   │────▶│ AKS │
│  (git push)     │     │ docker build │     │  push   │     │apply│
│                 │     │ + tag        │     │         │     │ yaml│
└─────────────────┘     └──────────────┘     └─────────┘     └─────┘
```

1. **Source** lives in **Azure Repos** (or GitHub, GitLab — same idea).
2. **CI** (Azure Pipelines, GitHub Actions, etc.) runs on each merge or tag:
   - `docker build` for each service (from `examples/services/service-a`, `service-b`, …).
   - `docker tag` with ACR login server + repository + immutable tag (build id or git SHA).
   - `az acr login` + `docker push` to ACR (or use `AzureCLI@2` / `Docker@2` tasks).
3. **CD** updates the cluster:
   - `kubectl set image` / `kustomize edit set image` / Helm upgrade with new tag, **or**
   - GitOps (Flux / Argo CD) reconciles manifests from a repo branch that references the new tag.

**Immutable tags** (digest or `:$(Build.BuildId)` / git SHA) are strongly recommended so rollbacks and audits are clear.

---

## 3. Azure Repos specifically

**Azure Repos** is only **Git hosting** inside **Azure DevOps**. It does not build or push images by itself.

Typical setup:

| Piece | Where it lives |
|-------|------------------|
| Application + `Dockerfile` | **Azure Repos** (this repo mirrored or imported). |
| Pipeline YAML | Same repo (`azure-pipelines.yml`) or separate “platform” repo. |
| **Service connection** | Azure DevOps → **ARM** + **ACR** (managed identity or service principal with `AcrPush` on the registry, `Azure Kubernetes Service Cluster User Role` or deploy rights on AKS). |
| **Secrets** | **Variable groups** / **Key Vault** task references — not committed to Git. |

**Minimal Azure Pipelines outline**

- Trigger: branch `main` or PR validation.
- Stage **Build**: pool with Docker; build context `examples/services/service-a`; push to `$(acrLoginServer)/omniscope-service-a:$(Build.BuildId)`.
- Repeat for `service-b`.
- Stage **Deploy**: `AzureCLI@2` with `az aks get-credentials` (kubelogin + Azure AD if required by your cluster), then `kubectl apply -k` or apply rendered manifests with the same `$(Build.BuildId)` tag.

Use **environments** and **approvals** in Azure DevOps for production clusters.

---

## 4. Mapping to files in this repo

| Item | Location |
|------|----------|
| Docker build contexts | `examples/services/service-a`, `examples/services/service-b` |
| Kubernetes manifests (AKS) | `examples/kubernetes/` — replace `__ACR_LOGIN_SERVER__` before apply (or use your templating) |
| IaC: LAW + App Insights + Action Group + optional **ACR + AKS + AcrPull** | `infra/bicep/main.bicep` |

---

## 5. Quick commands (after Bicep deploy)

```bash
# Values from deployment outputs
ACR_LOGIN_SERVER="<acrLoginServer>"   # e.g. omnixyz.azurecr.io
RG="<resourceGroupName>"
AKS="<aksName>"

az acr login --name "${ACR_LOGIN_SERVER%%.azurecr.io}"
docker build -t "${ACR_LOGIN_SERVER}/omniscope-service-a:1" examples/services/service-a
docker push "${ACR_LOGIN_SERVER}/omniscope-service-a:1"
docker build -t "${ACR_LOGIN_SERVER}/omniscope-service-b:1" examples/services/service-b
docker push "${ACR_LOGIN_SERVER}/omniscope-service-b:1"

az aks get-credentials --resource-group "$RG" --name "$AKS"

export ACR_LOGIN_SERVER
envsubst < examples/kubernetes/apps/service-a.yaml | kubectl apply -f -
envsubst < examples/kubernetes/apps/service-b.yaml | kubectl apply -f -
```

If you do not use `envsubst`, use `sed` as described in `examples/README.md`.

Apply observability stack manifests (public images) first, then app deployments:

```bash
kubectl apply -f examples/kubernetes/namespace.yaml
kubectl apply -f examples/kubernetes/otel/
kubectl apply -f examples/kubernetes/apps/   # after substituting ACR in YAML
```

---

## 6. When you do **not** want ACR in IaC

Set Bicep parameter `deployAcr=false`. You can still use another registry (shared ACR, ACR in another subscription) and attach it manually or extend IaC with a second role assignment for that registry’s resource ID.
