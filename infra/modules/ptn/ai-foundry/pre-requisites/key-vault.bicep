metadata name = 'Azure AI Foundry Pre-requisite: Key Vault'

/*
** Pre-requisite resources: Key Vault
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

import { roleAssignmentType } from 'br/public:avm/utl/types/avm-common-types:0.2.1'
@description('Optional. Array of role assignments to create.')
param roleAssignments roleAssignmentType[]?

var splitId = split(resourceId, '/')

module createdResource 'br/public:avm/res/key-vault/vault:0.11.0' = if (empty(resourceId)) {
  name: 'prereq-${name}'
  params: {
    name: name
    location: location
    tags: tags

    // Optional settings
    enablePurgeProtection: false
    enableSoftDelete: false
    enableRbacAuthorization: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    roleAssignments: roleAssignments
  }
}

resource existingResource 'Microsoft.KeyVault/vaults@2023-07-01' existing = if (!empty(resourceId)) {
  name: splitId[8]
  scope: resourceGroup(splitId[2], splitId[4])
}

output location string = empty(resourceId) ? createdResource.outputs.location : existingResource.location
output name string = empty(resourceId) ? createdResource.outputs.name : existingResource.name
output resourceGroupName string = empty(resourceId) ? createdResource.outputs.resourceGroupName : splitId[4]
output resourceId string = empty(resourceId) ? createdResource.outputs.resourceId : existingResource.id

output uri string = empty(resourceId) ? createdResource.outputs.uri : existingResource.properties.vaultUri
