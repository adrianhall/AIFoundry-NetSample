/*
** Deploys the basic requirements of the AI Foundry that are used by other AI Foundry deployments
**
**  - An Azure AI Foundry Hub is the central place for all AI Foundry deployments
**  - An Azure AI Foundry Project is used to link resources common to this deployment
**  - A storage account for the project
*/

@minLength(1)
@maxLength(64)
@description('Name of the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@description('A short string to uniquely identify all resources deployed by this module')
param resourceToken string

@minLength(1)
@description('Primary location for all resources')
param location string = resourceGroup().location

@description('An optional additional principal ID for the user or app doing the deployment')
param principalId string = ''

@description('A set of tags to apply to all resources in this environment')
param tags object = {}

@description('The Principal ID for the application managed identity')
param managedIdentityPrincipalId string

@description('The SKU for the storage account')
@allowed([ 
  'Standard_LRS'
  'Standard_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_RAGRS'
  'Standard_RAGZRS'
  'Premium_LRS'
  'Premium_ZRS'
])
param storageAccountSku string = 'Standard_LRS'

@description('The resource ID for the Key Vault')
param keyVaultResourceId string

@description('The resource ID for the Application Insights')
param applicationInsightsResourceId string

// Specifies the friendly name for the AI Foundry Hub
var aiHubFriendlyName = 'AI Foundry Hub for ${environmentName}'

/*
** Create the storage account required for the AI Foundry project
*/
module storageAccount 'br/public:avm/res/storage/storage-account:0.14.3' = {
  name: 'storage-account-${resourceToken}'
  params: {
    name: 'sa${resourceToken}'
    location: location
    tags: tags
    skuName: storageAccountSku
    kind: 'StorageV2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    roleAssignments: concat(
      [ 
        { principalId: managedIdentityPrincipalId, principalType: 'ServicePrincipal', roleDefinitionIdOrName: 'Storage Blob Data Owner' } 
      ], 
      principalId == '' ? [] : [
        { principalId: principalId, principalType: 'User', roleDefinitionIdOrName: 'Storage Blob Data Owner' }
        { principalId: principalId, principalType: 'User', roleDefinitionIdOrName: 'Owner' }
      ]
    )
  }
}

/*
** Creates an AI Foundry Hub to manage all AI Foundry projects
** TODO: Convert to a module that allows you to specify an existing HUB to use.  if not provided, create a new one
*/
resource aiFoundryHub 'Microsoft.MachineLearningServices/workspaces@2024-07-01-preview' = {
  name: 'ai-hub-${resourceToken}'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityPrincipalId}': {}
    }
  }
  kind: 'hub'
  properties: {
    friendlyName: aiHubFriendlyName
    description: aiHubFriendlyName
    primaryUserAssignedIdentity: managedIdentityPrincipalId
    storageAccount: storageAccount.outputs.resourceId
    applicationInsights: applicationInsightsResourceId
    keyVault: keyVaultResourceId
  }
}

/*
** Creates an AI Foundry project to manage all the AI Foundry resources
*/
resource aiFoundryProject 'Microsoft.MachineLearningServices/workspaces@2024-07-01-preview' = {
  name: 'ai-project-${resourceToken}'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityPrincipalId}': {}
    }
  }
  kind: 'project'
  properties: {
    friendlyName: 'AI Foundry Project for ${environmentName}'
    description: 'AI Foundry Project for ${environmentName}'
    primaryUserAssignedIdentity: managedIdentityPrincipalId
    storageAccount: storageAccount.outputs.resourceId
    applicationInsights: applicationInsightsResourceId
    keyVault: keyVaultResourceId
    hubResourceId: aiFoundryHub.id
  }
}

/*
** Creates a Cognitive Services account for the AI Foundry project
** This will host the models that you deploy.
*/
resource aiServicesAccounts 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: 'ai-services-${resourceToken}'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityPrincipalId}': {}
    }
  }
  kind: 'AIServices'
  sku: { name: 'S0' }
}

/*
** Creates a connection between the AI Services and the AI Project
*/
resource aiServicesConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-07-01-preview' = {
  name: 'ai-services-connection-${resourceToken}'
  parent: aiFoundryProject
  properties: {
    authType: 'ApiKey'
    category: 'AIServices'
    target: aiServicesAccounts.properties.endpoint
    useWorkspaceManagedIdentity: true
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      ResourceId: aiServicesAccounts.id
      Location: aiServicesAccounts.location
    }
  }
}

/*
** Outputs so that other modules can reference the resources created by this module
*/
output aiFoundryStorageAccountResourceId string = storageAccount.outputs.resourceId

output aiFoundryHubResourceId string = aiFoundryHub.id
output aiFoundryHubName string = aiFoundryHub.name
output aiFoundryHubLocation string = aiFoundryHub.location
output aiFoundryResourceGroupName string = resourceGroup().name

output aiFoundryProjectResourceId string = aiFoundryProject.id
output aiFoundryProjectName string = aiFoundryProject.name
output aiFoundryProjectLocation string = aiFoundryProject.location
