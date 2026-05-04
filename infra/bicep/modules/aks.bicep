@description('Target resource group scope.')
param location string

@description('Naming prefix used across resources.')
param prefix string

@description('If false, skip AKS + post-install resources entirely (Observability-only deployments).')
param deployCluster bool = true

@description('Optional tags applied to resources that support tags.')
param tags object = {}

@description('AKS cluster name (defaults to prefix-based name).')
param aksName string = '${prefix}-aks'

@description('AKS API server DNS prefix.')
param aksDnsPrefix string = '${prefix}-aks'

@description('System node pool VM size.')
param systemVmSize string = 'Standard_D4s_v5'

@description('Initial system node pool count.')
param systemNodeCount int = 2

@description('OS disk size for system pool (GB).')
param systemOsDiskSizeGB int = 100

@description('If true, deploy a CPU stress workload into the cluster (namespace loadtest).')
param deployCpuStress bool = true

@description('CPU workers for polinux/stress (see image docs).')
param stressCpuWorkers int = 4

@description('Force redeploy of the post-install deploymentScript (change to rerun kubectl apply).')
param loadTestDeployTag string = utcNow()

@description('Log Analytics workspace resource ID for Container Insights addon (optional).')
param logAnalyticsWorkspaceId string

var deployerName = '${prefix}-aks-deployer-uai'
var aksContributorRoleDefinitionId = 'ed7f3fbd-7b88-4dd4-9017-9adb7ce333f8'

resource deployerIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = if (deployCluster) {
  name: deployerName
  location: location
  tags: tags
}

resource aks 'Microsoft.ContainerService/managedClusters@2025-02-01' = if (deployCluster) {
  name: aksName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: aksDnsPrefix
    enableRBAC: true
    agentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        count: systemNodeCount
        vmSize: systemVmSize
        osType: 'Linux'
        type: 'VirtualMachineScaleSets'
        osDiskSizeGB: systemOsDiskSizeGB
      }
    ]
    networkProfile: {
      networkPlugin: 'kubenet'
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
    }
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
        }
      }
    }
  }
}

resource aksContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployCluster) {
  name: guid(aks.id, deployerIdentity.id, aksContributorRoleDefinitionId)
  scope: aks
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      aksContributorRoleDefinitionId
    )
    principalId: deployerIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource loadTestDeploy 'Microsoft.Resources/deploymentScripts@2023-08-01' = if (deployCluster && deployCpuStress) {
  name: '${prefix}-aks-loadtest-deploy'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deployerIdentity.id}': {}
    }
  }
  kind: 'AzureCLI'
  dependsOn: [
    aks
    aksContributorAssignment
  ]
  properties: {
    azCliVersion: '2.66.0'
    retentionInterval: 'PT2H'
    cleanupPreference: 'OnSuccess'
    forceUpdateTag: loadTestDeployTag
    environmentVariables: [
      {
        name: 'RG'
        value: resourceGroup().name
      }
      {
        name: 'CLUSTER'
        value: aksName
      }
      {
        name: 'STRESS_CPU'
        value: string(stressCpuWorkers)
      }
    ]
    scriptContent: '''
set -euo pipefail

echo "Logging in with user-assigned managed identity..."
az login --identity

echo "Ensuring kubectl exists..."
if ! command -v kubectl >/dev/null 2>&1; then
  az aks install-cli >/dev/null
fi

echo "Fetching admin kubeconfig (non-interactive)..."
az aks get-credentials \
  --resource-group "$RG" \
  --name "$CLUSTER" \
  --admin \
  --overwrite-existing \
  --only-show-errors

kubectl version --client

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: loadtest
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cpu-stress
  namespace: loadtest
  labels:
    app: cpu-stress
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cpu-stress
  template:
    metadata:
      labels:
        app: cpu-stress
    spec:
      containers:
      - name: stress
        image: polinux/stress
        args:
          - stress
          - --cpu
          - "${STRESS_CPU}"
          - --verbose
          - --timeout
          - "0"
        resources:
          requests:
            cpu: "500m"
            memory: "128Mi"
          limits:
            cpu: "2"
            memory: "512Mi"
EOF

kubectl -n loadtest rollout status deployment/cpu-stress --timeout=10m

echo "Done."
'''
  }
}

output aksName string = deployCluster ? aks.name : ''
output aksId string = deployCluster ? aks.id : ''
output aksFqdn string = deployCluster ? aks.properties.fqdn : ''
output deployerIdentityId string = deployCluster ? deployerIdentity.id : ''
@description('Kubelet managed identity object id — use for AcrPull role assignment on ACR.')
output kubeletObjectId string = deployCluster ? aks.properties.identityProfile.kubeletidentity.objectId : ''
