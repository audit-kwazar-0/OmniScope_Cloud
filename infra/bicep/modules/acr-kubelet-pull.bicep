targetScope = 'resourceGroup'

@description('Existing Azure Container Registry name in this resource group.')
param acrName string

@description('AKS kubelet identity objectId (managed identity used by nodes to pull images).')
param kubeletObjectId string

@description('AKS cluster resource id (used only to stabilize role assignment name).')
param aksId string

var acrPullRoleDefinitionId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

resource acrPullKubelet 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, aksId, acrPullRoleDefinitionId)
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      acrPullRoleDefinitionId
    )
    principalId: kubeletObjectId
    principalType: 'ServicePrincipal'
  }
}
