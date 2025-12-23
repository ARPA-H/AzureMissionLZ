# Terraform Deployment Guide - TIC 3.0 Firewall Rules

Complete guide for deploying TIC 3.0 and Zero Trust compliant firewall rules using Terraform.

## 📋 Overview

This guide covers deploying Azure Firewall rules using Terraform as an alternative to the Bicep deployment. Both deployment methods achieve the same result - you can choose based on your organization's tooling preference.

### Terraform vs Bicep

| Feature | Terraform | Bicep |
|---------|-----------|-------|
| **Language** | HCL (HashiCorp) | Domain-specific for Azure |
| **Multi-cloud** | ✅ Yes | ❌ Azure only |
| **State Management** | Required | Azure-managed |
| **Learning Curve** | Moderate | Easy for Azure users |
| **Community** | Large, multi-cloud | Azure-focused |
| **Tool Maturity** | Very mature | Growing rapidly |

## 🚀 Quick Start

### Prerequisites

1. **Install Terraform**
   
   **Windows (with Chocolatey):**
   ```powershell
   choco install terraform
   ```
   
   **macOS (with Homebrew):**
   ```bash
   brew install terraform
   ```
   
   **Linux:**
   ```bash
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```

2. **Verify Installation**
   ```bash
   terraform version
   # Should show: Terraform v1.6.0 or later
   ```

3. **Azure CLI**
   ```bash
   az login
   az account set --subscription <subscription-id>
   ```

### Step-by-Step Deployment

#### 1. Navigate to Terraform Directory

```bash
cd src/terraform
```

#### 2. Configure Variables

```bash
# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars  # or use your preferred editor
```

**Required Configuration:**
```hcl
hub_subscription_id     = "12345678-1234-1234-1234-123456789abc"
hub_resource_group_name = "rg-mlz-hub-dev"
firewall_policy_name    = "afwp-mlz-hub-dev"

spoke_vnet_addresses = [
  "10.0.100.0/24",
  "10.0.110.0/24",
  "10.0.120.0/24"
]
```

#### 3. Initialize Terraform

```bash
terraform init
```

Expected output:
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/azurerm versions matching "~> 3.85"...
- Installing hashicorp/azurerm v3.85.0...
Terraform has been successfully initialized!
```

#### 4. Review Planned Changes

```bash
terraform plan -out=tfplan
```

Review the output carefully. You should see:
- ✅ 1 IP Group to be created
- ✅ 5 Rule Collection Groups to be created
- ✅ 0 resources to be destroyed

#### 5. Apply Configuration

```bash
terraform apply tfplan
```

Enter `yes` when prompted. Deployment typically takes 2-5 minutes.

#### 6. Verify Deployment

```bash
# View outputs
terraform output

# Check specific values
terraform output firewall_policy_id
terraform output configuration_summary
```

## 🔧 Configuration Options

### Security Modes

**High Security Mode (Default)**
```hcl
enable_high_security_mode = true
enable_microsoft_365      = true
enable_windows_update     = true
enable_azure_devops       = false
enable_github             = false
approved_external_fqdns   = []
```

**Development Mode**
```hcl
enable_high_security_mode = false
enable_microsoft_365      = true
enable_windows_update     = true
enable_azure_devops       = true
enable_github             = true
approved_external_fqdns   = [
  "api.dev-partner.com",
  "*.staging.example.com"
]
```

### Adding Approved External FQDNs

Edit `terraform.tfvars`:
```hcl
approved_external_fqdns = [
  "api.partner.gov",
  "*.approved-vendor.com",
  "data.research-org.edu"
]
```

Apply changes:
```bash
terraform plan
terraform apply
```

## 🎯 GitHub Actions Workflow

### Setup

The workflow is pre-configured at `.github/workflows/deploy-firewall-rules-terraform.yml`.

**Required GitHub Secrets:**
- `CLIENT_ID`
- `TENANT_ID`
- `SUBSCRIPTION_ID`
- `HUB_SUB_ID`
- `HUB_RESOURCE_GROUP`
- `FIREWALL_POLICY_NAME`
- `SUPERNET_ADDRESS` (JSON array format)

### Running the Workflow

1. **Navigate to Actions**
   - Go to your GitHub repository
   - Click **Actions** tab
   - Select **Deploy TIC 3.0 Firewall Rules (Terraform)**

2. **Run Workflow**
   - Click **Run workflow**
   - Select environment (development/staging/production)
   - Choose action:
     - **plan**: Preview changes only
     - **apply**: Deploy changes
     - **destroy**: Remove all rules
   - Configure feature flags
   - Click **Run workflow**

3. **Monitor Progress**
   - Watch workflow execution
   - Review Terraform plan output
   - Check deployment summary

## 📊 State Management

### Local State (Default)

Terraform stores state locally in `terraform.tfstate`. This works for:
- ✅ Single-user deployments
- ✅ Testing and development
- ❌ Team collaboration (not recommended)
- ❌ Production environments (not recommended)

### Remote State (Recommended for Teams)

#### Setup Azure Storage Backend

```bash
# Create resource group
az group create \
  --name rg-terraform-state \
  --location centralus

# Create storage account
az storage account create \
  --name sttfstatearpah \
  --resource-group rg-terraform-state \
  --location centralus \
  --sku Standard_LRS \
  --encryption-services blob \
  --min-tls-version TLS1_2

# Create container
az storage container create \
  --name tfstate \
  --account-name sttfstatearpah
```

#### Configure Backend

Create `backend.tf`:
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstatearpah"
    container_name       = "tfstate"
    key                  = "firewall-rules-tic30.tfstate"
  }
}
```

Migrate state:
```bash
terraform init -migrate-state
```

## 🔄 Updating and Maintenance

### Update Firewall Rules

1. **Modify Configuration**
   ```bash
   nano terraform.tfvars
   ```

2. **Plan Changes**
   ```bash
   terraform plan
   ```

3. **Review and Apply**
   ```bash
   terraform apply
   ```

### Add New Rule Collection

1. **Edit `main.tf`**
   Add new `azurerm_firewall_policy_rule_collection_group` resource

2. **Validate**
   ```bash
   terraform validate
   terraform fmt
   ```

3. **Deploy**
   ```bash
   terraform plan
   terraform apply
   ```

### Import Existing Resources

If rules were manually created:
```bash
terraform import \
  azurerm_firewall_policy_rule_collection_group.baseline_security \
  /subscriptions/{subscription-id}/resourceGroups/{rg}/providers/Microsoft.Network/firewallPolicies/{policy}/ruleCollectionGroups/{name}
```

## 🧪 Testing and Validation

### Syntax Validation

```bash
# Check syntax
terraform validate

# Format code
terraform fmt -recursive

# Check formatting
terraform fmt -check
```

### Security Scanning

```bash
# Install tfsec
brew install tfsec  # macOS
choco install tfsec # Windows

# Run security scan
tfsec .
```

### Policy Compliance

```bash
# Install Checkov
pip install checkov

# Run compliance scan
checkov -d .
```

### Drift Detection

```bash
# Check for configuration drift
terraform plan -detailed-exitcode

# Exit codes:
# 0 = No changes
# 1 = Error
# 2 = Successful plan with changes (drift detected)
```

## 🗑️ Rollback and Cleanup

### Rollback to Previous State

```bash
# List state versions (if using remote state)
terraform state list

# Show specific resource
terraform state show azurerm_ip_group.spokes

# Remove resource from state (doesn't delete actual resource)
terraform state rm azurerm_firewall_policy_rule_collection_group.workload_specific
```

### Selective Destruction

```bash
# Destroy specific resource
terraform destroy -target=azurerm_firewall_policy_rule_collection_group.workload_specific
```

### Complete Cleanup

```bash
# Plan destruction
terraform plan -destroy -out=destroy.tfplan

# Review
terraform show destroy.tfplan

# Execute
terraform apply destroy.tfplan

# Or use destroy directly
terraform destroy
```

## 📈 Monitoring Deployments

### View Current State

```bash
# Show all resources
terraform show

# List resources
terraform state list

# Show outputs
terraform output -json | jq .
```

### Refresh State

```bash
# Update state from actual infrastructure
terraform refresh

# Plan with refreshed state
terraform plan -refresh-only
```

### Generate Dependency Graph

```bash
# Install graphviz
brew install graphviz  # macOS
choco install graphviz # Windows

# Generate graph
terraform graph | dot -Tsvg > graph.svg

# Open in browser
open graph.svg  # macOS
start graph.svg # Windows
```

## 🔐 Security Best Practices

### Secure Variables

**Use Environment Variables:**
```bash
export TF_VAR_hub_subscription_id="12345678-..."
export TF_VAR_firewall_policy_name="afwp-mlz-hub-dev"
terraform plan
```

**Use Azure Key Vault:**
```bash
# Retrieve from Key Vault
az keyvault secret show \
  --vault-name kv-terraform \
  --name hub-subscription-id \
  --query value -o tsv
```

### State Encryption

Azure Storage backend automatically encrypts state at rest. For additional security:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstatearpah"
    container_name       = "tfstate"
    key                  = "firewall-rules-tic30.tfstate"
    
    # Enable additional features
    use_azuread_auth = true
  }
}
```

### Workspace Isolation

```bash
# Create production workspace
terraform workspace new production

# Create staging workspace
terraform workspace new staging

# List workspaces
terraform workspace list

# Switch workspace
terraform workspace select production
```

## 🆘 Troubleshooting

### Common Errors

#### Error: Insufficient Permissions

```
Error: authorization.RoleAssignmentCreateFailed
```

**Solution:**
```bash
# Check current permissions
az role assignment list --assignee <user-id> --output table

# Assign required role
az role assignment create \
  --assignee <user-id> \
  --role "Network Contributor" \
  --scope /subscriptions/<sub-id>/resourceGroups/<rg-name>
```

#### Error: Resource Already Exists

```
Error: A resource with the ID "/subscriptions/.../ipGroups/ipg-zerotrust-spokes" already exists
```

**Solution:**
```bash
# Import existing resource
terraform import azurerm_ip_group.spokes <resource-id>

# Or remove from Azure
az network ip-group delete --name ipg-zerotrust-spokes --resource-group <rg>
```

#### Error: State Lock

```
Error: Error acquiring the state lock
```

**Solution:**
```bash
# List locks (Azure Storage backend)
az storage blob lease list \
  --account-name sttfstatearpah \
  --container-name tfstate

# Force unlock (use carefully!)
terraform force-unlock <lock-id>
```

#### Error: Provider Version Conflict

```
Error: Failed to query available provider packages
```

**Solution:**
```bash
# Upgrade providers
terraform init -upgrade

# Or specify exact version in main.tf
required_providers {
  azurerm = {
    source  = "hashicorp/azurerm"
    version = "= 3.85.0"
  }
}
```

## 📚 Additional Resources

### Terraform Documentation
- [Terraform CLI Commands](https://www.terraform.io/cli/commands)
- [AzureRM Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

### Azure Resources
- [Azure Firewall Policy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall_policy)
- [Azure Firewall Policy Rule Collection Group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall_policy_rule_collection_group)
- [Azure IP Group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/ip_group)

### TIC 3.0 and Zero Trust
- [CISA TIC 3.0](https://www.cisa.gov/resources-tools/programs/trusted-internet-connections-tic)
- [Microsoft Zero Trust](https://www.microsoft.com/security/business/zero-trust)
- [Azure Well-Architected Framework](https://learn.microsoft.com/azure/architecture/framework/)

## 🔄 Bicep to Terraform Comparison

### Resource Mapping

| Bicep | Terraform |
|-------|-----------|
| `resource ... existing` | `data "azurerm_..."` |
| `resource ... =` | `resource "azurerm_..." ` |
| `param` | `variable` |
| `output` | `output` |
| `module` | `module` |

### Example Comparison

**Bicep:**
```bicep
resource spokesIpGroup 'Microsoft.Network/ipGroups@2023-11-01' = {
  name: 'ipg-zerotrust-spokes'
  location: resourceGroup().location
  properties: {
    ipAddresses: spokeVnetAddresses
  }
}
```

**Terraform:**
```hcl
resource "azurerm_ip_group" "spokes" {
  name                = "ipg-zerotrust-spokes"
  location            = data.azurerm_resource_group.hub.location
  resource_group_name = var.hub_resource_group_name
  cidrs               = var.spoke_vnet_addresses
}
```

## 📄 License

Copyright (c) Microsoft Corporation. Licensed under the MIT License.
