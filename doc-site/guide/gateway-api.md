# Gateway API

Gateway API is optional in this repository.

Manifests:

- `examples/kubernetes/gateway/10-gateway.yaml`
- `examples/kubernetes/gateway/20-httproute.yaml`

## Usage

1. Set `gatewayClassName` in `10-gateway.yaml`
2. Apply:

```bash
kubectl apply -f examples/kubernetes/gateway/
kubectl -n omniscope get gateway,httproute
```

Routes exposed by `HTTPRoute`:

- `/hello-a` -> `service-a`
- `/call-b` -> `service-a`
- `/hello-b` -> `service-b`
