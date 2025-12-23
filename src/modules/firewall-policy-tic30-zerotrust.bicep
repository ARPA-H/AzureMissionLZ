/*
Copyright (c) Microsoft Corporation.
Licensed under the MIT License.

TIC 3.0 and Zero Trust Compliant Firewall Policy Rules
This module creates comprehensive firewall rules aligned with:
- TIC 3.0 security capabilities
- Zero Trust architecture principles
- Azure Well-Architected Framework best practices
*/

@description('The name of the existing Firewall Policy to update')
param firewallPolicyName string

@description('Array of spoke VNet address prefixes for source filtering')
param spokeVnetAddresses array

@description('Tags to apply to resources')
param tags object = {}

@description('Enable TIC 3.0 high-security rules (more restrictive)')
param enableHighSecurityMode bool = true

@description('Array of approved external FQDNs for specific workloads')
param approvedExternalFqdns array = []

@description('Enable Microsoft 365 access')
param enableMicrosoft365 bool = true

@description('Enable Windows Update access')
param enableWindowsUpdate bool = true

@description('Enable Azure DevOps access')
param enableAzureDevOps bool = false

@description('Enable GitHub access')
param enableGitHub bool = false

// Reference existing firewall policy in the same resource group
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-11-01' existing = {
  name: firewallPolicyName
}

// Create IP Group for spoke networks - Zero Trust boundary
resource spokesIpGroup 'Microsoft.Network/ipGroups@2023-11-01' = {
  name: 'ipg-zerotrust-spokes'
  location: resourceGroup().location
  tags: tags
  properties: {
    ipAddresses: spokeVnetAddresses
  }
}

// TIC 3.0 Priority 100: Baseline Security - Deny High-Risk Traffic
resource baselineSecurityRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-11-01' = {
  parent: firewallPolicy
  name: 'TIC30-100-BaselineSecurity'
  properties: {
    priority: 100
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'BlockHighRiskCategories'
        priority: 100
        action: {
          type: 'Deny'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'Block-Malicious-Categories'
            description: 'TIC 3.0: Block known malicious web categories'
            protocols: [
              {
                protocolType: 'Http'
                port: 80
              }
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceAddresses: ['*']
            webCategories: [
              'Hacking'
              'Malware'
              'Phishing'
              'ProxyAvoidanceAndAnonymizers'
              'Spyware'
              'BotnetsAndZombies'
              'IllegalSoftware'
            ]
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'BlockUnencryptedProtocols'
        priority: 110
        action: {
          type: 'Deny'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'Block-Unencrypted-Protocols'
            description: 'TIC 3.0: Block insecure legacy protocols'
            ipProtocols: ['TCP']
            sourceAddresses: ['*']
            destinationAddresses: ['*']
            destinationPorts: [
              '21'    // FTP
              '23'    // Telnet
              '69'    // TFTP
              '161'   // SNMP
              '445'   // SMB
            ]
          }
        ]
      }
    ]
  }
}

// TIC 3.0 Priority 200: Essential Azure Services
resource essentialServicesRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-11-01' = {
  parent: firewallPolicy
  name: 'TIC30-200-EssentialServices'
  dependsOn: [baselineSecurityRuleCollectionGroup]
  properties: {
    priority: 200
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'AzureManagementServices'
        priority: 200
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'Allow-Azure-Monitor'
            description: 'Zero Trust: Azure Monitor for observability'
            ipProtocols: ['TCP']
            sourceIpGroups: [spokesIpGroup.id]
            destinationAddresses: ['AzureMonitor']
            destinationPorts: ['443']
          }
          {
            ruleType: 'NetworkRule'
            name: 'Allow-Azure-Storage'
            description: 'Zero Trust: Azure Storage service tag'
            ipProtocols: ['TCP']
            sourceIpGroups: [spokesIpGroup.id]
            destinationAddresses: ['Storage']
            destinationPorts: ['443']
          }
          {
            ruleType: 'NetworkRule'
            name: 'Allow-Azure-KeyVault'
            description: 'Zero Trust: Azure Key Vault for secrets management'
            ipProtocols: ['TCP']
            sourceIpGroups: [spokesIpGroup.id]
            destinationAddresses: ['AzureKeyVault']
            destinationPorts: ['443']
          }
          {
            ruleType: 'NetworkRule'
            name: 'Allow-Azure-Backup'
            description: 'Zero Trust: Azure Backup service'
            ipProtocols: ['TCP']
            sourceIpGroups: [spokesIpGroup.id]
            destinationAddresses: ['AzureBackup']
            destinationPorts: ['443']
          }
          {
            ruleType: 'NetworkRule'
            name: 'Allow-Azure-ActiveDirectory'
            description: 'Zero Trust: Azure AD authentication'
            ipProtocols: ['TCP']
            sourceIpGroups: [spokesIpGroup.id]
            destinationAddresses: ['AzureActiveDirectory']
            destinationPorts: ['443', '80']
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'AzureAuthenticationServices'
        priority: 210
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'Allow-Azure-AD-Authentication'
            description: 'TIC 3.0: Azure AD authentication endpoints'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceIpGroups: [spokesIpGroup.id]
            targetFqdns: [
              uri(environment().authentication.loginEndpoint, '')
              'login.microsoft.com'
              'login.windows.net'
              'aadcdn.msauth.net'
              'aadcdn.msftauth.net'
              'pas.windows.net'
            ]
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'TimeServices'
        priority: 220
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'Allow-NTP'
            description: 'TIC 3.0: Network Time Protocol for time synchronization'
            ipProtocols: ['UDP']
            sourceIpGroups: [spokesIpGroup.id]
            destinationFqdns: [
              'time.windows.com'
              'time.nist.gov'
            ]
            destinationPorts: ['123']
          }
        ]
      }
    ]
  }
}

// TIC 3.0 Priority 300: Microsoft Services (Conditional)
resource microsoftServicesRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-11-01' = {
  parent: firewallPolicy
  name: 'TIC30-300-MicrosoftServices'
  dependsOn: [essentialServicesRuleCollectionGroup]
  properties: {
    priority: 300
    ruleCollections: concat(
      enableMicrosoft365 ? [
        {
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          name: 'Microsoft365Services'
          priority: 300
          action: {
            type: 'Allow'
          }
          rules: [
            {
              ruleType: 'ApplicationRule'
              name: 'Allow-M365-Services'
              description: 'TIC 3.0: Microsoft 365 services'
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              sourceIpGroups: [spokesIpGroup.id]
              fqdnTags: ['MicrosoftActiveProtectionService']
            }
            {
              ruleType: 'ApplicationRule'
              name: 'Allow-Microsoft365-Core'
              description: 'Zero Trust: M365 core services'
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              sourceIpGroups: [spokesIpGroup.id]
              targetFqdns: [
                '*.office365.com'
                '*.microsoft.com'
                '*.office.com'
                '*.office.net'
                '*.microsoftonline.com'
                'outlook.office365.com'
                '*.protection.outlook.com'
                '*.sharepoint.com'
                '*.onedrive.com'
              ]
            }
          ]
        }
      ] : [],
      enableWindowsUpdate ? [
        {
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          name: 'WindowsUpdateServices'
          priority: 310
          action: {
            type: 'Allow'
          }
          rules: [
            {
              ruleType: 'ApplicationRule'
              name: 'Allow-Windows-Update'
              description: 'TIC 3.0: Windows Update for security patches'
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
                {
                  protocolType: 'Http'
                  port: 80
                }
              ]
              sourceIpGroups: [spokesIpGroup.id]
              fqdnTags: ['WindowsUpdate', 'WindowsDiagnostics']
            }
          ]
        }
      ] : [],
      enableAzureDevOps ? [
        {
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          name: 'AzureDevOpsServices'
          priority: 320
          action: {
            type: 'Allow'
          }
          rules: [
            {
              ruleType: 'ApplicationRule'
              name: 'Allow-Azure-DevOps'
              description: 'Zero Trust: Azure DevOps for CI/CD'
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              sourceIpGroups: [spokesIpGroup.id]
              targetFqdns: [
                '*.visualstudio.com'
                '*.dev.azure.com'
                'dev.azure.com'
                'azure.microsoft.com'
                '*.vsassets.io'
                '*.vssps.visualstudio.com'
                '*.vstmrblob.vsassets.io'
              ]
            }
          ]
        }
      ] : [],
      enableGitHub ? [
        {
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          name: 'GitHubServices'
          priority: 330
          action: {
            type: 'Allow'
          }
          rules: [
            {
              ruleType: 'ApplicationRule'
              name: 'Allow-GitHub'
              description: 'Zero Trust: GitHub for source control'
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              sourceIpGroups: [spokesIpGroup.id]
              targetFqdns: [
                'github.com'
                '*.github.com'
                'api.github.com'
                'raw.githubusercontent.com'
                'github.githubassets.com'
                'codeload.github.com'
              ]
            }
          ]
        }
      ] : []
    )
  }
}

// TIC 3.0 Priority 400: Workload-Specific Rules
resource workloadSpecificRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-11-01' = if (!enableHighSecurityMode || length(approvedExternalFqdns) > 0) {
  parent: firewallPolicy
  name: 'TIC30-400-WorkloadSpecific'
  dependsOn: [microsoftServicesRuleCollectionGroup]
  properties: {
    priority: 400
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'ApprovedExternalServices'
        priority: 400
        action: {
          type: 'Allow'
        }
        rules: length(approvedExternalFqdns) > 0 ? [
          {
            ruleType: 'ApplicationRule'
            name: 'Allow-Approved-External-FQDNs'
            description: 'Zero Trust: Pre-approved external services'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceIpGroups: [spokesIpGroup.id]
            targetFqdns: approvedExternalFqdns
          }
        ] : []
      }
    ]
  }
}

// TIC 3.0 Priority 500: Azure PaaS Services (Database, AI, etc.)
resource azurePaaSRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-11-01' = {
  parent: firewallPolicy
  name: 'TIC30-500-AzurePaaS'
  dependsOn: [workloadSpecificRuleCollectionGroup]
  properties: {
    priority: 500
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'AzureDatabaseServices'
        priority: 500
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'Allow-Azure-SQL'
            description: 'Zero Trust: Azure SQL Database'
            ipProtocols: ['TCP']
            sourceIpGroups: [spokesIpGroup.id]
            destinationAddresses: ['Sql']
            destinationPorts: ['1433']
          }
          {
            ruleType: 'NetworkRule'
            name: 'Allow-Azure-CosmosDB'
            description: 'Zero Trust: Azure Cosmos DB'
            ipProtocols: ['TCP']
            sourceIpGroups: [spokesIpGroup.id]
            destinationAddresses: ['AzureCosmosDB']
            destinationPorts: ['443', '10250-10255']
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'AzureAIServices'
        priority: 510
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'Allow-Cognitive-Services'
            description: 'Zero Trust: Azure Cognitive Services'
            ipProtocols: ['TCP']
            sourceIpGroups: [spokesIpGroup.id]
            destinationAddresses: ['CognitiveServicesManagement']
            destinationPorts: ['443']
          }
          {
            ruleType: 'ApplicationRule'
            name: 'Allow-OpenAI-Service'
            description: 'Zero Trust: Azure OpenAI Service'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceIpGroups: [spokesIpGroup.id]
            targetFqdns: [
              '*.openai.azure.com'
              'openai.azure.com'
            ]
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'AzureContainerServices'
        priority: 520
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'Allow-Container-Registry'
            description: 'Zero Trust: Azure Container Registry'
            ipProtocols: ['TCP']
            sourceIpGroups: [spokesIpGroup.id]
            destinationAddresses: ['AzureContainerRegistry']
            destinationPorts: ['443']
          }
          {
            ruleType: 'NetworkRule'
            name: 'Allow-Kubernetes-API'
            description: 'Zero Trust: Azure Kubernetes Service API'
            ipProtocols: ['TCP']
            sourceIpGroups: [spokesIpGroup.id]
            destinationAddresses: ['AzureKubernetesService']
            destinationPorts: ['443']
          }
        ]
      }
    ]
  }
}

@description('The resource ID of the updated Firewall Policy')
output firewallPolicyId string = firewallPolicy.id

@description('The name of the updated Firewall Policy')
output firewallPolicyName string = firewallPolicy.name

@description('The resource ID of the spokes IP Group')
output spokesIpGroupId string = spokesIpGroup.id

@description('Rule collection groups created')
output ruleCollectionGroupsCreated array = [
  'TIC30-100-BaselineSecurity'
  'TIC30-200-EssentialServices'
  'TIC30-300-MicrosoftServices'
  enableHighSecurityMode || length(approvedExternalFqdns) > 0 ? 'TIC30-400-WorkloadSpecific' : ''
  'TIC30-500-AzurePaaS'
]
