targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
@allowed([
  'australiaeast'
  'brazilsouth'
  'canadacentral'
  'canadaeast'
  'eastus'
  'eastus2'
  'francecentral'
  'germanywestcentral'
  'japaneast'
  'koreacentral'
  'northcentralus'
  'norwayeast'
  'polandcentral'
  'southafricanorth'
  'southcentralus'
  'southindia'
  'swedencentral'
  'switzerlandnorth'
  'uaenorth'
  'uksouth'
  'westeurope'
  'westus'
  'westus3'
])
param location string

@description('The connection string of the AI Foundry Project')
param aiFoundryConnectionString string

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
** Now that we have a model deployed, we can deploy a web service that can use the model
** The project is the central place that is provided for all AI Foundry deployments and
** the connection string for the AI Foundry Project is injected into the web service.
*/
module appServicePlan 'br/public:avm/res/web/serverfarm:0.3.0' = {
  name: 'app-service-plan-${resourceToken}'
  scope: rg
  params: {
    name: 'asp-${resourceToken}'
    location: location
    tags: tags
    skuName: 'B1'
  }
}

module webApp 'br/public:avm/res/web/site:0.12.0' = {
  name: 'webapp-${resourceToken}'
  scope: rg
  params: {
    name: 'web-${resourceToken}'
    location: location
    tags: union(tags, { 'azd-service-name': 'webapp' })
    kind: 'app'
    serverFarmResourceId: appServicePlan.outputs.resourceId
    managedIdentities: {
      systemAssigned: true
    }

    appSettingsKeyValuePairs: {
      'ConnectionStrings:AzureAIFoundry': aiFoundryConnectionString
      'AzureAIFoundry:ModelName': 'gpt-4o'
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
/*
** We now need to output the requirements of our application so that we can access it
** afterwards.
*/
output SERVICE_WEB_NAME string = webApp.outputs.name
output SERVICE_WEB_URI string = 'https://${webApp.outputs.defaultHostname}'
