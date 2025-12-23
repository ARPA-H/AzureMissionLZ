# TIC 3.0 and Zero Trust Firewall Rules

This directory contains a separate deployment for adding TIC 3.0 and Zero Trust compliant firewall rules to your Azure Mission Landing Zone.

## 🎯 What This Deploys

Comprehensive firewall rule collections that implement:
- **TIC 3.0 Security Capabilities**: Meet CISA Trusted Internet Connection requirements
- **Zero Trust Architecture**: Explicit verification, least-privilege access, assume breach
- **Azure Well-Architected Framework**: Security, reliability, and operational excellence

## 📁 Files

```
src/
├── deploy-firewall-rules-tic30.bicep          # Main deployment file
├── modules/
│   └── firewall-policy-tic30-zerotrust.bicep  # Firewall rules module
├── parameters/
│   └── firewall-rules-tic30.parameters.json   # Sample parameters

.github/workflows/
└── deploy-firewall-rules-tic30.yml            # GitHub Actions workflow

docs/
├── firewall-rules-tic30-deployment.md         # Complete deployment guide
└── github-secrets-setup.md                    # GitHub secrets configuration
```

## 🚀 Quick Start

### 1. Setup GitHub Secrets

See [docs/github-secrets-setup.md](../docs/github-secrets-setup.md) for detailed instructions.

Required secrets:
- `CLIENT_ID`, `TENANT_ID`, `SUBSCRIPTION_ID` (Azure authentication)
- `HUB_SUB_ID`, `HUB_RESOURCE_GROUP`, `FIREWALL_POLICY_NAME` (deployment targets)
- `SUPERNET_ADDRESS` (spoke VNet address ranges as JSON array)

### 2. Run Deployment

**Option A: GitHub Workflow (Recommended)**
1. Go to **Actions** → **Deploy TIC 3.0 Firewall Rules**
2. Click **Run workflow**
3. Configure options and run in What-If mode first
4. Review changes, then run actual deployment

**Option B: Azure CLI**
```bash
az deployment sub create \
  --location centralus \
  --template-file ./src/deploy-firewall-rules-tic30.bicep \
  --parameters @./src/parameters/firewall-rules-tic30.parameters.json
```

### 3. Verify Deployment

```bash
# Check rule collection groups
az network firewall policy rule-collection-group list \
  --policy-name <firewall-policy-name> \
  --resource-group <hub-resource-group>

# Check firewall logs
# Navigate to Log Analytics workspace in Azure Portal
```

## 🛡️ Rule Collections

| Priority | Name | Purpose |
|----------|------|---------|
| 100 | TIC30-100-BaselineSecurity | Block malicious categories, insecure protocols |
| 200 | TIC30-200-EssentialServices | Azure services, authentication, time sync |
| 300 | TIC30-300-MicrosoftServices | M365, Windows Update, DevOps, GitHub |
| 400 | TIC30-400-WorkloadSpecific | Approved external services |
| 500 | TIC30-500-AzurePaaS | Azure SQL, Cosmos DB, AI services, AKS |

## ⚙️ Configuration

### High Security Mode (Default)
```json
{
  "enableHighSecurityMode": true,
  "enableMicrosoft365": true,
  "enableWindowsUpdate": true,
  "enableAzureDevOps": false,
  "enableGitHub": false,
  "approvedExternalFqdns": []
}
```

### Development Mode
```json
{
  "enableHighSecurityMode": false,
  "enableMicrosoft365": true,
  "enableWindowsUpdate": true,
  "enableAzureDevOps": true,
  "enableGitHub": true,
  "approvedExternalFqdns": [
    "api.dev-partner.com",
    "*.staging.example.com"
  ]
}
```

## 📊 Monitoring

After deployment, monitor:
- **Denied connections**: Check for legitimate traffic being blocked
- **IDPS alerts**: Review threat intelligence hits
- **SNAT utilization**: Monitor for capacity issues
- **Firewall health**: Ensure 100% availability

**Key KQL Query:**
```kql
AzureDiagnostics
| where Category in ("AzureFirewallApplicationRule", "AzureFirewallNetworkRule")
| where msg_s contains "Deny"
| project TimeGenerated, msg_s
| order by TimeGenerated desc
```

## 🔧 Maintenance

### Adding Approved External FQDNs

1. **Identify required FQDN** from denied connection logs
2. **Update parameters file**:
   ```json
   "approvedExternalFqdns": {
     "value": ["existing.com", "new-service.com"]
   }
   ```
3. **Redeploy** using workflow or CLI

### Updating Rules

1. **Edit** `src/modules/firewall-policy-tic30-zerotrust.bicep`
2. **Test** with What-If mode
3. **Deploy** changes
4. **Monitor** logs for impact

## 📚 Documentation

- **[Complete Deployment Guide](../docs/firewall-rules-tic30-deployment.md)**: Detailed instructions, troubleshooting, customization
- **[GitHub Secrets Setup](../docs/github-secrets-setup.md)**: Configure authentication and deployment secrets
- **[Azure Firewall Best Practices](https://learn.microsoft.com/en-us/azure/well-architected/service-guides/azure-firewall)**: Microsoft guidance
- **[TIC 3.0 Overview](https://www.cisa.gov/resources-tools/programs/trusted-internet-connections-tic)**: CISA documentation

## ✅ Compliance Checklist

- [x] TIC 3.0 access control (least-privilege rules)
- [x] TIC 3.0 threat detection (IDPS, threat intel)
- [x] TIC 3.0 encryption (HTTPS-only, TLS inspection capable)
- [x] TIC 3.0 data loss prevention (FQDN filtering)
- [x] TIC 3.0 security monitoring (diagnostic logs)
- [x] Zero Trust explicit verification (no implicit trust)
- [x] Zero Trust least-privilege (deny-by-default)
- [x] Zero Trust assume breach (segmentation)

## 🆘 Support

**Common Issues:**
- Application can't connect → Check firewall logs, add FQDN to approved list
- Rule priority conflicts → Review existing rules, adjust priorities
- SNAT exhaustion → Add public IPs, implement NAT Gateway

**Get Help:**
1. Review [deployment guide](../docs/firewall-rules-tic30-deployment.md) troubleshooting section
2. Check Azure Firewall logs in Log Analytics
3. Review Azure Firewall known issues
4. Open an issue in this repository

## 🔄 Updates

This deployment is designed to be:
- **Idempotent**: Safe to re-run multiple times
- **Non-destructive**: Adds rules without removing existing ones
- **Updateable**: Modify parameters and redeploy to adjust configuration

## 📄 License

Copyright (c) Microsoft Corporation. Licensed under the MIT License.

---

**Next Steps:**
1. ✅ Configure [GitHub secrets](../docs/github-secrets-setup.md)
2. ✅ Review [deployment guide](../docs/firewall-rules-tic30-deployment.md)
3. ✅ Run workflow in What-If mode
4. ✅ Deploy rules
5. ✅ Monitor and adjust as needed
