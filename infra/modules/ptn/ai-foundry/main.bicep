metadata name = 'Azure AI Foundry Project Deployment'

@description('Optional.  The name suffix for all resources that are not explicitly named')
param nameSuffix string = uniqueString(subscription().subscriptionId, resourceGroup().name, resourceGroup().location)

@description('Optional. The name of the Azure AI Project that will be created')
param name string = 'ai-project-${nameSuffix}'

@description('Optional.  The location for the created resources.  Defaults to the location of the resource group.')
param location string = resourceGroup().location

@description('Optional.  The list of tags to apply to the created resources.')
param tags object = {}

@description('Optional.  The principal ID to assign as an owner.')
param principalId string = ''

@description('Optional.  The resource ID for the managed identity to use for the AI Foundry resources.  If not provided, a user-assigned identity will be created')
param managedIdentityResourceId string = ''

// @description('Optional.  The resource ID for the Azure AI Foundry Hub to use. If not provided, a new hub will be created')
param aiFoundryHubResourceId string = ''

@description('Optional.  The resource ID for the Azure Key Vault to use.  If one is not provided, a new one will be created.')
param keyVaultResourceId string = ''

@description('Optional.  The resource ID for the Log Analytics Workspace to use. If one is not provided, a new one will be created.')
param logAnalyticsWorkspaceResourceId string = ''

@description('Optional.  The resource ID for the Application Insights to use.  If one is not provided, a new one will be created.')
param applicationInsightsResourceId string = ''

@description('Optional.  The resource ID for the Azure Storage Account to use.  If one is not provided, a new one will be created.')
param storageAccountResourceId string = ''

@description('Optional.  The list of model deployments to create.')
param modelDeployments DeploymentModel[] = []

/*
** Pre-requisite resources
*/
module managedIdentity './pre-requisites/user-assigned-managed-identity.bicep' = {
  name: 'ptn-aifoundry-mi-${nameSuffix}'
  params: {
    name: 'aimi-${nameSuffix}'
    location: location
    tags: tags
    resourceId: managedIdentityResourceId
  }
}

module logAnalytics './pre-requisites/log-analytics-workspace.bicep' = {
  name: 'ptn-aifoundry-law-${nameSuffix}'
  params: {
    name: 'ailog-${nameSuffix}'
    location: location
    tags: tags
    resourceId: logAnalyticsWorkspaceResourceId
  }
}

module appInsights './pre-requisites/application-insights.bicep' = {
  name: 'ptn-aifoundry-appi-${nameSuffix}'
  params: {
    name: 'aiappi-${nameSuffix}'
    location: location
    tags: tags
    resourceId: applicationInsightsResourceId
    logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
}

module keyVault './pre-requisites/key-vault.bicep' = {
  name: 'ptn-aifoundry-kv-${nameSuffix}'
  params: {
    name: 'aikv-${nameSuffix}'
    location: location
    tags: tags
    resourceId: keyVaultResourceId
    roleAssignments: concat([
      { principalId: managedIdentity.outputs.principalId, principalType: 'ServicePrincipal', roleDefinitionIdOrName: 'Key Vault Secrets User' }
    ], principalId != '' ? [
      { principalId: principalId, principalType: 'User', roleDefinitionIdOrName: 'Owner' }
      { principalId: principalId, principalType: 'User', roleDefinitionIdOrName: 'Key Vault Secrets Officer' }
    ] : [])
  }
}

module storageAccount './pre-requisites/storage-account.bicep' = {
  name: 'ptn-aifoundry-sa-${nameSuffix}'
  params: {
    name: 'aist${nameSuffix}'
    location: location
    tags: tags
    resourceId: storageAccountResourceId
    roleAssignments: concat([
      { principalId: managedIdentity.outputs.principalId, principalType: 'ServicePrincipal', roleDefinitionIdOrName: 'Reader and Data Access' }
    ], principalId != '' ? [
      { principalId: principalId, principalType: 'User', roleDefinitionIdOrName: 'Reader and Data Access' }
    ] : [])
  }
}

module aiServices './modules/cognitive-services.bicep' = {
  name: 'ptn-aifoundry-svcs-${nameSuffix}'
  params: {
    name: 'aisvc-${nameSuffix}'
    location: location
    tags: tags
    kind: 'AIServices'
    deployments: modelDeployments
  }
}

/*
** Hub and Project resources
*/
module aiFoundryHub './modules/ai-foundry-hub.bicep' = {
  name: 'ptn-aifoundry-hub-${nameSuffix}'
  params: {
    name: 'aihub-${nameSuffix}'
    location: location
    tags: tags
    resourceId: aiFoundryHubResourceId
    
    aiServicesResourceId: aiServices.outputs.resourceId
    applicationInsightsResourceId: appInsights.outputs.resourceId
    keyVaultResourceId: keyVault.outputs.resourceId
    managedIdentityPrincipalId: managedIdentity.outputs.principalId
    storageAccountResourceId: storageAccount.outputs.resourceId
    roleAssignments: concat([
      { principalId: managedIdentity.outputs.principalId, principalType: 'ServicePrincipal', roleDefinitionIdOrName: 'Azure AI Developer' }
      { principalId: managedIdentity.outputs.principalId, principalType: 'ServicePrincipal', roleDefinitionIdOrName: 'Search Service Data Contributor' }
    ], principalId != '' ? [
      { principalId: principalId, principalType: 'User', roleDefinitionIdOrName: 'Azure AI Developer' }
    ] : [])
  }
}

module aiFoundryProject './modules/ai-foundry-project.bicep' = {
  name: 'ptn-aifoundry-prj-${nameSuffix}'
  params: {
    name: name
    location: location
    tags: tags
    hubResourceId: aiFoundryHub.outputs.resourceId
    managedIdentityPrincipalId: managedIdentity.outputs.principalId
    roleAssignments: concat([
      { principalId: managedIdentity.outputs.principalId, principalType: 'ServicePrincipal', roleDefinitionIdOrName: 'Azure AI Developer' }
      { principalId: managedIdentity.outputs.principalId, principalType: 'ServicePrincipal', roleDefinitionIdOrName: 'Search Service Data Contributor' }
    ], principalId != '' ? [
      { principalId: principalId, principalType: 'User', roleDefinitionIdOrName: 'Azure AI Developer' }
    ] : [])
  }
}

/*
** Outputs
*/
output aiFoundryHubLocation string = aiFoundryHub.outputs.location
output aiFoundryHubName string = aiFoundryHub.outputs.name
output aiFoundryHubResourceId string = aiFoundryHub.outputs.resourceId

output aiFoundryProjectLocation string = aiFoundryProject.outputs.location
output aiFoundryProjectName string = aiFoundryProject.outputs.name
output aiFoundryProjectResourceId string = aiFoundryProject.outputs.resourceId

output aiServicesLocation string = aiServices.outputs.location
output aiServicesName string = aiServices.outputs.name
output aiServicesResourceId string = aiServices.outputs.resourceId

output aiFoundryManagedIdentityPrincipalId string = managedIdentity.outputs.principalId
output aiFoundryKeyVaultUri string = keyVault.outputs.uri

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
