metadata name = 'Azure AI Foundry: AI Foundry Hub'

/*
** Creates an AI Foundry Hub to manage all the AI Foundry projects.
*/

@description('If creating a resource, the name of the resource to create.')
param name string

@description('If creating a resource, the location for the resource')
param location string

@description('If creating a resource, the tags the associate with the resource')
param tags object

@description('If specified, use this resource rather than creating one')
param resourceId string = ''

/*
** Pre-requisite resources
*/
@description('Required.  The resource ID for the AI Services resource to connect.')
param aiServicesResourceId string

@description('Optional.  The name of the AI Services connection.')
param aiServicesConnectionName string = 'aoai-${uniqueString(name, resourceGroup().name, subscription().id)}'

@description('Required.  The resource ID for the Application Insights resource to connect.')
param applicationInsightsResourceId string

@description('Required.  The resource ID for the Azure Key Vault to use.')
param keyVaultResourceId string

@description('Required.  The Resource ID for the application managed identity')
param managedIdentityResourceId string

@description('Required.  The resource ID for the storage account')
param storageAccountResourceId string

import { roleAssignmentType } from 'br/public:avm/utl/types/avm-common-types:0.2.1'
@description('Optional. Array of role assignments to create.')
param roleAssignments roleAssignmentType[]?

var builtInRoleNames = {
  Contributor: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
  Owner: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
  Reader: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
  'Role Based Access Control Administrator': subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'f58310d9-a9f6-439a-9e8d-f62e7b41a168')
  'User Access Administrator': subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9')
  'Azure AI Developer': subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '64702f94-c441-49e6-a78b-ef80e0188fee')
  'AzureML Data Scientist': subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'f6c7c914-8db3-469d-8ca1-694a8f32e121')
  'Cognitive Services OpenAI Contributor': subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a001fd3d-188f-4b5d-821b-7da978bf7442')
  'Cognitive Services OpenAI User': subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
  'Search Index Data Contributor': subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8ebe5a00-799e-43f5-93ac-243d3dce84a7')
  'Search Index Data Reader': subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '1407120a-92aa-4202-b7e9-c0e197c71c8f')
}

var roleAssignmentArray = [
  for (roleAssignment, index) in (roleAssignments ?? []): union(roleAssignment, {
    roleDefinitionId: builtInRoleNames[?roleAssignment.roleDefinitionIdOrName] ?? (contains(
        roleAssignment.roleDefinitionIdOrName,
        '/providers/Microsoft.Authorization/roleDefinitions/'
      )
      ? roleAssignment.roleDefinitionIdOrName
      : subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleAssignment.roleDefinitionIdOrName))
  })
]

var formattedRoleAssignments = empty(resourceId) ? roleAssignmentArray : []
var splitId = split(resourceId, '/')
var aiServicesId = split(aiServicesResourceId, '/')

resource aiService 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: aiServicesId[8]
  scope: resourceGroup(aiServicesId[2], aiServicesId[4])
}

// resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
//   name: split(managedIdentityResourceId, '/')[8]
//   scope: resourceGroup(split(managedIdentityResourceId, '/')[2], split(managedIdentityResourceId, '/')[4])
// }

resource createdResource 'Microsoft.MachineLearningServices/workspaces@2024-07-01-preview' = if (empty(resourceId)) {
  name: name
  location: location
  tags: tags
  kind: 'Hub'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityResourceId}': {}
    }
  }
  properties: {
    friendlyName: name
    description: name
    applicationInsights: applicationInsightsResourceId
    keyVault: keyVaultResourceId
    storageAccount: storageAccountResourceId
    primaryUserAssignedIdentity: managedIdentityResourceId
    hbiWorkspace: false
    managedNetwork: { isolationMode: 'Disabled' }
    v1LegacyMode: false
    publicNetworkAccess: 'Enabled'
  }
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }

  resource aiServiceConnection 'connections' = {
    name: aiServicesConnectionName
    properties: {
      category: 'AIServices'
      authType: 'ApiKey'
      isSharedToAll: true
      target: aiService.properties.endpoint
      metadata: {
        ApiVersion: '2023-07-01-preview'
        ApiType: 'Azure'
        ResourceId: aiService.id
      }
      credentials: {
        key: aiService.listKeys().key1
      }
    }
  }
}

// This only gets created if the resourceId is not provided.
resource storageAccount_roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (roleAssignment, index) in (formattedRoleAssignments ?? []): {
    name: roleAssignment.?name ?? guid(createdResource.id, roleAssignment.principalId, roleAssignment.roleDefinitionId)
    properties: {
      roleDefinitionId: roleAssignment.roleDefinitionId
      principalId: roleAssignment.principalId
      description: roleAssignment.?description
      principalType: roleAssignment.?principalType
      condition: roleAssignment.?condition
      conditionVersion: !empty(roleAssignment.?condition) ? (roleAssignment.?conditionVersion ?? '2.0') : null // Must only be set if condtion is set
      delegatedManagedIdentityResourceId: roleAssignment.?delegatedManagedIdentityResourceId
    }
    scope: createdResource
  }
]

resource existingResource 'Microsoft.MachineLearningServices/workspaces@2024-07-01-preview' existing = if (!empty(resourceId)) {
  name: splitId[8]
  scope: resourceGroup(splitId[2], splitId[4])
}

output location string = empty(resourceId) ? createdResource.location : existingResource.location
output name string = empty(resourceId) ? createdResource.name : existingResource.name
output resourceGroupName string = empty(resourceId) ? resourceGroup().name : splitId[4]
output resourceId string = empty(resourceId) ? createdResource.id : existingResource.id
