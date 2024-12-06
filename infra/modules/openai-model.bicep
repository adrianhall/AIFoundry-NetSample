/*
** Deploys an OpenAI Model to a connected AI Foundry.
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

@description('The name of the Azure AI Foundry Project that this model will be linked to')
param aiFoundryProjectName string

@description('The name of the model you want to deploy')
param modelName string = 'gpt-4o-mini'

// Find out the complete list of allowed values for this parameter
@description('The style of deployment')
@allowed([ 'Global Standard' ])
param deploymentType string = 'Global Standard'

// TODO: Create resources

output modelName string = modelName
