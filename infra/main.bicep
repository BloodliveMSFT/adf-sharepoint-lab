@description('Azure region for all resources.')
param location string

@description('Name of the Data Factory.')
param factoryName string

@description('GitHub account name (owner/org).')
param gitAccountName string

@description('GitHub repository name.')
param gitRepositoryName string

@description('Git collaboration branch, e.g. main.')
param gitCollaborationBranch string = 'main'

@description('Root folder in repo where ADF JSON lives.')
param gitRootFolder string = '/adf'

@description('Publish branch for ADF (usually adf_publish).')
param gitPublishBranch string = 'adf_publish'

@description('Optional: Storage account resource ID for RBAC assignment (ADLS Gen2). Leave empty to skip RBAC.')
param storageAccountId string = ''

// Data Factory with system-assigned identity
resource df 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: factoryName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // Configure GitHub repo integration (Factory Git mode)
    repoConfiguration: {
      type: 'FactoryVSTSConfiguration' // NOTE: For GitHub use FactoryGitHubConfiguration in newer API versions if available in your environment.
      accountName: gitAccountName
      repositoryName: gitRepositoryName
      collaborationBranch: gitCollaborationBranch
      rootFolder: gitRootFolder
      lastCommitId: ''
      publishBranch: gitPublishBranch
    }
  }
}

// Optional RBAC assignment to Storage Account for ADF managed identity
// Storage Blob Data Contributor role definition ID (built-in)
var storageBlobDataContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')

resource storageRbac 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (storageAccountId != '') {
  name: guid(storageAccountId, df.identity.principalId, storageBlobDataContributorRoleId)
  scope: resourceId(storageAccountId)
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleId
    principalId: df.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output factoryResourceId string = df.id
output factoryPrincipalId string = df.identity.principalId
