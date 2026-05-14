# OmniScope: story of building the observability architecture

This platform was built as a practical engineering loop, not a slide-deck demo.  
The goal was simple: at any time you can stand up infrastructure from scratch, deploy services, see metrics/logs/traces, and quickly see where the problem is.

## Why the project is structured this way

In observability projects, what usually breaks is not data collection but the links between layers:

- infrastructure lives apart from applications;
- metrics exist without log and trace context;
- alerts fire without a clear “what to open next.”

So OmniScope’s philosophy is **one operational flow**:

1. IaC describes the full platform;
2. the application deploys into the same ring;
3. observability is on by default;
4. every signal has a path to action (alert → action group → channel).

## How the architecture came together

I started from the core in `infra/bicep` and locked in a minimally useful set:

- `Log Analytics Workspace` as the base log layer;
- `Application Insights` for traces and APM;
- `AKS` as the target runtime;
- `Action Group` for notifications.

Then I added extensions that give a “real operations” picture:

- `Azure Monitor Workspace` + `Managed Grafana` (metrics and dashboards);
- `Event Hub` + `LAW Data Export` as a path to OpenSearch/Elastic;
- `AKS control-plane diagnostics` into LAW;
- alerts for infrastructure and application layers.

The key principle is full parameterization so the same template works for minimal and full profiles.

## Application observability as part of the platform

I kept two simple services (`service-a`, `service-b`) but made them real in terms of signals:

- OpenTelemetry tracing via OTel Collector;
- custom business metrics:
  - `omniscope_processed_messages_total`
  - `omniscope_processing_errors_total`
- the `/call-b` chain to show an end-to-end trace.

That way we see not only “the cluster is up” but **actual business flow behavior**.

## What implementation surfaced

Typical Azure nuances showed up that rarely appear on pretty diagrams:

- SKU limits by region/subscription;
- activation delay for some resources (e.g. LAW export);
- API version mismatches for certain resource types;
- scheduled query rule format details.

Those scenarios stay in runbooks/evidence because that is how the platform is actually run.

## What matters for the team

OmniScope is a **repeatable engineering process**:

- the platform can be raised from one IaC path;
- application and observability deploy predictably;
- smoke/evidence give a clear definition of done;
- documentation describes a real working path, not theory.

In short: not just “monitoring in Azure,” but **operational architecture** where any incident can go from symptom to cause without manual magic.
