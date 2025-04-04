/*
Copyright (c) Microsoft Corporation.
Licensed under the MIT License.
*/

param deploySentinel bool = false
param location string
param mlzTags object
param name string
param retentionInDays int = 30
param skuName string = 'PerGB2018'
param tags object
param workspaceCappingDailyQuotaGb int = -1

// Solutions to add to workspace
var solutions = [
  {
    deploy: true
    name: 'AzureActivity'
    product: 'OMSGallery/AzureActivity'
    publisher: 'Microsoft'
    promotionCode: ''
  }
  {
    deploy: deploySentinel
    name: 'SecurityInsights'
    product: 'OMSGallery/SecurityInsights'
    publisher: 'Microsoft'
    promotionCode: ''
  }
  {
    deploy: true
    name: 'VMInsights'
    product: 'OMSGallery/VMInsights'
    publisher: 'Microsoft'
    promotionCode: '' 
  }
  {
    deploy: true
    name: 'Security'
    product: 'OMSGallery/Security'
    publisher: 'Microsoft'
    promotionCode: ''
  }
  {
    deploy: true
    name: 'ServiceMap'
    publisher: 'Microsoft'
    product: 'OMSGallery/ServiceMap'
    promotionCode: ''
  }
  {
    deploy: true
    name: 'ContainerInsights'
    publisher: 'Microsoft'
    product: 'OMSGallery/ContainerInsights'
    promotionCode: ''
  }
  {
    deploy: true
    name: 'KeyVaultAnalytics'
    publisher: 'Microsoft'
    product: 'OMSGallery/KeyVaultAnalytics'
    promotionCode: ''
  }
]

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: name
  location: location
  tags: union(tags[?'Microsoft.OperationalInsights/workspaces'] ?? {}, mlzTags)
  properties: {
    retentionInDays: deploySentinel && retentionInDays < 90 ? 90 : retentionInDays
    sku:{
      name: skuName
    }
    workspaceCapping: {
      dailyQuotaGb: workspaceCappingDailyQuotaGb
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource logAnalyticsSolutions 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = [for solution in solutions: if(solution.deploy) {
  name: '${solution.name}(${logAnalyticsWorkspace.name})'
  location: location
  tags: union(tags[?'Microsoft.OperationsManagement/solutions'] ?? {}, mlzTags)
  properties: {
    workspaceResourceId: logAnalyticsWorkspace.id
  }
  plan: {
    name: '${solution.name}(${logAnalyticsWorkspace.name})'
    product: solution.product
    publisher: solution.publisher
    promotionCode: solution.promotionCode
  }
}]

output resourceId string = logAnalyticsWorkspace.id
