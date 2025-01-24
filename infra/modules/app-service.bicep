@description('Primary location for all resources')
param location string = resourceGroup().location

@description('Tags to apply to all resources')
param tags object = {}

@description('The name of the App Service')
param appServiceName string = ''

@description('The name of the App Service Plan')
param appServicePlanName string = ''

@description('The SKU to use for the App Service Plan')
param skuName string = 'B1'

@description('The name of the deployment service name, see azure.yaml')
param serviceName string

@description('The list of app settings to apply')
param appSettings object = {}

var resourceToken = uniqueString(resourceGroup().name, resourceGroup().location, subscription().subscriptionId)

module appServicePlan 'br/public:avm/res/web/serverfarm:0.3.0' = {
  name: 'app-service-plan-${resourceToken}'
  params: {
    name: empty(appServicePlanName) ? 'asp-${resourceToken}' : appServicePlanName
    location: location
    tags: tags
    skuName: skuName
  }
}

module webApp 'br/public:avm/res/web/site:0.12.0' = {
  name: 'webapp-${resourceToken}'
  params: {
    name: empty(appServiceName) ? 'web-${resourceToken}' : appServiceName
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    kind: 'app'
    serverFarmResourceId: appServicePlan.outputs.resourceId
    managedIdentities: {
      systemAssigned: true
    }

    appSettingsKeyValuePairs: appSettings

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

output SERVICE_WEB_NAME string = webApp.outputs.name
output SERVICE_WEB_URI string = 'https://${webApp.outputs.defaultHostname}'
