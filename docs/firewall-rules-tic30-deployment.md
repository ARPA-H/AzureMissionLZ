# TIC 3.0 and Zero Trust Firewall Rules Deployment

This deployment adds comprehensive, compliance-focused firewall rules to your existing Azure Mission Landing Zone (MLZ) firewall policy.

## 🎯 Overview

This solution implements:
- **TIC 3.0 Compliance**: Trusted Internet Connection security capabilities
- **Zero Trust Architecture**: Least-privilege access, explicit verification
- **Azure Well-Architected Framework**: Security, reliability, and operational excellence best practices

## 📋 Prerequisites

1. **Existing MLZ Deployment**
   - Azure Firewall deployed (Standard or Premium SKU recommended)
   - Firewall Policy created
   - Hub-spoke network topology

2. **Required Access**
   - Contributor or Owner role on the Hub subscription
   - Permissions to modify Firewall Policy

3. **GitHub Secrets** (for workflow)
   - `CLIENT_ID`: Azure service principal client ID
   - `TENANT_ID`: Azure AD tenant ID
   - `SUBSCRIPTION_ID`: Target subscription ID
   - `HUB_SUB_ID`: Hub subscription ID
   - `HUB_RESOURCE_GROUP`: Hub resource group name (e.g., `rg-mlz-hub-dev`)
   - `FIREWALL_POLICY_NAME`: Firewall policy name (e.g., `afwp-mlz-hub-dev`)
   - `SUPERNET_ADDRESS`: JSON array of spoke VNet CIDR ranges

## 🏗️ Architecture

### Rule Collection Groups Hierarchy

```
Priority 100: TIC30-100-BaselineSecurity
├── Block malicious web categories (Hacking, Malware, Phishing, etc.)
└── Block insecure protocols (FTP, Telnet, TFTP, SNMP, SMB)

Priority 200: TIC30-200-EssentialServices
├── Azure Monitor (observability)
├── Azure Storage
├── Azure Key Vault
├── Azure Backup
├── Azure Active Directory
├── Azure AD Authentication endpoints
└── NTP time synchronization

Priority 300: TIC30-300-MicrosoftServices
├── Microsoft 365 (conditional)
├── Windows Update (conditional)
├── Azure DevOps (conditional)
└── GitHub (conditional)

Priority 400: TIC30-400-WorkloadSpecific
└── Approved external FQDNs (custom)

Priority 500: TIC30-500-AzurePaaS
├── Azure SQL Database
├── Azure Cosmos DB
├── Azure Cognitive Services
├── Azure OpenAI
├── Azure Container Registry
└── Azure Kubernetes Service
```

## 🚀 Deployment Options

### Option 1: GitHub Workflow (Recommended)

1. **Navigate to Actions** in your GitHub repository
2. **Select** "Deploy TIC 3.0 Firewall Rules"
3. **Click** "Run workflow"
4. **Configure**:
   - Environment: development/staging/production
   - High Security Mode: `true` (recommended)
   - Microsoft 365: `true` (if needed)
   - Windows Update: `true` (recommended)
   - Azure DevOps: `false` (enable if used)
   - GitHub: `false` (enable if used)
   - What-If Only: `true` (for first run)
5. **Review** What-If results
6. **Re-run** with What-If Only: `false` to deploy

### Option 2: Azure CLI

```bash
# Login
az login

# Set variables
LOCATION="centralus"
HUB_SUB_ID="your-hub-subscription-id"
HUB_RG="rg-mlz-hub-dev"
FW_POLICY="afwp-mlz-hub-dev"
SPOKE_ADDRESSES='["10.0.100.0/24","10.0.110.0/24","10.0.120.0/24"]'

# Validate
az deployment sub validate \
  --location $LOCATION \
  --template-file ./src/deploy-firewall-rules-tic30.bicep \
  --parameters hubSubscriptionId=$HUB_SUB_ID \
               hubResourceGroupName=$HUB_RG \
               firewallPolicyName=$FW_POLICY \
               spokeVnetAddresses=$SPOKE_ADDRESSES \
               enableHighSecurityMode=true \
               enableMicrosoft365=true \
               enableWindowsUpdate=true

# What-If
az deployment sub what-if \
  --location $LOCATION \
  --template-file ./src/deploy-firewall-rules-tic30.bicep \
  --parameters hubSubscriptionId=$HUB_SUB_ID \
               hubResourceGroupName=$HUB_RG \
               firewallPolicyName=$FW_POLICY \
               spokeVnetAddresses=$SPOKE_ADDRESSES

# Deploy
az deployment sub create \
  --location $LOCATION \
  --name deploy-fw-rules-tic30 \
  --template-file ./src/deploy-firewall-rules-tic30.bicep \
  --parameters hubSubscriptionId=$HUB_SUB_ID \
               hubResourceGroupName=$HUB_RG \
               firewallPolicyName=$FW_POLICY \
               spokeVnetAddresses=$SPOKE_ADDRESSES
```

### Option 3: Azure PowerShell

```powershell
# Connect
Connect-AzAccount

# Set variables
$Location = "centralus"
$HubSubId = "your-hub-subscription-id"
$HubRG = "rg-mlz-hub-dev"
$FwPolicy = "afwp-mlz-hub-dev"
$SpokeAddresses = @("10.0.100.0/24", "10.0.110.0/24", "10.0.120.0/24")

# What-If
New-AzSubscriptionDeployment `
  -Location $Location `
  -TemplateFile "./src/deploy-firewall-rules-tic30.bicep" `
  -hubSubscriptionId $HubSubId `
  -hubResourceGroupName $HubRG `
  -firewallPolicyName $FwPolicy `
  -spokeVnetAddresses $SpokeAddresses `
  -WhatIf

# Deploy
New-AzSubscriptionDeployment `
  -Location $Location `
  -Name "deploy-fw-rules-tic30" `
  -TemplateFile "./src/deploy-firewall-rules-tic30.bicep" `
  -hubSubscriptionId $HubSubId `
  -hubResourceGroupName $HubRG `
  -firewallPolicyName $FwPolicy `
  -spokeVnetAddresses $SpokeAddresses
```

## ⚙️ Configuration Parameters

### Core Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `hubSubscriptionId` | string | Yes | Hub subscription ID |
| `hubResourceGroupName` | string | Yes | Hub resource group name |
| `firewallPolicyName` | string | Yes | Existing firewall policy name |
| `location` | string | No | Deployment location (default: deployment location) |
| `spokeVnetAddresses` | array | Yes | Array of spoke VNet CIDR ranges |

### Security Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enableHighSecurityMode` | bool | true | Enable stricter security controls |
| `enableMicrosoft365` | bool | true | Allow Microsoft 365 services |
| `enableWindowsUpdate` | bool | true | Allow Windows Update |
| `enableAzureDevOps` | bool | false | Allow Azure DevOps |
| `enableGitHub` | bool | false | Allow GitHub |
| `approvedExternalFqdns` | array | [] | Custom approved external FQDNs |

### Example: Approved External FQDNs

```json
{
  "approvedExternalFqdns": {
    "value": [
      "api.partner.gov",
      "*.approved-vendor.com",
      "data.research-org.edu"
    ]
  }
}
```

## 🔒 TIC 3.0 Compliance Mapping

| TIC 3.0 Security Capability | Implementation |
|----------------------------|----------------|
| **Access Control** | IP Groups, least-privilege rules, Zero Trust segmentation |
| **Threat Detection** | IDPS (Alert and Deny mode), Threat Intelligence |
| **Encryption** | TLS Inspection (Premium), HTTPS-only rules |
| **Data Loss Prevention** | FQDN filtering, web categories |
| **Security Monitoring** | Diagnostic logs to Log Analytics, Azure Monitor |
| **Incident Response** | Integration with Microsoft Sentinel |
| **Asset Management** | Service tags, IP Groups, hierarchical policies |

## 🛡️ Zero Trust Principles

### 1. Verify Explicitly
- All traffic authenticated and authorized
- Source IP Groups for network segmentation
- Service-specific rules (no wildcards in high-security mode)

### 2. Use Least-Privilege Access
- Deny-by-default approach
- Explicit allow rules only
- Hierarchical policy structure

### 3. Assume Breach
- Network segmentation via spoke VNets
- East-west traffic inspection
- Continuous monitoring and logging

## 📊 Monitoring and Compliance

### Required Diagnostic Settings

Ensure your Azure Firewall has these diagnostic categories enabled:

```bicep
diagnosticSettings: {
  logs: [
    'AzureFirewallApplicationRule'
    'AzureFirewallNetworkRule'
    'AzureFirewallDnsProxy'
    'AzureFirewallThreatIntelLog'
  ]
  metrics: ['AllMetrics']
}
```

### Key Metrics to Monitor

| Metric | Alert Threshold | Purpose |
|--------|----------------|---------|
| SNAT Port Utilization | > 80% | Capacity planning |
| Firewall Health State | < 100% | Availability |
| Throughput | Varies | Performance |
| IDPS Signature Hits | > 0 | Security incidents |
| Denied Connections | High rate | Misconfiguration or attacks |

### KQL Queries for Monitoring

```kql
// Denied connections (potential threats)
AzureDiagnostics
| where Category == "AzureFirewallApplicationRule" or Category == "AzureFirewallNetworkRule"
| where OperationName == "AzureFirewallApplicationRuleLog" or OperationName == "AzureFirewallNetworkRuleLog"
| where msg_s contains "Deny"
| project TimeGenerated, Resource, msg_s
| order by TimeGenerated desc

// IDPS alerts
AzureDiagnostics
| where Category == "AzureFirewallThreatIntelLog"
| project TimeGenerated, Resource, msg_s, ThreatDescription_s, ThreatSeverity_s
| order by TimeGenerated desc

// Top blocked destinations
AzureDiagnostics
| where Category in ("AzureFirewallApplicationRule", "AzureFirewallNetworkRule")
| where msg_s contains "Deny"
| extend Destination = extract("to ([^:]+)", 1, msg_s)
| summarize DeniedCount = count() by Destination
| order by DeniedCount desc
| take 20
```

## 🧪 Testing and Validation

### 1. Validate Rule Processing

```bash
# Test allowed traffic (should succeed)
curl https://login.microsoftonline.com
curl https://management.azure.com

# Test blocked traffic (should fail)
curl http://malicious-site.example.com
```

### 2. Check Policy Application

```bash
# View firewall policy
az network firewall policy show \
  --name $FW_POLICY \
  --resource-group $HUB_RG \
  --query "ruleCollectionGroups" -o table

# View specific rule collection group
az network firewall policy rule-collection-group show \
  --name "TIC30-200-EssentialServices" \
  --policy-name $FW_POLICY \
  --resource-group $HUB_RG
```

### 3. Verify Logging

```bash
# Check diagnostic settings
az monitor diagnostic-settings list \
  --resource $(az network firewall show \
    --name <firewall-name> \
    --resource-group $HUB_RG \
    --query id -o tsv)
```

## 🔧 Troubleshooting

### Common Issues

#### Issue: Application connectivity broken after deployment

**Solution:**
1. Check firewall logs for denied connections:
   ```kql
   AzureDiagnostics | where msg_s contains "Deny" and TimeGenerated > ago(1h)
   ```
2. Identify required FQDNs/IPs
3. Add to `approvedExternalFqdns` parameter
4. Redeploy

#### Issue: Rule collection priority conflicts

**Solution:**
- Existing rules may conflict with priority ranges 100-500
- Check existing priorities: `az network firewall policy rule-collection-group list`
- Adjust priorities in the Bicep module if needed

#### Issue: SNAT port exhaustion

**Solution:**
- Add more public IP addresses to firewall
- Review traffic patterns
- Implement NAT Gateway for spoke VNets

### Rollback Procedure

```bash
# Delete rule collection groups
az network firewall policy rule-collection-group delete \
  --name "TIC30-100-BaselineSecurity" \
  --policy-name $FW_POLICY \
  --resource-group $HUB_RG

# Repeat for other groups: TIC30-200, TIC30-300, TIC30-400, TIC30-500

# Delete IP Group
az network ip-group delete \
  --name "ipg-zerotrust-spokes" \
  --resource-group $HUB_RG
```

## 📝 Customization

### Adding Custom Rules

Edit `src/modules/firewall-policy-tic30-zerotrust.bicep`:

```bicep
// Add a new rule collection to existing group
{
  ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
  name: 'CustomWorkloadRules'
  priority: 410
  action: {
    type: 'Allow'
  }
  rules: [
    {
      ruleType: 'ApplicationRule'
      name: 'Allow-Custom-API'
      protocols: [{protocolType: 'Https', port: 443}]
      sourceIpGroups: [spokesIpGroup.id]
      targetFqdns: ['api.custom-service.com']
    }
  ]
}
```

### Adjusting Security Posture

**More Restrictive (High Security)**
- Set `enableHighSecurityMode: true`
- Minimize `approvedExternalFqdns`
- Disable optional services (DevOps, GitHub)

**More Permissive (Development)**
- Set `enableHighSecurityMode: false`
- Add development FQDNs to `approvedExternalFqdns`
- Enable DevOps/GitHub access

## 🔄 Maintenance

### Quarterly Reviews
1. Review firewall logs for denied connections
2. Validate approved external FQDNs still required
3. Check for new Azure service tags
4. Update web category filters as needed
5. Review policy analytics dashboard

### Updates
- Microsoft maintains service tags automatically
- FQDN tags auto-update
- Web categories updated by Microsoft
- IDPS signatures auto-update (Premium)

## 📚 Additional Resources

- [Azure Firewall TIC 3.0 Guidance](https://learn.microsoft.com/en-us/azure/well-architected/service-guides/azure-firewall)
- [Zero Trust Architecture](https://learn.microsoft.com/en-us/security/zero-trust/)
- [TIC 3.0 CISA Documentation](https://www.cisa.gov/resources-tools/programs/trusted-internet-connections-tic)
- [Azure Firewall Documentation](https://learn.microsoft.com/en-us/azure/firewall/)
- [Azure Firewall Policy](https://learn.microsoft.com/en-us/azure/firewall/policy-overview)

## 🆘 Support

For issues or questions:
1. Review Azure Firewall logs in Log Analytics
2. Check Azure Firewall known issues
3. Consult Azure Well-Architected Framework guidance
4. Open an issue in this repository

## 📄 License

Copyright (c) Microsoft Corporation. Licensed under the MIT License.
