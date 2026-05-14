# Deployment Runbook

The full runbook lives in `docs/DEPLOYMENT_RUNBOOK.md`. This is a short version.

## 1) Infra deploy

```bash
cd infra/bicep
jq '.parameters.alertEmail.value = "you@example.com"' parameters.test-aks.json > /tmp/omniscope-test-params.json
export PARAMS_FILE=/tmp/omniscope-test-params.json
export DEPLOYMENT_NAME="omniscope-fulltest-$(date +%Y%m%d%H%M)"
./deploy.sh deploy
```

## 2) Connect kubectl

```bash
az aks get-credentials --resource-group omniscope-aks-test-rg --name omniscope-aks-test-aks --overwrite-existing
kubectl get nodes
```

## 3) Build/push images

```bash
cd examples
ACR_LOGIN_SERVER="<acrLoginServer>"
az acr login --name "${ACR_LOGIN_SERVER%%.azurecr.io}"
docker build -t "${ACR_LOGIN_SERVER}/omniscope/service-a:latest" services/service-a
docker push "${ACR_LOGIN_SERVER}/omniscope/service-a:latest"
docker build -t "${ACR_LOGIN_SERVER}/omniscope/service-b:latest" services/service-b
docker push "${ACR_LOGIN_SERVER}/omniscope/service-b:latest"
```

## 4) Apply manifests

```bash
kubectl apply -f examples/kubernetes/namespace.yaml
kubectl apply -f examples/kubernetes/otel/
sed "s|__ACR_LOGIN_SERVER__|${ACR_LOGIN_SERVER}|g" examples/kubernetes/apps/service-a.yaml | kubectl apply -f -
sed "s|__ACR_LOGIN_SERVER__|${ACR_LOGIN_SERVER}|g" examples/kubernetes/apps/service-b.yaml | kubectl apply -f -
```

## 5) Smoke test

```bash
kubectl -n omniscope run smoke-curl --rm -i --restart=Never --image=curlimages/curl --command -- sh -c \
  "curl -s http://service-a:8081/hello-a && echo && curl -s http://service-a:8081/call-b && echo"
```
