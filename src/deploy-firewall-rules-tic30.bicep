/*
Copyright (c) Microsoft Corporation.
Licensed under the MIT License.

Main deployment file for TIC 3.0 and Zero Trust compliant firewall rules
This deployment adds comprehensive rule collections to an existing Azure Firewall Policy
*/

targetScope = 'subscription'

@description('The subscription ID where the Hub resources exist')
param hubSubscriptionId string

@description('The resource group containing the Firewall Policy')
param hubResourceGroupName string

@description('The name of the existing Firewall Policy')
param firewallPolicyName string

@description('Location for the deployment')
param location string = deployment().location

@description('Array of spoke VNet CIDR ranges for Zero Trust segmentation')
param spokeVnetAddresses array

@description('Enable TIC 3.0 high-security mode (more restrictive rules)')
param enableHighSecurityMode bool = true

@description('Enable Microsoft 365 access')
param enableMicrosoft365 bool = true

@description('Enable Windows Update access')
param enableWindowsUpdate bool = true

@description('Enable Azure DevOps access')
param enableAzureDevOps bool = false

@description('Enable GitHub access')
param enableGitHub bool = false

@description('Array of approved external FQDNs (e.g., ["api.example.com", "*.partner.com"])')
param approvedExternalFqdns array = []

@description('Tags to apply to all resources')
param tags object = {
  'Compliance': 'TIC 3.0'
  'Architecture': 'Zero Trust'
  'ManagedBy': 'AzureMissionLZ'
  'DeploymentType': 'FirewallRules'
}

@description('Timestamp for deployment tracking')
param deploymentTimestamp string = utcNow('yyyy-MM-dd-HH-mm-ss')

// Deploy firewall rules to the hub subscription
module firewallRules './modules/firewall-policy-tic30-zerotrust.bicep' = {
  name: 'deploy-firewall-rules-tic30-${deploymentTimestamp}'
  scope: resourceGroup(hubSubscriptionId, hubResourceGroupName)
  params: {
    firewallPolicyName: firewallPolicyName
    spokeVnetAddresses: spokeVnetAddresses
    tags: tags
    enableHighSecurityMode: enableHighSecurityMode
    approvedExternalFqdns: approvedExternalFqdns
    enableMicrosoft365: enableMicrosoft365
    enableWindowsUpdate: enableWindowsUpdate
    enableAzureDevOps: enableAzureDevOps
    enableGitHub: enableGitHub
  }
}

// Outputs
@description('The resource ID of the Firewall Policy that was updated')
output firewallPolicyId string = firewallRules.outputs.firewallPolicyId

@description('The name of the Firewall Policy')
output firewallPolicyName string = firewallRules.outputs.firewallPolicyName

@description('The resource ID of the spokes IP Group created')
output spokesIpGroupId string = firewallRules.outputs.spokesIpGroupId

@description('List of rule collection groups that were created')
output ruleCollectionGroupsCreated array = firewallRules.outputs.ruleCollectionGroupsCreated

@description('Deployment timestamp')
output deploymentTime string = deploymentTimestamp

@description('Configuration summary')
output configurationSummary object = {
  tic30Compliance: true
  zeroTrustEnabled: true
  highSecurityMode: enableHighSecurityMode
  microsoft365Enabled: enableMicrosoft365
  windowsUpdateEnabled: enableWindowsUpdate
  azureDevOpsEnabled: enableAzureDevOps
  gitHubEnabled: enableGitHub
  spokeNetworksConfigured: length(spokeVnetAddresses)
  approvedExternalFqdnsCount: length(approvedExternalFqdns)
}
