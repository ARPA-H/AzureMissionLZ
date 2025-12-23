# TIC 3.0 Firewall Rules - Terraform Deployment

This Terraform configuration deploys TIC 3.0 and Zero Trust compliant firewall rules to your Azure Mission Landing Zone.

## 📋 Prerequisites

1. **Terraform**: Version 1.6.0 or later
   ```bash
   terraform version
   ```

2. **Azure CLI**: Authenticated to your Azure environment
   ```bash
   az login
   az account show
   ```

3. **Existing MLZ Deployment**: Azure Firewall and Firewall Policy must already exist

4. **Permissions**: Contributor or Owner role on the Hub subscription

## 🚀 Quick Start

### 1. Configure Variables

```bash
# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
code terraform.tfvars
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Plan Deployment

```bash
terraform plan -out=tfplan
```

### 4. Review and Apply

```bash
# Review the plan
terraform show tfplan

# Apply changes
terraform apply tfplan
```

## 📁 Files

- **main.tf**: Main Terraform configuration with all firewall rules
- **variables.tf**: Input variable definitions
- **outputs.tf**: Output values after deployment
- **terraform.tfvars.example**: Example configuration
- **backend.tf.example**: Remote state configuration (optional)

## ⚙️ Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `hub_subscription_id` | Hub subscription ID | `"12345678-..."` |
| `hub_resource_group_name` | Hub resource group | `"rg-mlz-hub-dev"` |
| `firewall_policy_name` | Firewall policy name | `"afwp-mlz-hub-dev"` |
| `spoke_vnet_addresses` | Spoke VNet CIDR ranges | `["10.0.100.0/24"]` |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `enable_high_security_mode` | `true` | Enable stricter security |
| `enable_microsoft_365` | `true` | Allow M365 services |
| `enable_windows_update` | `true` | Allow Windows Update |
| `enable_azure_devops` | `false` | Allow Azure DevOps |
| `enable_github` | `false` | Allow GitHub |
| `approved_external_fqdns` | `[]` | Custom approved FQDNs |

## 🛡️ What Gets Deployed

### Rule Collection Groups (Priority Order)

1. **TIC30-100-BaselineSecurity** (Priority 100)
   - Blocks malicious web categories
   - Blocks insecure protocols (FTP, Telnet, etc.)

2. **TIC30-200-EssentialServices** (Priority 200)
   - Azure Monitor, Storage, Key Vault, Backup
   - Azure AD authentication
   - NTP time services

3. **TIC30-300-MicrosoftServices** (Priority 300)
   - Microsoft 365 (conditional)
   - Windows Update (conditional)
   - Azure DevOps (conditional)
   - GitHub (conditional)

4. **TIC30-400-WorkloadSpecific** (Priority 400)
   - Approved external FQDNs

5. **TIC30-500-AzurePaaS** (Priority 500)
   - Azure SQL, Cosmos DB
   - Azure OpenAI, Cognitive Services
   - Container Registry, AKS

## 📊 Outputs

After successful deployment:

```bash
# View all outputs
terraform output

# View specific output
terraform output firewall_policy_id
terraform output configuration_summary
```

## 🔧 Advanced Usage

### Remote State Configuration

Configure remote state for team collaboration:

```bash
# Copy example
cp backend.tf.example backend.tf

# Edit with your storage account details
code backend.tf

# Reinitialize with backend
terraform init -migrate-state
```

### Workspaces

Use workspaces for multiple environments:

```bash
# Create workspace
terraform workspace new production

# Switch workspace
terraform workspace select production

# List workspaces
terraform workspace list
```

### Variable Files

Use different variable files per environment:

```bash
# Development
terraform plan -var-file="dev.tfvars"

# Production
terraform plan -var-file="prod.tfvars"
```

## 🧪 Testing

### Validate Configuration

```bash
terraform validate
```

### Format Code

```bash
terraform fmt -recursive
```

### Plan with Detailed Output

```bash
terraform plan -out=tfplan
terraform show -json tfplan | jq . > plan.json
```

## 🔄 Updating Rules

### Adding Custom FQDNs

1. Edit `terraform.tfvars`:
   ```hcl
   approved_external_fqdns = [
     "api.partner.com",
     "*.vendor.gov"
   ]
   ```

2. Apply changes:
   ```bash
   terraform plan
   terraform apply
   ```

### Enabling Additional Services

1. Update variables:
   ```hcl
   enable_azure_devops = true
   enable_github       = true
   ```

2. Apply:
   ```bash
   terraform apply
   ```

## 🗑️ Cleanup

### Remove All Rules

```bash
# Plan destruction
terraform plan -destroy

# Destroy resources
terraform destroy
```

### Remove Specific Rule Collection Group

Use Terraform's `-target` flag:

```bash
terraform destroy -target=azurerm_firewall_policy_rule_collection_group.workload_specific
```

## 📈 Monitoring

### Check Deployment State

```bash
# Show current state
terraform show

# List resources
terraform state list

# Show specific resource
terraform state show azurerm_ip_group.spokes
```

### Drift Detection

```bash
# Check for configuration drift
terraform plan -detailed-exitcode
```

## 🔐 Security Best Practices

1. **Use Remote State**: Store state in Azure Storage with encryption
2. **Enable State Locking**: Prevent concurrent modifications
3. **Secure Variables**: Use Azure Key Vault for sensitive values
4. **Review Plans**: Always review `terraform plan` before applying
5. **Use Workspaces**: Separate environments (dev/staging/prod)

## 🆘 Troubleshooting

### Common Issues

**Issue: Authentication failed**
```bash
# Re-authenticate
az logout
az login
az account set --subscription <subscription-id>
```

**Issue: Resource already exists**
```bash
# Import existing resource
terraform import azurerm_ip_group.spokes /subscriptions/.../ipGroups/ipg-zerotrust-spokes
```

**Issue: State lock**
```bash
# Force unlock (use carefully!)
terraform force-unlock <lock-id>
```

**Issue: Version conflicts**
```bash
# Upgrade providers
terraform init -upgrade
```

## 📚 Additional Resources

- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Firewall Policy Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall_policy)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [TIC 3.0 Guidance](https://www.cisa.gov/resources-tools/programs/trusted-internet-connections-tic)

## 🔄 Migration from Bicep

If migrating from Bicep deployment:

1. **Import existing resources**:
   ```bash
   terraform import azurerm_ip_group.spokes <resource-id>
   terraform import azurerm_firewall_policy_rule_collection_group.baseline_security <resource-id>
   ```

2. **Run plan to verify**:
   ```bash
   terraform plan
   ```

3. **Continue with Terraform**

## 📄 License

Copyright (c) Microsoft Corporation. Licensed under the MIT License.
