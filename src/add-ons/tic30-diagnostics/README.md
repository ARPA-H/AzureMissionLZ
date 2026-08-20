# TIC 3.0 Diagnostics Add-On

This add-on deploys the Event Hub namespace and event hubs used as TIC 3.0 boundary streaming targets for Mission Landing Zone (MLZ). It is implemented in Terraform (rather than Bicep, like the rest of this repo) and is deployed independently of the core MLZ Bicep templates.

Diagnostic settings that point Azure Firewall and Entra ID logs at these event hubs are configured manually and are out of scope for this Terraform configuration.

## What this add-on deploys

- An `azurerm_eventhub_namespace` named using [Azure/naming/azurerm](https://registry.terraform.io/modules/Azure/naming/azurerm/latest)
- Two `azurerm_eventhub` resources under that namespace:
  - `<eventhub-name>-firewall-logs`
  - `<eventhub-name>-entra-id-logs`

## Prerequisites

1. An existing MLZ deployment with a resource group to host the Event Hub namespace (e.g. the hub or operations resource group).
2. An Azure Storage Account and container to use as the Terraform `azurerm` remote state backend.
3. A service principal or Entra ID app registration federated for GitHub Actions OIDC login, with `Contributor` on the target resource group.

## Usage

```bash
cd src/add-ons/tic30-diagnostics/terraform

terraform init \
  -backend-config="resource_group_name=<state-rg>" \
  -backend-config="storage_account_name=<state-sa>" \
  -backend-config="container_name=<state-container>" \
  -backend-config="key=tic30-diagnostics.tfstate"

terraform plan \
  -var="location=eastus" \
  -var="resource_group_name=mlz-rg-hub" \
  -var="naming_prefix=[\"mlz\"]"

terraform apply
```

## Inputs

Name | Description | Default
---- | ----------- | -------
`location` | Azure region for the Event Hub namespace | (required)
`resource_group_name` | Existing MLZ resource group to host the namespace | (required)
`naming_prefix` | Prefix segments for the naming module | `[]`
`naming_suffix` | Suffix segments for the naming module | `["operations", "tic30", "usc"]`
`eventhub_namespace_sku` | Event Hub namespace SKU | `Standard`
`eventhub_namespace_capacity` | Namespace throughput units | `1`
`eventhub_partition_count` | Partition count per event hub | `2`
`eventhub_message_retention` | Message retention in days per event hub | `7`
`tags` | Tags applied to created resources | `{}`

## Outputs

Name | Description
---- | -----------
`eventhub_namespace_id` | Resource ID of the Event Hub namespace
`eventhub_namespace_name` | Name of the Event Hub namespace
`firewall_logs_eventhub_name` | Name of the firewall logs event hub
`entra_id_logs_eventhub_name` | Name of the Entra ID logs event hub
`diagnostic_settings_authorization_rule_id` | Resource ID of the send-only authorization rule for diagnostic settings
`diagnostic_settings_authorization_rule_name` | Name of the send-only authorization rule for diagnostic settings

After apply, manually configure diagnostic settings on Azure Firewall and the Entra ID tenant to stream to `firewall_logs_eventhub_name` and `entra_id_logs_eventhub_name` respectively, using `diagnostic_settings_authorization_rule_name`.
