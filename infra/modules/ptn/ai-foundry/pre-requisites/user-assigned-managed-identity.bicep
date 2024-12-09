metadata name = 'Azure AI Foundry Pre-requisite: User Assigned Managed Identity'

/*
** Pre-requisite resources: User Assigned Managed Identity
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

var splitId = split(resourceId, '/')

module createdResource 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = if (empty(resourceId)) {
  name: 'prereq-${name}'
  params: {
    name: name
    location: location
    tags: tags
  }
}

resource existingResource 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = if (!empty(resourceId)) {
  name: splitId[8]
  scope: resourceGroup(splitId[2], splitId[4])
}

output location string = empty(resourceId) ? createdResource.outputs.location : existingResource.location
output name string = empty(resourceId) ? createdResource.outputs.name : existingResource.name
output resourceGroupName string = empty(resourceId) ? createdResource.outputs.resourceGroupName : splitId[4]
output resourceId string = empty(resourceId) ? createdResource.outputs.resourceId : existingResource.id

output clientId string = empty(resourceId) ? createdResource.outputs.clientId : existingResource.properties.clientId
output principalId string = empty(resourceId) ? createdResource.outputs.principalId : existingResource.properties.principalId
