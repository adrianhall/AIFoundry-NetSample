/*
** Deploys some common services that are used by all other services
**
**  - Azure Key Vault is used to store any secrets used by the environment.
**  - Azure Log Analytics is used to store logs and metrics.
**  - Azure Application Insights is used to monitor the environment.
**  - User-assigned Managed Identity is used for RBAC across the environment.
*/

@description('A short string to uniquely identify all resources deployed by this module')
param resourceToken string

@minLength(1)
@description('Primary location for all resources')
param location string = resourceGroup().location

@description('An optional additional principal ID for the user or app doing the deployment')
param principalId string = ''

@description('A set of tags to apply to all resources in this environment')
param tags object = {}

/*
** User-assigned Managed Identity
*/
module userAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: 'managed-identity-${resourceToken}'
  params: {
    name: 'mi-app-${resourceToken}'
    location: location
    tags: tags
  }
}

/*
** Log Analytics Workspace
*/
module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.9.0' = {
  name: 'log-analytics-${resourceToken}'
  params: {
    name: 'law-${resourceToken}'
    location: location
    tags: tags
    skuName: 'PerGB2018'
  }
}

/*
** Application Insights
*/
module appInsights 'br/public:avm/res/insights/component:0.4.2' = {
  name: 'app-insights-${resourceToken}'
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
** Azure Key Vault
*/
module keyVault 'br/public:avm/res/key-vault/vault:0.11.0' = {
  name: 'key-vault-${resourceToken}'
  params: {
    name: 'kv-${resourceToken}'
    location: location
    tags: tags
    enablePurgeProtection: false
    enableSoftDelete: false
    enableRbacAuthorization: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    roleAssignments: concat(
      [ 
        { principalId: userAssignedIdentity.outputs.principalId, principalType: 'ServicePrincipal', roleDefinitionIdOrName: 'Key Vault Secrets User' } 
      ], 
      principalId == '' ? [] : [
        { principalId: principalId, principalType: 'User', roleDefinitionIdOrName: 'Key Vault Secrets Officer' }
        { principalId: principalId, principalType: 'User', roleDefinitionIdOrName: 'Owner' }
      ]
    )
  }
}

/*
** Outputs so that other modules can reference the resources created by this module
*/
output managedIdentityResourceId string = userAssignedIdentity.outputs.resourceId
output managedIdentityPrincipalId string = userAssignedIdentity.outputs.principalId

output logAnalyticsResourceId string = logAnalytics.outputs.resourceId
output logAnalyticsWorkspaceId string = logAnalytics.outputs.logAnalyticsWorkspaceId

output appInsightsResourceId string = appInsights.outputs.resourceId
output appInsightsConnectionString string = appInsights.outputs.connectionString

output keyVaultResourceId string = keyVault.outputs.resourceId
output keyVaultUri string = keyVault.outputs.uri
