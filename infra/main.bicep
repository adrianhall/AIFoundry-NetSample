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

/*
** Resource Group
**
** All the resources we create are contained in the resource group - you can delete
** the resource group to delete all resources (except for any Azure AD creations).
*/
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

/*
** User-assigned Managed Identity
**
** All resources within this environment will use this managed identity where possible
** for talking to other services within the environment.  It ensures we have a consistent
** identity for doing RBAC across the environment.
*/
module userAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: 'managed-identity-${resourceToken}'
  scope: rg
  params: {
    name: 'mi-app-${resourceToken}'
    location: location
    tags: tags
  }
}

/*
** Azure Monitor is used for logging and reporting across the environment.  It consists of a pair of
** services - a Log Analytics workspace for capturing logs and an Application Insights instance for
** monitoring.
*/
module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.9.0' = {
  name: 'log-analytics-${resourceToken}'
  scope: rg
  params: {
    name: 'law-${resourceToken}'
    location: location
    tags: tags
    skuName: 'PerGB2018'
  }
}

module appInsights 'br/public:avm/res/insights/component:0.4.2' = {
  name: 'app-insights-${resourceToken}'
  scope: rg
  params: {
    name: 'ai-${resourceToken}'
    location: location
    tags: tags
    applicationType: 'web'
    disableIpMasking: true
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    workspaceResourceId: logAnalytics.outputs.resourceId
  }
}

/*
** Deploy an Azure AI Foundry Project
*/
module aiFoundryProject 'modules/ptn/ai-foundry/main.bicep' = {
  name: 'ai-foundry-${resourceToken}'
  scope: rg
  params: {
    // The name of the AI Foundry Project to create.  If not specified, the name will be
    // created from the nameSuffix.
    name: 'aiproject-${environmentName}'

    // Suffix all names that are not specified with the resource token
    nameSuffix: resourceToken

    // The location & tags for all resources
    location: location
    tags: tags

    // A principal ID to assign as an owner to resources.
    principalId: principalId

    // The managed identity to use for all resources.  If one is not provided, a user-assigned
    // managed identity will be created and assigned appropriate roles.
    managedIdentityResourceId: userAssignedIdentity.outputs.resourceId

    // If specified, the resource ID for the Azure AI Foundry Hub that this project will be
    // attached to.  If not specified, a new Azure AI Foundry Hub will be created.
    // aiFoundryHubResourceId: aiFoundryHub.outputs.resourceId

    // Pre-requisites - each one of these resources can be provided using a resourceId OR it will 
    //  be automatically created for you with the default settings necessary for AI Foundry.

    // keyVaultResourceId: keyVault.outputs.resourceId
    logAnalyticsWorkspaceResourceId: logAnalytics.outputs.resourceId
    applicationInsightsResourceId: appInsights.outputs.resourceId
    // storageAccountResourceId: storageAccount.outputs.resourceId

    // Model Deployments
    modelDeployments: [ 
      {
        name: 'gpt-4o-mini'
        model: {
          name: 'gpt-4o-mini'
          deploymentType: 'GlobalStandard'
        }
      }
    ]
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
    tags: tags

    applicationInsightsResourceId: appInsights.outputs.resourceId
    managedIdentityPrincipalId: userAssignedIdentity.outputs.principalId
    appServicePlanSku: 'B1'

    // For linking the AI Foundry project to the web service
    aiFoundryProjectName: aiFoundryProject.outputs.aiFoundryProjectName
    aiModelName: 'gpt-4o-mini'
  }
}

/*
** We now need to output the requirements of our application so that we can access it
** afterwards.
*/
output SERVICE_WEB_NAME string = webService.outputs.webAppName
output SERVICE_WEB_URI string = webService.outputs.webAppUri
