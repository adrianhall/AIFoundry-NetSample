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
** Azure AI Foundry Module, deploying the specific model we expect
*/
module aiFoundry './modules/ai-foundry.bicep' = {
  name: 'aifoundry-deploy-${resourceToken}'
  scope: rg
  params: {
    location: location
    tags: tags
    openAiDeployments: [
      {
        model: { name: 'gpt-4o', version: '2024-05-13' }
        sku: { name: 'Standard', capacity: 8 }
      }
    ]
  }
}

/*
** App Service with a unique plan
*/
module appService './modules/app-service.bicep' = {
  name: 'appsvc-deploy-${resourceToken}'
  scope: rg
  params: {
    location: location
    tags: tags
    serviceName: 'webapp'

    appSettings: {
      'ConnectionStrings:AzureAIFoundry': aiFoundry.outputs.PROJECT_CONNECTION_STRING
      'AzureAIFoundry:ModelName': 'gpt-4o'
    }
  }
}

/*
** We now need to output the requirements of our application so that we can access it
** afterwards.
*/
output AIFOUNDRY_CONNECTION_STRING string = aiFoundry.outputs.PROJECT_CONNECTION_STRING
output OPENAI_SERVICE_ENDPOINT string = aiFoundry.outputs.OPENAI_SERVICE_ENDPOINT
output AZUREAI_SERVICE_ENDPOINT string = aiFoundry.outputs.AZUREAI_SERVICE_ENDPOINT
output SERVICE_WEB_NAME string = appService.outputs.SERVICE_WEB_NAME
output SERVICE_WEB_URI string = appService.outputs.SERVICE_WEB_URI
