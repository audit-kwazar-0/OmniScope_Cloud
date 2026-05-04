# OmniScope Cloud

**Azure observability reference** — architecture documentation, parallel Infrastructure-as-Code (Bicep, Terraform, Pulumi), and a **local OpenTelemetry** playground you can run with Docker Compose.

---

## Highlights

| Area | What you get |
|------|----------------|
| **Architecture** | End-to-end observability design for Azure (metrics, logs, traces, Grafana, alerting, IaC narrative) in [`doc-site/`](./doc-site/). |
| **Infrastructure** | Minimal **test** baseline: Resource Group, Log Analytics, Application Insights (linked to LAW), Action Group — plus optional **AKS** in Bicep. Three implementations: [`infra/bicep/`](./infra/bicep/), [`infra/terraform/`](./infra/terraform/), [`infra/pulumi/`](./infra/pulumi/). |
| **Examples** | Two Go services, **OTLP → Collector → Jaeger + Prometheus** — see [`examples/`](./examples/). |

---

## Repository layout

```text
OmniScope_Cloud/
├── doc-site/           # VitePress docs (config + Markdown)
├── examples/           # Local OTel stack (docker compose)
├── infra/
│   ├── bicep/          # ARM/Bicep (incl. optional AKS)
│   ├── pulumi/         # Pulumi (TypeScript)
│   ├── terraform/      # Terraform (azurerm)
│   └── README.md       # Shared parameters & extension ideas
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

---

## Quick start

### Local observability examples

Requires **Docker** and **Docker Compose v2**.

```bash
cd examples
docker compose up --build
```

| Endpoint | URL |
|----------|-----|
| Service A | [http://localhost:8081](http://localhost:8081) — try `/hello-a`, `/call-b` |
| Service B | [http://localhost:8082](http://localhost:8082) — try `/hello-b`, `/call-a` |
| Jaeger UI | [http://localhost:16686](http://localhost:16686) |
| Prometheus | [http://localhost:9090](http://localhost:9090) |

Stop with `docker compose down`. Full details: [`examples/README.md`](./examples/README.md).

### Azure baseline (Bicep)

Prerequisites: **Azure CLI**, `az login`. Example deployment at subscription scope:

```bash
cd infra/bicep
az deployment sub create \
  --location westeurope \
  --template-file ./main.bicep \
  --parameters \
    prefix="omniscope-obs-test" \
    alertEmail="oncall@example.com"
```

Parameter reference: [`infra/bicep/README.md`](./infra/bicep/README.md). Terraform and Pulumi equivalents live under [`infra/terraform/`](./infra/terraform/) and [`infra/pulumi/`](./infra/pulumi/); shared concepts are summarized in [`infra/README.md`](./infra/README.md).

### Documentation site

Sources live under [`doc-site/`](./doc-site/) (VitePress: `.vitepress/config.ts` + `index.md`). To preview locally, add a `package.json` in `doc-site/` with the [VitePress](https://vitepress.dev/) dependency and run the dev server from that directory, or read [`doc-site/index.md`](./doc-site/index.md) directly.

---

## GitHub

Suggested **repository description**:

> Azure observability reference: docs (VitePress), parallel IaC (Bicep / Terraform / Pulumi), local OpenTelemetry examples (Go, Collector, Jaeger, Prometheus).

Suggested **topics**: `azure`, `observability`, `opentelemetry`, `application-insights`, `log-analytics`, `bicep`, `terraform`, `pulumi`, `aks`, `prometheus`, `docker-compose`, `vitepress`.

---

## Contributing

We welcome issues and pull requests. Please read [`CONTRIBUTING.md`](./CONTRIBUTING.md) before submitting changes.

---

## License

This project is released under the [MIT License](./LICENSE).
