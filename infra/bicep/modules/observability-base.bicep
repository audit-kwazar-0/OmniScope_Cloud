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

@description('If true, deploy Azure Monitor workspace + Managed Grafana.')
param deployManagedPrometheus bool = true

@description('Azure Monitor workspace name (Managed Prometheus storage).')
param azureMonitorWorkspaceName string

@description('Managed Grafana instance name.')
param grafanaName string

@description('If true, deploy Event Hub export path for OpenSearch/Elastic ingestion.')
param deployLogExport bool = true

@description('Event Hub namespace name used as export target for logs.')
param eventHubNamespaceName string

@description('Event Hub name for streamed logs.')
param eventHubName string

@description('Optional Teams webhook endpoint for Action Group simulation.')
@secure()
param teamsWebhookUri string = ''

@description('Entra object id (user, group, or SPN) granted Grafana Admin on Managed Grafana (for portal + az grafana API). Leave empty to skip.')
param grafanaAdminObjectId string = ''

@description('Principal type for grafanaAdminObjectId: User, Group, or ServicePrincipal.')
@allowed(['User', 'Group', 'ServicePrincipal'])
param grafanaAdminPrincipalType string = 'User'

// Built-in: Grafana Admin (configure datasources/API access for automation and admins)
var grafanaAdminRoleId = '22926164-76b3-42b3-bc55-97df8dab3e41'

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
    webhookReceivers: !empty(teamsWebhookUri)
      ? [
          {
            name: 'teams-webhook'
            serviceUri: teamsWebhookUri
            useCommonAlertSchema: true
          }
        ]
      : []
  }
}

resource azureMonitorWorkspace 'Microsoft.Monitor/accounts@2023-04-03' = if (deployManagedPrometheus) {
  name: azureMonitorWorkspaceName
  location: location
  tags: tags
  properties: {}
}

resource managedGrafana 'Microsoft.Dashboard/grafana@2023-09-01' = if (deployManagedPrometheus) {
  name: grafanaName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    apiKey: 'Enabled'
    deterministicOutboundIP: 'Disabled'
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Disabled'
    grafanaIntegrations: {
      azureMonitorWorkspaceIntegrations: [
        {
          azureMonitorWorkspaceResourceId: azureMonitorWorkspace.id
        }
      ]
    }
  }
}

resource grafanaAdminAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployManagedPrometheus && !empty(grafanaAdminObjectId)) {
  name: guid(managedGrafana.id, grafanaAdminObjectId, grafanaAdminRoleId)
  scope: managedGrafana
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', grafanaAdminRoleId)
    principalId: grafanaAdminObjectId
    principalType: grafanaAdminPrincipalType
  }
}

resource ehNamespace 'Microsoft.EventHub/namespaces@2022-10-01-preview' = if (deployLogExport) {
  name: eventHubNamespaceName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 1
  }
  tags: tags
  properties: {
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

resource eh 'Microsoft.EventHub/namespaces/eventhubs@2022-10-01-preview' = if (deployLogExport) {
  name: eventHubName
  parent: ehNamespace
  properties: {
    messageRetentionInDays: 1
    partitionCount: 2
  }
}

resource lawExportAllLogs 'Microsoft.OperationalInsights/workspaces/dataExports@2023-09-01' = if (deployLogExport) {
  name: 'to-eventhub-alllogs'
  parent: law
  properties: {
    destination: {
      resourceId: ehNamespace.id
    }
    tableNames: [
      'ContainerLogV2'
      'AzureDiagnostics'
      'KubePodInventory'
      'KubeEvents'
    ]
    enable: true
  }
  dependsOn: [
    eh
  ]
}

resource cpuHighAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: '${actionGroupName}-aks-cpu-high'
  location: location
  tags: tags
  dependsOn: [
    law
    appInsights
  ]
  properties: {
    description: 'AKS node CPU usage > 80% for 5 minutes'
    enabled: true
    severity: 2
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    scopes: [
      law.id
    ]
    criteria: {
      allOf: [
        {
          query: 'let avgCpu = toscalar(InsightsMetrics | where TimeGenerated > ago(5m) | where Namespace == "container.azm.ms/cpu" and Name == "cpuUsageNanoCores" | summarize avg(Val)); print cpuBreach = iif(isnull(avgCpu), 0.0, iif(avgCpu > 80.0, 1.0, 0.0))'
          timeAggregation: 'Maximum'
          metricMeasureColumn: 'cpuBreach'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: true
    actions: {
      actionGroups: [
        actionGroup.id
      ]
    }
  }
}

resource appErrorsAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: '${actionGroupName}-omniscope-errors'
  location: location
  tags: tags
  dependsOn: [
    law
    appInsights
  ]
  properties: {
    description: 'OmniScope error ratio > 5% for last 10 minutes'
    enabled: true
    severity: 2
    evaluationFrequency: 'PT5M'
    windowSize: 'PT10M'
    scopes: [
      law.id
    ]
    criteria: {
      allOf: [
        {
          query: 'let total = toscalar(ContainerLogV2 | where TimeGenerated > ago(10m) | count); let errors = toscalar(ContainerLogV2 | where TimeGenerated > ago(10m) | where LogMessage has "ERROR" or LogMessage matches regex @"\\b5\\d\\d\\b" | count); print errorRate = iif(total == 0, 0.0, todouble(errors) / todouble(total) * 100.0)'
          timeAggregation: 'Maximum'
          metricMeasureColumn: 'errorRate'
          operator: 'GreaterThan'
          threshold: 5
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: true
    actions: {
      actionGroups: [
        actionGroup.id
      ]
    }
  }
}

output lawId string = law.id
output applicationInsightsId string = appInsights.id
output actionGroupId string = actionGroup.id
output azureMonitorWorkspaceId string = deployManagedPrometheus ? azureMonitorWorkspace.id : ''
output grafanaUrl string = deployManagedPrometheus ? managedGrafana.properties.endpoint : ''
output eventHubId string = deployLogExport ? eh.id : ''
