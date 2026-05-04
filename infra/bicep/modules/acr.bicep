@description('Target resource group scope.')
param location string

@description('Azure Container Registry name: 5–50 alphanumeric characters, globally unique.')
param acrName string

@description('Optional tags.')
param tags object = {}

// SKU Basic is enough for test images; use Standard/Premium for geo-replication, retention policies, etc.
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

output acrId string = acr.id
output acrName string = acr.name
output loginServer string = acr.properties.loginServer
