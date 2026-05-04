# OmniScope examples — **AKS only** (no Docker Compose)

Sample **Go** microservices and Kubernetes manifests to run on **Azure Kubernetes Service (AKS)** with **Azure Container Registry (ACR)** for your own images. OpenTelemetry **Collector** and **Jaeger** use **public** images from the manifest files (you can later mirror them to ACR if your policy requires private-only pulls).

For the relationship **ACR ↔ AKS**, **build/push/deploy**, and **Azure Repos** + Azure Pipelines, see **[`docs/AKS-ACR-CICD.md`](./docs/AKS-ACR-CICD.md)**.

---

## Layout

| Path | Purpose |
|------|---------|
| `services/service-a`, `services/service-b` | `Dockerfile` + Go sources for `docker build` / pipeline build. |
| `kubernetes/` | Namespaced workloads for AKS (`omniscope` namespace). |
| `docs/AKS-ACR-CICD.md` | ACR, AKS, CI/CD, Azure Repos. |
| `otel-collector-config.yaml` | Optional reference copy of the collector config (source of truth in `kubernetes/otel/20-otel-configmap.yaml`). |

---

## Prerequisites

- An AKS cluster (this repo’s Bicep can create **AKS + ACR + AcrPull** — see `infra/bicep/README.md`).
- `kubectl` and `az` CLI; kubeconfig from `az aks get-credentials`.
- Images **pushed** to your ACR: repositories `omniscope-service-a` and `omniscope-service-b` (tags must match manifests, e.g. `latest` or your CI tag).

---

## 1. Build and push images to ACR

```bash
export ACR_LOGIN_SERVER="yourregistry.azurecr.io"   # from deployment output acrLoginServer

az acr login --name "${ACR_LOGIN_SERVER%%.azurecr.io}"

docker build -t "${ACR_LOGIN_SERVER}/omniscope-service-a:latest" services/service-a
docker push "${ACR_LOGIN_SERVER}/omniscope-service-a:latest"

docker build -t "${ACR_LOGIN_SERVER}/omniscope-service-b:latest" services/service-b
docker push "${ACR_LOGIN_SERVER}/omniscope-service-b:latest"
```

---

## 2. Substitute registry in app manifests

Manifests use the placeholder **`__ACR_LOGIN_SERVER__`** (FQDN only, e.g. `myregistry.azurecr.io`).

```bash
export ACR_LOGIN_SERVER="yourregistry.azurecr.io"
sed "s|__ACR_LOGIN_SERVER__|${ACR_LOGIN_SERVER}|g" kubernetes/apps/service-a.yaml > /tmp/service-a.rendered.yaml
sed "s|__ACR_LOGIN_SERVER__|${ACR_LOGIN_SERVER}|g" kubernetes/apps/service-b.yaml > /tmp/service-b.rendered.yaml
```

Or use `envsubst` if your shell has it (see `docs/AKS-ACR-CICD.md`).

---

## 3. Apply to AKS

From the `examples` directory:

```bash
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/otel/
kubectl apply -f /tmp/service-a.rendered.yaml
kubectl apply -f /tmp/service-b.rendered.yaml
```

**Port-forward** (no Ingress in this minimal set):

```bash
kubectl -n omniscope port-forward svc/service-a 8081:8081 &
kubectl -n omniscope port-forward svc/service-b 8082:8082 &
kubectl -n omniscope port-forward svc/jaeger 16686:16686 &
```

- Service A: http://localhost:8081/hello-a — chain call: http://localhost:8081/call-b  
- Service B: http://localhost:8082/hello-b  
- Jaeger UI: http://localhost:16686  

---

## 4. Optional: full OpenTelemetry demo

For a complete shop demo with many languages, use the upstream project:

```bash
git clone https://github.com/open-telemetry/opentelemetry-demo.git
```

---

## Inspiration

Patterns align with ideas from `observability-zero-to-hero` and the collector-first approach of [`open-telemetry/opentelemetry-demo`](https://github.com/open-telemetry/opentelemetry-demo).
