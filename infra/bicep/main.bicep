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

@description('If true, deploy AKS cluster with a sample CPU stress workload in namespace loadtest.')
param deployAks bool = true

@description('AKS node pool VM size for the system pool.')
param aksSystemVmSize string = 'Standard_D4s_v5'

@description('AKS system pool node count (test default).')
param aksSystemNodeCount int = 2

@description('CPU workers for polinux/stress in loadtest deployment.')
param stressCpuWorkers int = 4

@description('Force rerun of the AKS post-install kubectl deployment (any new string triggers update).')
param loadTestDeployTag string = utcNow()

var rgName = '${prefix}-rg'
var lawName = '${prefix}-law'
var appInsightsName = '${prefix}-appi'
var actionGroupName = '${prefix}-ag'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: location
}

resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: lawName
  location: location
  tags: tags
  resourceGroupName: rgName
  dependsOn: [
    rg
  ]
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: logAnalyticsRetentionDays
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  tags: tags
  resourceGroupName: rgName
  dependsOn: [
    law
  ]
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    Request_Source: 'rest'
    IngestionMode: 'LogAnalytics'
    WorkspaceResourceId: law.id
    RetentionInDays: appInsightsRetentionDays
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2024-10-01-preview' = {
  name: actionGroupName
  location: 'global'
  resourceGroupName: rgName
  properties: {
    enabled: true
    groupShortName: actionGroupShortName
    emailReceivers: [
      {
        name: 'oncall-email'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
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
    logAnalyticsWorkspaceId: law.id
    systemVmSize: aksSystemVmSize
    systemNodeCount: aksSystemNodeCount
    loadTestDeployTag: loadTestDeployTag
  }
  dependsOn: [
    law
  ]
}

output resourceGroupName string = rg.name
output logAnalyticsWorkspaceId string = law.id
output applicationInsightsId string = appInsights.id
output actionGroupId string = actionGroup.id
output aksName string = aks.outputs.aksName
output aksFqdn string = aks.outputs.aksFqdn

