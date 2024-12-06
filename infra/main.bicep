targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Additional ID of the user or app to assign application roles')
param principalId string = ''

@description('A short string to uniquely identify all resources in this environment')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

@description('A set of tags to apply to all resources in this environment')
var tags = { 'azd-env-name': environmentName }

// We organize resources into resource groups.  This project places all required resources into the same resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

/*
** Start off with some common services that are used by all other services
**
**  - Azure Key Vault is used to store any secrets used by the environment.
**  - Azure Log Analytics is used to store logs and metrics.
**  - Azure Application Insights is used to monitor the environment.
**  - User-assigned Managed Identity is used for RBAC across the environment.
*/
module commonServices './modules/common-services.bicep' = {
  name: 'common-services-${resourceToken}'
  scope: rg
  params: {
    resourceToken: resourceToken
    location: location
    principalId: principalId
    tags: tags
  }
}

/*
** Next, deploy the Azure AI Foundry base resources
*/
module aiFoundry './modules/ai-foundry.bicep' = {
  name: 'ai-foundry-${resourceToken}'
  scope: rg
  params: {
    environmentName: environmentName
    resourceToken: resourceToken
    location: location
    principalId: principalId
    tags: tags

    applicationInsightsResourceId: commonServices.outputs.appInsightsResourceId
    keyVaultResourceId: commonServices.outputs.keyVaultResourceId
    managedIdentityPrincipalId: commonServices.outputs.managedIdentityPrincipalId
    storageAccountSku: 'Standard_LRS'
  }
}

/*
** Deploy the gpt-4o-mini model into the Azure AI Foundry project that we created.
TODO: Add the model deployment here
*/
module openAIModel './modules/openai-model.bicep' = {
  name: 'openai-model-${resourceToken}'
  scope: rg
  params: {
    resourceToken: resourceToken
    location: location
    principalId: principalId
    tags: tags

    aiFoundryProjectName: aiFoundry.outputs.aiFoundryProjectName
    modelName: 'gpt-4o-mini'
    deploymentType: 'Global Standard'
  }
}

/*
** Now that we have a model deployed, we can deploy a web service that can use the model
** The project is the central place that is provided for all AI Foundry deployments and
** the connection string for the AI Foundry Project is injected into the web service.
*/
module webService './modules/web-service.bicep' = {
  name: 'web-service-${resourceToken}'
  scope: rg
  params: {
    resourceToken: resourceToken
    location: location
    principalId: principalId
    tags: tags

    applicationInsightsResourceId: commonServices.outputs.appInsightsResourceId
    keyVaultUri: commonServices.outputs.keyVaultUri
    managedIdentityPrincipalId: commonServices.outputs.managedIdentityPrincipalId
    appServicePlanSku: 'B1'

    // For linking the AI Foundry project to the web service
    aiFoundryProjectName: aiFoundry.outputs.aiFoundryProjectName
    aiModelName: openAIModel.outputs.modelName
  }
}

/*
** We now need to output the requirements of our application so that we can access it
** afterwards.
*/
output SERVICE_WEB_NAME string = webService.outputs.webAppName
output SERVICE_WEB_URI string = webService.outputs.webAppUri
