/*
Copyright (c) Microsoft Corporation.
Licensed under the MIT License.
*/

param clientIpConfigurationSubnetResourceId string
param clientIpConfigurationPublicIPAddressResourceId string
param dnsServers array
param enableProxy bool
param firewallPolicyName string
param firewallSupernetIPAddress array
@allowed([
  'Alert'
  'Deny'
  'Off'
])
param intrusionDetectionMode string
param location string
param managementIpConfigurationSubnetResourceId string
param managementIpConfigurationPublicIPAddressResourceId string
param mlzTags object
param name string
@allowed([
  'Standard'
  'Premium'
  'Basic'
])
param skuTier string
param tags object = {}
@allowed([
  'Alert'
  'Deny'
  'Off'
])
param threatIntelMode string

//param spokeVnetAddresses array

var intrusionDetectionObject = {
  mode: intrusionDetectionMode
}

var dnsSettings = {
  enableProxy: enableProxy
  servers: dnsServers
}

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2021-02-01' = {
  name: firewallPolicyName
  location: location
  tags: union(contains(tags, 'Microsoft.Network/firewallPolicies') ? tags['Microsoft.Network/firewallPolicies'] : {}, mlzTags)
  properties: {
    threatIntelMode: threatIntelMode
    intrusionDetection: ((skuTier == 'Premium') ? intrusionDetectionObject : null)
    sku: {
      tier: skuTier
    }
    dnsSettings: ((skuTier == 'Premium' || skuTier == 'Standard') ? dnsSettings : null)
  }
}

resource mlzIpGroup 'Microsoft.Network/ipGroups@2024-03-01' = {
  location: location
  name: 'ipg-mlz-spokes'
  properties: {
    ipAddresses: firewallSupernetIPAddress
  }
  tags: mlzTags
}

resource kmsIpGroup 'Microsoft.Network/ipGroups@2024-03-01' = {
  location: location
  name: 'ipg-ksm-spokes'
  properties: {
    ipAddresses: [
      '20.118.99.224'
      '40.83.235.53'
      '23.102.135.246'
    ]
  }
  tags: mlzTags
}


resource firewallAppRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2021-02-01' = {
  parent: firewallPolicy
  name: 'DefaultApplicationRuleCollectionGroup'
  properties: {
    priority: 300
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'msftauth'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            fqdnTags: []
            webCategories: []
            targetFqdns: [
              'aadcdn.msftauth.net'
              'aadcdn.msauth.net'
            ]
            targetUrls: []
            terminateTLS: false
            sourceAddresses: [
              '*'
            ]
            destinationAddresses: []
            sourceIpGroups: []
          }
        ]
        name: 'AzureAuth'
        priority: 110
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'AllowOutboundTemp'
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
            fqdnTags: []
            webCategories: []
            targetFqdns: [
              '*'
            ]
            targetUrls: []
            terminateTLS: false
            sourceAddresses: []
            destinationAddresses: []
            sourceIpGroups: [
              mlzIpGroup.id
            ]
          }
        ]
        name: 'AzureAuth'
        priority: 65000
      }
    ]
  }
}

resource firewallNetworkRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2021-02-01' = {
  parent: firewallPolicy
  name: 'DefaultNetworkRuleCollectionGroup'
  dependsOn: [
    firewallAppRuleCollectionGroup
  ]
  properties: {
    priority: 200
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'AzureCloud'
            ipProtocols: [
              'Any'
            ]
            sourceAddresses: [
              '*'
            ]
            sourceIpGroups: []
            destinationAddresses: [
              'AzureCloud'
            ]
            destinationIpGroups: []
            destinationFqdns: []
            destinationPorts: [
              '*'
            ]
          }
        ]
        name: 'AllowAzureCloud'
        priority: 100
      }
      // {
      //   ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
      //   action: {
      //     type: 'Allow'
      //   }
      //   rules: [
      //     {
      //       ruleType: 'NetworkRule'
      //       name: 'AllSpokeTraffic'
      //       ipProtocols: [
      //         'Any'
      //       ]
      //       sourceAddresses: []
      //       sourceIpGroups: [
      //         mlzIpGroup.id
      //       ]
      //       destinationAddresses: [
      //         '*'
      //       ]
      //       destinationIpGroups: []
      //       destinationFqdns: []
      //       destinationPorts: [
      //         '*'
      //       ]
      //     }
      //   ]
      //   name: 'AllowOutbound'
      //   priority: 65000
      // }
      // {
      //   ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
      //   action: {
      //     type: 'Allow'
      //   }
      //   rules: [
      //     {
      //       ruleType: 'NetworkRule'
      //       name: 'KMS'
      //       ipProtocols: [
      //         'Any'
      //       ]
      //       sourceAddresses: []
      //       sourceIpGroups: [
      //         mlzIpGroup.id
      //       ]
      //       destinationAddresses: []
      //       destinationIpGroups: [
      //         kmsIpGroup.id
      //       ]
      //       destinationFqdns: []
      //       destinationPorts: [
      //         '*'
      //       ]
      //     }
      //   ]
      //   name: 'AllowTrafficBetweenSpokes'
      //   priority: 210
      // }
    ]
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2021-02-01' = {
  name: name
  location: location
  tags: union(contains(tags, 'Microsoft.Network/azureFirewalls') ? tags['Microsoft.Network/azureFirewalls'] : {}, mlzTags)
  dependsOn: [
    firewallNetworkRuleCollectionGroup
    firewallAppRuleCollectionGroup
  ]
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig-client'
        properties: {
          subnet: {
            id: clientIpConfigurationSubnetResourceId
          }
          publicIPAddress: {
            id: clientIpConfigurationPublicIPAddressResourceId
          }
        }
      }
    ]
    managementIpConfiguration: {
      name: 'ipconfig-management'
      properties: {
        subnet: {
          id: managementIpConfigurationSubnetResourceId
        }
        publicIPAddress: {
          id: managementIpConfigurationPublicIPAddressResourceId
        }
      }
    }
    firewallPolicy: {
      id: firewallPolicy.id
    }
    sku: {
      tier: skuTier
    }
  }
}

output name string = firewall.name
output privateIPAddress string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output resourceId string = firewall.id
