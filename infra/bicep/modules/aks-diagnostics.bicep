targetScope = 'resourceGroup'

@description('AKS cluster name to configure diagnostics for.')
param aksName string

@description('Log Analytics Workspace resource ID.')
param lawId string

@description('If false, skip AKS control-plane diagnostics.')
param deployDiagnostics bool = true

resource aks 'Microsoft.ContainerService/managedClusters@2025-02-01' existing = if (deployDiagnostics) {
  name: aksName
}

resource aksDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (deployDiagnostics) {
  name: 'send-to-law'
  scope: aks
  properties: {
    workspaceId: lawId
    logs: [
      {
        category: 'kube-apiserver'
        enabled: true
      }
      {
        category: 'kube-audit'
        enabled: true
      }
      {
        category: 'kube-audit-admin'
        enabled: true
      }
      {
        category: 'kube-controller-manager'
        enabled: true
      }
      {
        category: 'kube-scheduler'
        enabled: true
      }
      {
        category: 'cluster-autoscaler'
        enabled: true
      }
      {
        category: 'guard'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

