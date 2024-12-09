/*
** Deploys a web service with an associated app service plan and links
** it to the appropriate services.
*/

@description('A short string to uniquely identify all resources deployed by this module')
param resourceToken string

@minLength(1)
@description('Primary location for all resources')
param location string = resourceGroup().location

@description('A set of tags to apply to all resources in this environment')
param tags object = {}

@description('The resource ID of the application insights resource')
param applicationInsightsResourceId string

@description('The principal ID of the user-assigned managed identity to use')
param managedIdentityPrincipalId string

@description('The name for the AI Foundry project to use')
param aiFoundryProjectName string

@description('The SKU for the app service plan')
param appServicePlanSku string = 'B1'

@description('The name of the AI Model that was deployed')
param aiModelName string

/*
** Gets the existing AI Foundry project so we can grab the connection string later on
*/
resource aiFoundryProject 'Microsoft.MachineLearningServices/workspaces@2024-07-01-preview' existing = {
  name: aiFoundryProjectName
}

/*
** Creates an App Service Plan
*/
module appServicePlan 'br/public:avm/res/web/serverfarm:0.3.0' = {
  name: 'app-service-plan-${resourceToken}'
  params: {
    name: 'asp-${resourceToken}'
    location: location
    tags: tags
    skuName: appServicePlanSku
  }
}

/*
** Creates the Web App - note that we adjust the tags here to ensure that the
** azd command line tool can deploy our sample code to this web site.  The
** tag must match what is in azure.yaml for deployment.
*/
module webApp 'br/public:avm/res/web/site:0.12.0' = {
  name: 'webapp-${resourceToken}'
  params: {
    name: 'web-${resourceToken}'
    location: location
    tags: union(tags, { 'azd-service-name': 'webapp' })
    kind: 'app'
    serverFarmResourceId: appServicePlan.outputs.resourceId
    appInsightResourceId: applicationInsightsResourceId
    managedIdentities: {
      userAssignedResourceIds: [ managedIdentityPrincipalId]
    }

    appSettingsKeyValuePairs: {
      ConnectionStrings__AzureAIFoundry: '${aiFoundryProject.properties.discoveryUrl};${subscription().id};${resourceGroup().name};${aiFoundryProject.name}'
      AzureAI__ModelName: aiModelName
    }

    // Set up logging so that all logs are stored for log streaming
    logsConfiguration: {
      applicationLogs: {
        fileSystem: {
          level: 'Verbose'
          retentionInDays: 3
        }
      }
      detailedErrorMessages: {
        enabled: true
      }
      failedRequestsTracing: {
        enabled: true
      }
      httpLogs: {
        fileSystem: {
          retentionInDays: 3
          enabled: true
          retentionInMb: 35
        }
      }
    }
  }
}

output webAppName string = webApp.outputs.name
output webAppUri string = 'https://${webApp.outputs.defaultHostname}'
