targetScope = 'subscription'

@description('Naming prefix used across resources.')
param prefix string

@description('Azure region.')
param location string = 'westeurope'

@description('Email receiver for Azure Monitor Action Group.')
param alertEmail string

@description('Log Analytics retention in days.')
param logAnalyticsRetentionDays int = 30

@description('Application Insights retention in days.')
param appInsightsRetentionDays int = 90

@description('Optional tags applied to resources that support tags.')
param tags object = {}

@description('Action Group short name (SMS limitation, max 12 chars).')
param actionGroupShortName string = 'obs-pzu'

@description('If true, deploy Azure Monitor workspace + Managed Grafana for Managed Prometheus.')
param deployManagedPrometheus bool = true

@description('If true, deploy Event Hub log export path for OpenSearch/Elastic ingestion.')
param deployLogExport bool = true

@description('Optional Teams webhook URL for simulated notifications in Action Group.')
@secure()
param teamsWebhookUri string = ''

@description('If true, deploy AKS cluster with a sample CPU stress workload in namespace loadtest.')
param deployAks bool = true

@description('If true (and deployAks), create Azure Container Registry and grant kubelet AcrPull.')
param deployAcr bool = true

@description('If true (and deployAks), enable AKS control-plane diagnostic settings to LAW.')
param deployAksDiagnostics bool = true

@description('ACR name: 5–50 characters, letters and numbers only, globally unique. Leave empty for an auto-generated name.')
param acrNameOverride string = ''

@description('AKS node pool VM size for the system pool.')
param aksSystemVmSize string = 'Standard_D4s_v5'

@description('AKS system pool node count (test default).')
param aksSystemNodeCount int = 2

@description('CPU workers for polinux/stress in loadtest deployment.')
param stressCpuWorkers int = 4

@description('Force rerun of the AKS post-install kubectl deployment (any new string triggers update).')
param loadTestDeployTag string = utcNow()

var rgName = '${prefix}-rg'
var acrRegistryName = !empty(acrNameOverride)
  ? take(replace(toLower(acrNameOverride), '-', ''), 50)
  : take('omni${uniqueString(subscription().id, prefix, rgName)}', 50)
var lawName = '${prefix}-law'
var appInsightsName = '${prefix}-appi'
var actionGroupName = '${prefix}-ag'
var azureMonitorWorkspaceName = '${prefix}-amw'
var grafanaName = take('${prefix}grafana', 23)
var eventHubNamespaceName = take(replace('${prefix}ehns', '-', ''), 50)
var eventHubName = 'streamforge-logs'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: location
}

module observabilityBase 'modules/observability-base.bicep' = {
  name: '${prefix}-observability-base'
  scope: rg
  params: {
    location: location
    tags: tags
    lawName: lawName
    logAnalyticsRetentionDays: logAnalyticsRetentionDays
    appInsightsName: appInsightsName
    appInsightsRetentionDays: appInsightsRetentionDays
    actionGroupName: actionGroupName
    actionGroupShortName: actionGroupShortName
    alertEmail: alertEmail
    deployManagedPrometheus: deployManagedPrometheus
    azureMonitorWorkspaceName: azureMonitorWorkspaceName
    grafanaName: grafanaName
    deployLogExport: deployLogExport
    eventHubNamespaceName: eventHubNamespaceName
    eventHubName: eventHubName
    teamsWebhookUri: teamsWebhookUri
  }
  dependsOn: [
    rg
  ]
}

module acr 'modules/acr.bicep' = if (deployAks && deployAcr) {
  name: '${prefix}-acr-module'
  scope: rg
  params: {
    location: location
    acrName: acrRegistryName
    tags: tags
  }
  dependsOn: [
    rg
  ]
}

module aks 'modules/aks.bicep' = {
  name: '${prefix}-aks-module'
  scope: rg
  params: {
    location: location
    prefix: prefix
    deployCluster: deployAks
    tags: tags
    deployCpuStress: true
    stressCpuWorkers: stressCpuWorkers
    logAnalyticsWorkspaceId: observabilityBase.outputs.lawId
    systemVmSize: aksSystemVmSize
    systemNodeCount: aksSystemNodeCount
    loadTestDeployTag: loadTestDeployTag
  }
  dependsOn: [
    observabilityBase
  ]
}

module acrKubeletPull 'modules/acr-kubelet-pull.bicep' = if (deployAks && deployAcr) {
  name: '${prefix}-acr-kubelet-pull'
  scope: rg
  params: {
    acrName: acrRegistryName
    kubeletObjectId: aks.outputs.kubeletObjectId
    aksId: aks.outputs.aksId
  }
  dependsOn: [
    acr
    aks
  ]
}

module aksDiagnostics 'modules/aks-diagnostics.bicep' = if (deployAks && deployAksDiagnostics) {
  name: '${prefix}-aks-diagnostics'
  scope: rg
  params: {
    aksName: aks.outputs.aksName
    lawId: observabilityBase.outputs.lawId
    deployDiagnostics: true
  }
  dependsOn: [
    aks
    observabilityBase
  ]
}

output resourceGroupName string = rg.name
output logAnalyticsWorkspaceId string = observabilityBase.outputs.lawId
output applicationInsightsId string = observabilityBase.outputs.applicationInsightsId
output actionGroupId string = observabilityBase.outputs.actionGroupId
output azureMonitorWorkspaceId string = observabilityBase.outputs.azureMonitorWorkspaceId
output grafanaUrl string = observabilityBase.outputs.grafanaUrl
output eventHubId string = observabilityBase.outputs.eventHubId
output aksName string = aks.outputs.aksName
output aksFqdn string = aks.outputs.aksFqdn
output vnetId string = aks.outputs.vnetId
output privateEndpointsSubnetId string = aks.outputs.privateEndpointsSubnetId
output acrName string = (deployAks && deployAcr) ? acr.outputs.acrName : ''
output acrLoginServer string = (deployAks && deployAcr) ? acr.outputs.loginServer : ''

