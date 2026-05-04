targetScope = 'resourceGroup'

@description('Azure region.')
param location string

@description('Optional tags.')
param tags object = {}

@description('Log Analytics workspace name.')
param lawName string

@description('Log Analytics retention in days.')
param logAnalyticsRetentionDays int

@description('Application Insights component name.')
param appInsightsName string

@description('Application Insights retention in days.')
param appInsightsRetentionDays int

@description('Action Group name.')
param actionGroupName string

@description('Action Group short name (max 12 chars).')
param actionGroupShortName string

@description('Email receiver for Action Group.')
param alertEmail string

resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: lawName
  location: location
  tags: tags
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
}

output lawId string = law.id
output applicationInsightsId string = appInsights.id
output actionGroupId string = actionGroup.id
