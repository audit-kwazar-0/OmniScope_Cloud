# Evidence / DoD

Primary checklist: `docs/EVIDENCE.md`.

## Minimum proof set

1. IaC deploy succeeded (`az deployment sub show`)
2. AKS node Ready + app pods Running
3. e2e request path works (`/hello-a`, `/call-b`)
4. Trace in Application Insights
5. Metrics visible in Grafana
6. Logs queryable in LAW
7. Alert rules and action group present

## Useful commands

```bash
kubectl get nodes
kubectl -n omniscope get pods
az monitor scheduled-query list --resource-group "$RG" -o table
az monitor action-group list --resource-group "$RG" -o table
```
