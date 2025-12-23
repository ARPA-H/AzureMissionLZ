# GitHub Secrets Configuration for TIC 3.0 Firewall Rules Deployment

This guide helps you configure the required GitHub secrets for the automated firewall rules deployment workflow.

## 📋 Required Secrets

### Authentication Secrets

| Secret Name | Description | Example Value |
|------------|-------------|---------------|
| `CLIENT_ID` | Azure Service Principal (App Registration) Client ID | `12345678-1234-1234-1234-123456789abc` |
| `TENANT_ID` | Azure AD Tenant ID | `87654321-4321-4321-4321-cba987654321` |
| `SUBSCRIPTION_ID` | Azure Subscription ID for authentication | `abcdef12-3456-7890-abcd-ef1234567890` |

### Deployment Secrets

| Secret Name | Description | Example Value |
|------------|-------------|---------------|
| `HUB_SUB_ID` | Hub subscription ID where firewall exists | `abcdef12-3456-7890-abcd-ef1234567890` |
| `HUB_RESOURCE_GROUP` | Resource group name containing the firewall policy | `rg-mlz-hub-dev` |
| `FIREWALL_POLICY_NAME` | Name of the existing Azure Firewall Policy | `afwp-mlz-hub-dev` |
| `SUPERNET_ADDRESS` | JSON array of spoke VNet CIDR ranges | `["10.0.100.0/24","10.0.110.0/24"]` |

## 🔧 Setup Instructions

### Step 1: Create Azure Service Principal (if not exists)

```bash
# Login to Azure
az login

# Create service principal with Contributor role
az ad sp create-for-rbac \
  --name "sp-mlz-firewall-deployment" \
  --role Contributor \
  --scopes /subscriptions/<subscription-id> \
  --sdk-auth

# Output will include:
# {
#   "clientId": "...",
#   "clientSecret": "...",
#   "subscriptionId": "...",
#   "tenantId": "...",
#   ...
# }
```

**Save the output values** for CLIENT_ID, TENANT_ID, and SUBSCRIPTION_ID.

### Step 2: Configure OIDC Federation (Recommended for passwordless)

```bash
# Get your GitHub repo details
GITHUB_ORG="your-org"
GITHUB_REPO="missionlz"
APP_ID="<your-app-id-from-step-1>"

# Add federated credential
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-actions-oidc",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"$GITHUB_ORG"'/'"$GITHUB_REPO"':ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### Step 3: Get Resource Information

```bash
# Get Hub Subscription ID
az account show --query id -o tsv

# Get Hub Resource Group Name
az group list --query "[?contains(name, 'hub')].name" -o table

# Get Firewall Policy Name
az network firewall policy list \
  --resource-group <hub-rg-name> \
  --query "[].name" -o table

# Get Spoke VNet Address Ranges
az network vnet list \
  --query "[?contains(name, 'spoke')].addressSpace.addressPrefixes" -o json
```

### Step 4: Add Secrets to GitHub Repository

1. **Navigate to your GitHub repository**
2. **Go to**: Settings → Secrets and variables → Actions
3. **Click**: "New repository secret"
4. **Add each secret**:

   ```
   CLIENT_ID = <from-step-1>
   TENANT_ID = <from-step-1>
   SUBSCRIPTION_ID = <from-step-1>
   HUB_SUB_ID = <from-step-3>
   HUB_RESOURCE_GROUP = <from-step-3>
   FIREWALL_POLICY_NAME = <from-step-3>
   SUPERNET_ADDRESS = <from-step-3-formatted-as-json-array>
   ```

### Step 5: Format SUPERNET_ADDRESS Correctly

The `SUPERNET_ADDRESS` secret must be a JSON array of strings:

**✅ Correct Format:**
```json
["10.0.100.0/24","10.0.110.0/24","10.0.120.0/24","10.0.130.0/24"]
```

**❌ Incorrect Format:**
```
10.0.100.0/24,10.0.110.0/24
```

**PowerShell to get spoke addresses:**
```powershell
$spokes = @("10.0.100.0/24", "10.0.110.0/24", "10.0.120.0/24")
$json = $spokes | ConvertTo-Json -Compress
Write-Output $json
```

**Bash to get spoke addresses:**
```bash
# From Azure CLI output
az network vnet list \
  --resource-group <rg-name> \
  --query "[?contains(name, 'spoke')].addressSpace.addressPrefixes[]" \
  -o json \
  --output tsv | jq -Rs 'split("\n") | map(select(length > 0))'
```

## ✅ Verification

### Test Secret Configuration

```bash
# In GitHub Actions, secrets are accessed as:
${{ secrets.CLIENT_ID }}
${{ secrets.HUB_SUB_ID }}
# etc.
```

### Validate Service Principal Permissions

```bash
# Login as service principal
az login --service-principal \
  --username <CLIENT_ID> \
  --password <CLIENT_SECRET> \
  --tenant <TENANT_ID>

# Check access to firewall policy
az network firewall policy show \
  --name <FIREWALL_POLICY_NAME> \
  --resource-group <HUB_RESOURCE_GROUP>

# Expected: Policy details displayed (not access denied error)
```

## 🔐 Security Best Practices

### Service Principal Permissions

**Principle of Least Privilege:**
- Grant only required permissions
- Scope to specific resource group if possible
- Use OIDC federation instead of client secrets

**Recommended Role Assignment:**
```bash
# Scope to Hub resource group only
az role assignment create \
  --assignee <CLIENT_ID> \
  --role "Network Contributor" \
  --scope /subscriptions/<HUB_SUB_ID>/resourceGroups/<HUB_RESOURCE_GROUP>
```

### Secret Rotation

**For Client Secret Method:**
- Rotate service principal secrets every 90 days
- Update GitHub secrets after rotation

**For OIDC Federation (Recommended):**
- No secrets to rotate
- More secure, passwordless authentication

### Audit

```bash
# View service principal activity
az monitor activity-log list \
  --caller <CLIENT_ID> \
  --start-time 2024-01-01 \
  --query "[].{Time:eventTimestamp, Operation:operationName.value, Status:status.value}"
```

## 🧪 Test the Workflow

### Manual Workflow Trigger

1. Go to **Actions** → **Deploy TIC 3.0 Firewall Rules**
2. Click **Run workflow**
3. Select:
   - Environment: `development`
   - What-If Only: `true`
4. Click **Run workflow**
5. Check run logs for any secret-related errors

### Common Errors

**Error: "No subscription found"**
- Solution: Verify `HUB_SUB_ID` is correct
- Check service principal has access to subscription

**Error: "Resource group not found"**
- Solution: Verify `HUB_RESOURCE_GROUP` name is exact
- Check it exists: `az group show --name <name>`

**Error: "Firewall policy not found"**
- Solution: Verify `FIREWALL_POLICY_NAME` is correct
- Check it exists in the resource group

**Error: "Invalid JSON"**
- Solution: Verify `SUPERNET_ADDRESS` is properly formatted JSON array
- Use online JSON validator

## 📋 Secrets Checklist

Before running the workflow, verify:

- [ ] `CLIENT_ID` is set
- [ ] `TENANT_ID` is set
- [ ] `SUBSCRIPTION_ID` is set
- [ ] `HUB_SUB_ID` is set
- [ ] `HUB_RESOURCE_GROUP` is set
- [ ] `FIREWALL_POLICY_NAME` is set
- [ ] `SUPERNET_ADDRESS` is set and valid JSON
- [ ] Service principal has Network Contributor or Contributor role
- [ ] OIDC federation configured (if using passwordless auth)
- [ ] Tested workflow with What-If mode

## 🆘 Troubleshooting

### Secret Not Available in Workflow

**Symptom:** Workflow fails with "secret not found"

**Solution:**
1. Verify secret name matches exactly (case-sensitive)
2. Check secret is at repository level (not environment level)
3. Verify workflow has permissions to access secrets

### Authentication Failures

**Symptom:** "Failed to authenticate" errors

**Solution:**
1. Verify CLIENT_ID, TENANT_ID, SUBSCRIPTION_ID are correct
2. Check service principal is not disabled/expired
3. Verify federated credential settings if using OIDC
4. Test authentication manually with Azure CLI

## 📚 Additional Resources

- [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Azure OIDC for GitHub Actions](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure)
- [Azure Service Principals](https://learn.microsoft.com/en-us/azure/active-directory/develop/app-objects-and-service-principals)
- [Azure RBAC Best Practices](https://learn.microsoft.com/en-us/azure/role-based-access-control/best-practices)
