metadata name = 'Azure AI Foundry: Azure Cognitive Services instance'

/*
** Creates an AI Foundry Cognitive Services Account for Azure AI Foundry.
*/

@description('If creating a resource, the name of the resource to create.')
param name string

@description('If creating a resource, the location for the resource')
param location string

@description('If creating a resource, the tags the associate with the resource')
param tags object

@description('The custom subdomain used to access the API.  Defaults to the name parameter.')
param customSubDomainName string = name

@description('If true, disabled local authentication')
param disableLocalAuth bool = false

@description('The type of the cognitive services account')
param kind string = 'AIServices'

@description('The list of models to deploy')
param deployments DeploymentModel[]

@allowed([ 'Enabled', 'Disabled' ])
param publicNetworkAccess string = 'Enabled'

@description('Name of the SKU to use.')
param skuName string = 'S0'

@description('The list of allowed IP address rules')
param allowedIPRules array = []

@description('Alternatively, specify the actual network ACLs to use.')
param networkAcls object = empty(allowedIPRules) ? { defaultAction: 'Allow' } : { ipRules: allowedIPRules, defaultAction: 'Deny' }

resource account 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  properties: {
    customSubDomainName: customSubDomainName
    disableLocalAuth: disableLocalAuth
    publicNetworkAccess: publicNetworkAccess
    networkAcls: networkAcls
  }
  sku: {
    name: skuName
  }
}

@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = [for deployment in deployments: {
  parent: account
  name: deployment.name
  properties: {
    model: deployment.model
    raiPolicyName: deployment.?raiPolicyName
  }
  sku: deployment.?sku ?? { name: 'Standard', capacity: 20 }
}]

output location string = account.location
output name string = account.name
output resourceGroupName string = resourceGroup().name
output resourceId string = account.id

output endpoint string = account.properties.endpoint
output endpoints object = account.properties.endpoints

/*
** Types
*/
type DeploymentModel = {
  @description('The name of the deployment.')
  name: string

  @description('The official name of the model.')
  model: object

  @description('Optional. The RAI policy name.')
  raiPolicyName: string?

  @description('Optionaal. The SKU for the model')
  sku: object?
}
