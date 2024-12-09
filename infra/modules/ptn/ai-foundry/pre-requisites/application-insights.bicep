metadata name = 'Azure AI Foundry Pre-requisite: Application Insights'

/*
** Pre-requisite resources: Application Insights
**
** If a resource ID is provided, this module will use that resource.
** If not, it will create a new resource will be created.
** The outputs are identical to the AVM equivalent module.
*/

@description('If creating a resource, the name of the resource to create.')
param name string

@description('If creating a resource, the location for the resource')
param location string

@description('If creating a resource, the tags the associate with the resource')
param tags object

@description('If specified, use this resource rather than creating one')
param resourceId string = ''

@description('If creating a resource, the resource ID for the Log Analytics workspace to use')
param logAnalyticsWorkspaceId string

var splitId = split(resourceId, '/')

module createdResource 'br/public:avm/res/insights/component:0.4.2' = if (empty(resourceId)) {
  name: 'prereq-${name}'
  params: {
    name: name
    location: location
    tags: tags
    workspaceResourceId: logAnalyticsWorkspaceId
  }
}

resource existingResource 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(resourceId)) {
  name: splitId[8]
  scope: resourceGroup(splitId[2], splitId[4])
}

output location string = empty(resourceId) ? createdResource.outputs.location : existingResource.location
output name string = empty(resourceId) ? createdResource.outputs.name : existingResource.name
output resourceGroupName string = empty(resourceId) ? createdResource.outputs.resourceGroupName : splitId[4]
output resourceId string = empty(resourceId) ? createdResource.outputs.resourceId : resourceId

output applicationId string = empty(resourceId) ? createdResource.outputs.applicationId : existingResource.properties.AppId
output connectionSring string = empty(resourceId) ? createdResource.outputs.connectionString : existingResource.properties.ConnectionString
output instrumentationKey string = empty(resourceId) ? createdResource.outputs.instrumentationKey : existingResource.properties.InstrumentationKey
