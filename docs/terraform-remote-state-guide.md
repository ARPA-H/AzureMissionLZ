# Terraform Remote State Setup Guide

This guide explains how to configure and use remote state management for the TIC 3.0 firewall rules Terraform deployment.

## 🎯 Why Remote State?

**Benefits:**
- ✅ **Team Collaboration**: Multiple team members can work on the same infrastructure
- ✅ **State Locking**: Prevents concurrent modifications and corruption
- ✅ **State Security**: Encrypted at rest in Azure Storage
- ✅ **State History**: Versioning and point-in-time recovery
- ✅ **CI/CD Integration**: Seamless automation workflows

**When to Use:**
- ✅ Production environments
- ✅ Team-based deployments
- ✅ Automated CI/CD pipelines
- ❌ Local testing (use local state)
- ❌ Single-user development

## 🚀 Quick Setup

### Required GitHub Secrets

Add these secrets to your GitHub repository for remote state support:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `TF_STATE_RESOURCE_GROUP` | Resource group for state storage | `rg-terraform-state` |
| `TF_STATE_STORAGE_ACCOUNT` | Storage account name (globally unique) | `sttfstatearpah` |
| `TF_STATE_CONTAINER` | Container name for state files | `tfstate` |
| `TF_STATE_LOCATION` | Azure region for storage | `centralus` |

### Automated Setup via Workflow

The GitHub Actions workflow automatically creates the storage infrastructure if it doesn't exist:

1. Navigate to **Actions** → **Deploy TIC 3.0 Firewall Rules (Terraform)**
2. Click **Run workflow**
3. Set **Use remote state** to `true` ✅
4. Click **Run workflow**

The workflow will:
- ✅ Create resource group (if needed)
- ✅ Create storage account (if needed)
- ✅ Create blob container (if needed)
- ✅ Configure backend automatically
- ✅ Initialize Terraform with remote state

## 🛠️ Manual Setup

### Option 1: Azure CLI

```bash
# Set variables
RESOURCE_GROUP="rg-terraform-state"
STORAGE_ACCOUNT="sttfstatearpah"  # Must be globally unique
CONTAINER_NAME="tfstate"
LOCATION="centralus"

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION \
  --tags "Purpose=TerraformState" "ManagedBy=Manual"

# Create storage account with security features
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2 \
  --encryption-services blob \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --https-only true

# Enable versioning for state file history
az storage account blob-service-properties update \
  --account-name $STORAGE_ACCOUNT \
  --enable-versioning true

# Create container
az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT \
  --auth-mode login

echo "✅ Remote state storage created successfully"
echo "Storage Account: $STORAGE_ACCOUNT"
echo "Container: $CONTAINER_NAME"
```

### Option 2: Azure PowerShell

```powershell
# Set variables
$ResourceGroup = "rg-terraform-state"
$StorageAccount = "sttfstatearpah"  # Must be globally unique
$ContainerName = "tfstate"
$Location = "centralus"

# Create resource group
New-AzResourceGroup `
  -Name $ResourceGroup `
  -Location $Location `
  -Tag @{"Purpose"="TerraformState"; "ManagedBy"="Manual"}

# Create storage account
$storageParams = @{
    ResourceGroupName = $ResourceGroup
    Name              = $StorageAccount
    Location          = $Location
    SkuName           = "Standard_LRS"
    Kind              = "StorageV2"
    MinimumTlsVersion = "TLS1_2"
    AllowBlobPublicAccess = $false
    EnableHttpsTrafficOnly = $true
}
New-AzStorageAccount @storageParams

# Get storage context
$ctx = (Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $StorageAccount).Context

# Enable versioning
Update-AzStorageBlobServiceProperty `
  -ResourceGroupName $ResourceGroup `
  -StorageAccountName $StorageAccount `
  -EnableVersioning $true

# Create container
New-AzStorageContainer -Name $ContainerName -Context $ctx

Write-Host "✅ Remote state storage created successfully" -ForegroundColor Green
Write-Host "Storage Account: $StorageAccount"
Write-Host "Container: $ContainerName"
```

## 📝 Local Configuration

### Configure Backend in Terraform

Create or edit `backend.tf` in `src/terraform/`:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstatearpah"
    container_name       = "tfstate"
    key                  = "firewall-rules-tic30-dev.tfstate"
    use_azuread_auth     = true
  }
}
```

### Initialize with Remote State

```bash
cd src/terraform

# Initialize (first time or after backend changes)
terraform init

# Or reconfigure if changing backends
terraform init -reconfigure

# Migrate from local to remote state
terraform init -migrate-state
```

### Environment-Specific State Files

Use different state file keys for each environment:

**Development:**
```hcl
key = "firewall-rules-tic30-dev.tfstate"
```

**Staging:**
```hcl
key = "firewall-rules-tic30-staging.tfstate"
```

**Production:**
```hcl
key = "firewall-rules-tic30-prod.tfstate"
```

## 🔐 Security Best Practices

### 1. Access Control

Grant least-privilege access to the storage account:

```bash
# Grant Storage Blob Data Contributor role to service principal
az role assignment create \
  --assignee $CLIENT_ID \
  --role "Storage Blob Data Contributor" \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT
```

### 2. Network Security

Restrict storage account access:

```bash
# Enable firewall (allow only specific IPs)
az storage account update \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --default-action Deny

# Add GitHub Actions IP ranges (if using self-hosted runners)
az storage account network-rule add \
  --account-name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --ip-address <github-runner-ip>

# Allow Azure services
az storage account update \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --bypass AzureServices
```

### 3. Encryption

State files are automatically encrypted at rest with Azure Storage Service Encryption (SSE).

For additional security, use customer-managed keys:

```bash
# Create Key Vault and key
az keyvault create \
  --name kv-tfstate \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION

az keyvault key create \
  --vault-name kv-tfstate \
  --name tfstate-encryption-key \
  --kty RSA

# Configure storage account to use customer-managed key
az storage account update \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --encryption-key-source Microsoft.Keyvault \
  --encryption-key-vault <key-vault-uri> \
  --encryption-key-name tfstate-encryption-key
```

### 4. Soft Delete and Versioning

Enable protection against accidental deletion:

```bash
# Enable soft delete for blobs
az storage account blob-service-properties update \
  --account-name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --enable-delete-retention true \
  --delete-retention-days 30

# Enable versioning
az storage account blob-service-properties update \
  --account-name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --enable-versioning true

# Enable container soft delete
az storage account blob-service-properties update \
  --account-name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --enable-container-delete-retention true \
  --container-delete-retention-days 30
```

## 🔄 State Management Operations

### View State

```bash
# List state contents
terraform state list

# Show specific resource
terraform state show azurerm_ip_group.spokes

# Pull state locally (for inspection)
terraform state pull > current-state.json
```

### State Locking

Azure Storage automatically provides state locking using blob leases.

**Check for locks:**
```bash
az storage blob lease list \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER_NAME \
  --blob-name firewall-rules-tic30-dev.tfstate
```

**Break lock (use carefully!):**
```bash
# Via Terraform
terraform force-unlock <lock-id>

# Via Azure CLI
az storage blob lease break \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER_NAME \
  --blob-name firewall-rules-tic30-dev.tfstate
```

### State Recovery

Restore from a previous version:

```bash
# List blob versions
az storage blob list \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER_NAME \
  --prefix firewall-rules-tic30 \
  --include v

# Download specific version
az storage blob download \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER_NAME \
  --name firewall-rules-tic30-dev.tfstate \
  --version-id <version-id> \
  --file terraform.tfstate.backup

# Restore (carefully!)
az storage blob upload \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER_NAME \
  --name firewall-rules-tic30-dev.tfstate \
  --file terraform.tfstate.backup \
  --overwrite
```

## 🔀 Migration Scenarios

### Migrate from Local to Remote State

```bash
cd src/terraform

# Create backend.tf with remote configuration
cat > backend.tf <<EOF
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstatearpah"
    container_name       = "tfstate"
    key                  = "firewall-rules-tic30-dev.tfstate"
    use_azuread_auth     = true
  }
}
EOF

# Reinitialize and migrate
terraform init -migrate-state

# Verify migration
terraform state list
```

### Migrate from Remote to Local State

```bash
cd src/terraform

# Remove backend.tf
rm backend.tf

# Reinitialize with local backend
terraform init -migrate-state

# State will be stored in terraform.tfstate locally
```

### Change Storage Account

```bash
# Update backend.tf with new storage account
nano backend.tf

# Reconfigure backend
terraform init -reconfigure -migrate-state
```

## 🧪 Testing Remote State

### Verify Configuration

```bash
cd src/terraform

# Initialize
terraform init

# Verify backend configuration
terraform version
terraform providers

# Check state location
az storage blob list \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER_NAME \
  --output table
```

### Test State Locking

In one terminal:
```bash
terraform apply
# Keep running...
```

In another terminal:
```bash
terraform plan
# Should show: "Error acquiring the state lock"
```

## 🆘 Troubleshooting

### Issue: "Failed to get existing workspaces"

**Cause:** Missing permissions on storage account

**Solution:**
```bash
az role assignment create \
  --assignee $CLIENT_ID \
  --role "Storage Blob Data Contributor" \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT
```

### Issue: "Error acquiring state lock"

**Cause:** Another process is holding the lock or stale lock

**Solution:**
```bash
# Wait for other process to finish, or force unlock
terraform force-unlock <lock-id>
```

### Issue: "Storage account does not exist"

**Cause:** Backend configuration references non-existent storage

**Solution:**
```bash
# Verify storage account exists
az storage account show \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP

# Create if needed (see Manual Setup section)
```

### Issue: "Blob not found" during init

**Cause:** First time initialization (normal behavior)

**Solution:**
```
# This is normal for first initialization
terraform init
# Terraform will create the state file automatically
```

## 📊 Monitoring and Compliance

### Storage Metrics

Monitor state file access:

```bash
# Enable diagnostic logs
az monitor diagnostic-settings create \
  --resource /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT \
  --name storage-diagnostics \
  --logs '[{"category":"StorageRead","enabled":true},{"category":"StorageWrite","enabled":true}]' \
  --metrics '[{"category":"Transaction","enabled":true}]' \
  --workspace <log-analytics-workspace-id>
```

### Compliance Checks

Verify security settings:

```bash
# Check encryption
az storage account show \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --query encryption

# Check public access
az storage account show \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --query allowBlobPublicAccess

# Check TLS version
az storage account show \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --query minimumTlsVersion
```

## 📚 Additional Resources

- [Terraform Azure Backend Documentation](https://www.terraform.io/language/settings/backends/azurerm)
- [Azure Storage Security](https://learn.microsoft.com/azure/storage/common/storage-security-guide)
- [Terraform State Management](https://www.terraform.io/language/state)
- [Azure Storage Versioning](https://learn.microsoft.com/azure/storage/blobs/versioning-overview)

## 📄 Quick Reference

### GitHub Workflow Usage

**With Remote State (Recommended):**
```
Actions → Deploy TIC 3.0 Firewall Rules (Terraform)
→ Use remote state: true ✅
→ Run workflow
```

**With Local State:**
```
Actions → Deploy TIC 3.0 Firewall Rules (Terraform)
→ Use remote state: false
→ Run workflow
```

### Environment Variables

For local development, export these:

```bash
export ARM_CLIENT_ID="<client-id>"
export ARM_SUBSCRIPTION_ID="<subscription-id>"
export ARM_TENANT_ID="<tenant-id>"
export ARM_USE_AZUREAD=true
```

### State File Naming Convention

```
firewall-rules-tic30-{environment}.tfstate

Examples:
- firewall-rules-tic30-dev.tfstate
- firewall-rules-tic30-staging.tfstate
- firewall-rules-tic30-prod.tfstate
```

---

**Next Steps:**
1. ✅ Set up GitHub secrets for remote state
2. ✅ Run workflow with "Use remote state" enabled
3. ✅ Verify state file in Azure Storage
4. ✅ Configure RBAC and security settings
5. ✅ Enable monitoring and alerts
