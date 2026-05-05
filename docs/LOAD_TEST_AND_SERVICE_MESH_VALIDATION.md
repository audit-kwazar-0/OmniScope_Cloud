# Load Test + Service Mesh Validation

## 1. Scope

This checklist is a practical validation playbook for:
- standard observability metrics coverage,
- load testing readiness and execution,
- Service Mesh and connectivity validation.

Use it after base deployment from `docs/DEPLOYMENT_RUNBOOK.md`.

## 2. Standard metrics checklist

## 2.1 Cluster / Nodes

- [ ] CPU usage and saturation
- [ ] Memory usage and pressure
- [ ] Disk I/O and disk usage
- [ ] Network RX/TX throughput
- [ ] `NodeReady` state
- [ ] Pressure conditions (`MemoryPressure`, `DiskPressure`, `PIDPressure`)

Quick checks:

```bash
kubectl get nodes
kubectl describe node <node-name>
kubectl top nodes
```

## 2.2 Kubernetes Control Signals

- [ ] Pod restarts trend
- [ ] `CrashLoopBackOff` workloads
- [ ] Pending pods and scheduling failures
- [ ] Deployment unavailable replicas
- [ ] HPA behavior during load

Quick checks:

```bash
kubectl get pods -A
kubectl get events -A --sort-by=.lastTimestamp
kubectl get deploy -A
kubectl get hpa -A
```

## 2.3 Container Health

- [ ] CPU throttling
- [ ] Memory working set vs limits
- [ ] OOM kills
- [ ] Container filesystem usage

PromQL examples:

```promql
sum(rate(container_cpu_cfs_throttled_seconds_total{namespace="omniscope"}[5m])) by (pod)
```

```promql
sum(container_memory_working_set_bytes{namespace="omniscope"}) by (pod)
```

```promql
sum(increase(kube_pod_container_status_restarts_total{namespace="omniscope"}[15m])) by (pod)
```

## 2.4 Application RED/USE

- [ ] Request rate
- [ ] Error rate (4xx/5xx or app errors)
- [ ] Latency p50/p95/p99
- [ ] Saturation (queue depth, worker busy ratio, or CPU/memory proxy)

OmniScope metrics:

```promql
sum(rate(omniscope_processed_messages_total[5m])) by (service)
```

```promql
sum(rate(omniscope_processing_errors_total[5m])) by (service)
```

```promql
100 * sum(rate(omniscope_processing_errors_total[10m])) / clamp_min(sum(rate(omniscope_processed_messages_total[10m])), 1)
```

## 2.5 Tracing / APM

- [ ] Endpoint duration (p50/p95/p99)
- [ ] Error spans
- [ ] Dependency latency
- [ ] Top failing operations

Suggested App Insights checks:
- failed requests by operation name,
- dependencies with high duration,
- traces filtered by `operation_Id`.

## 2.6 Logs and Correlation

- [ ] Error log rate trend
- [ ] `trace_id` / `request_id` correlation from alert to logs
- [ ] Service hop visibility (`service-a -> service-b`)

KQL examples (LAW):

```kql
ContainerLogV2
| where TimeGenerated > ago(30m)
| where KubernetesNamespace == "omniscope"
| where LogLevel in~ ("error", "critical") or LogMessage has_any ("error", "exception", "failed")
| summarize errors=count() by bin(TimeGenerated, 5m), KubernetesPodName
| order by TimeGenerated asc
```

```kql
ContainerLogV2
| where TimeGenerated > ago(30m)
| where KubernetesNamespace == "omniscope"
| where LogMessage has "<trace_id>"
| project TimeGenerated, KubernetesPodName, LogMessage
| order by TimeGenerated desc
```

## 2.7 SLO / Alerts

- [ ] Availability SLI/SLO
- [ ] Latency SLO (p95/p99 target)
- [ ] Error budget burn rate
- [ ] Alerts routed to Action Group with actionable context

---

## 3. Load testing checklist

## 3.1 Test design

- [ ] Test type selected: baseline / stress / spike / endurance / soak
- [ ] Workload profile defined: RPS, duration, ramp-up/ramp-down
- [ ] Endpoint mix defined: `/hello-a`, `/call-b`, `/hello-b`
- [ ] Success criteria approved before start

Recommended initial thresholds:
- p95 latency: `< 300ms`,
- error rate: `< 1-2%`,
- no sustained saturation causing availability impact.

## 3.2 Environment controls

- [ ] Dedicated namespace/profile for load tests
- [ ] Fixed image tags (no floating release changes during run)
- [ ] Stable cluster autoscaling policy for test window
- [ ] No parallel disruptive maintenance operations

## 3.3 k6 sample

Use repository script:
- `tests/load/k6-omniscope.js`
- baseline: `tests/load/baseline.json`
- runner: `scripts/run-load-test.sh`

Run locally:

```bash
BASE_URL=http://localhost:8081 ./scripts/run-load-test.sh
```

Run with stricter regression gate:

```bash
BASE_URL=http://localhost:8081 ALLOW_REGRESSION_PERCENT=5 ./scripts/run-load-test.sh
```

The script exports k6 summary JSON under `tests/load/results/`.

Reference script content:

```javascript
import http from "k6/http";
import { check, sleep } from "k6";

export const options = {
  scenarios: {
    baseline: {
      executor: "ramping-arrival-rate",
      startRate: 5,
      timeUnit: "1s",
      preAllocatedVUs: 20,
      maxVUs: 200,
      stages: [
        { target: 20, duration: "5m" },
        { target: 50, duration: "10m" },
        { target: 0, duration: "3m" }
      ]
    }
  },
  thresholds: {
    http_req_failed: ["rate<0.02"],
    http_req_duration: ["p(95)<300"]
  }
};

const base = __ENV.BASE_URL || "http://localhost:8081";

export default function () {
  const r1 = http.get(`${base}/hello-a`);
  check(r1, { "hello-a 200": (r) => r.status === 200 });

  const r2 = http.get(`${base}/call-b`);
  check(r2, { "call-b 200": (r) => r.status === 200 });

  sleep(0.2);
}
```

CI automation:
- workflow: `.github/workflows/load-test.yml`
- trigger: `workflow_dispatch` and nightly schedule
- artifacts: k6 summary JSON uploaded from each run

## 3.4 Runtime observability during load

- [ ] Grafana dashboard open (latency, errors, throughput, node/pod saturation)
- [ ] App Insights live traces for hot endpoints
- [ ] LAW log stream filtered by namespace and trace correlation
- [ ] HPA status watched during ramp phases

Useful commands:

```bash
kubectl -n omniscope get pods -w
kubectl -n omniscope get hpa -w
kubectl top pods -n omniscope
kubectl top nodes
```

---

## 4. Service Mesh validation checklist

Apply this section if mesh is enabled (Istio/Linkerd/Consul).

## 4.1 Control plane health

- [ ] Mesh control plane pods are `Running`
- [ ] No critical errors in control plane logs

Examples:

```bash
kubectl get pods -n istio-system
kubectl logs -n istio-system deploy/istiod --tail=200
```

## 4.2 Sidecar and policy enforcement

- [ ] Sidecar injected for target workloads
- [ ] Namespace/workload policy labels applied

Examples:

```bash
kubectl -n omniscope get pod <pod-name> -o jsonpath='{.spec.containers[*].name}'
kubectl get ns omniscope --show-labels
```

## 4.3 mTLS checks

- [ ] Mode verified (`permissive` or `strict`)
- [ ] Successful encrypted service-to-service traffic
- [ ] Unencrypted traffic denied in `strict`

## 4.4 Traffic policy behavior

- [ ] Retries behave as configured
- [ ] Timeouts protect callers from hanging upstream
- [ ] Circuit breaking prevents cascading failures
- [ ] Fault-injection confirms resilience paths

## 4.5 Mesh telemetry and resilience

- [ ] Service-to-service latency visible
- [ ] 5xx and TCP resets visible by source/destination
- [ ] Policy denials observable and explainable
- [ ] Degrade path verified (`service-b` down -> `service-a` behavior documented)

---

## 5. Connectivity validation (mesh or no mesh)

- [ ] DNS resolution inside cluster
- [ ] Service and endpoints match expected pods
- [ ] Readiness/liveness healthy for serving pods
- [ ] NetworkPolicy allows only intended traffic
- [ ] Egress to external dependencies is controlled and observable
- [ ] Timeout/retry budgets prevent retry storms

Commands:

```bash
kubectl -n omniscope get svc,endpoints
kubectl -n omniscope get networkpolicy
kubectl -n omniscope run dns-debug --rm -i --restart=Never --image=busybox:1.36 -- nslookup service-b
kubectl -n omniscope describe pod <pod-name>
```

---

## 6. Report template (post-test)

Use this structure for every load/mesh validation run.

```text
Title: OmniScope Load Test + Mesh Validation Report
Date/Time:
Environment:
Version/Images:
Test Type: baseline|stress|spike|endurance|soak
Duration:
Target RPS / profile:

1) Success Criteria
- p95 latency target:
- error rate target:
- saturation boundaries:

2) Results Summary
- Throughput achieved:
- p50/p95/p99 latency:
- error rate:
- saturation indicators:

3) Observability Findings
- Metrics findings:
- Tracing findings:
- Log correlation findings:
- Alert behavior:

4) Service Mesh / Connectivity Findings
- Control plane status:
- mTLS status:
- traffic policy behavior:
- degradation behavior:
- DNS/service/networkpolicy checks:

5) Bottlenecks
- Primary bottleneck:
- Evidence (graph/query/log):
- Impacted components:

6) Actions
- Immediate fixes:
- Follow-up tasks:
- Owner and ETA:
```

## 7. Exit criteria

Validation can be marked complete when:
- all mandatory checklist items are done,
- success criteria are measured and documented,
- bottlenecks have owner + action plan,
- report is attached to release/change record.
