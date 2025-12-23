/*
Copyright (c) Microsoft Corporation.
Licensed under the MIT License.

TIC 3.0 Firewall Rules - Terraform Outputs
*/

output "firewall_policy_id" {
  description = "The resource ID of the Firewall Policy that was updated"
  value       = data.azurerm_firewall_policy.existing.id
}

output "firewall_policy_name" {
  description = "The name of the Firewall Policy"
  value       = data.azurerm_firewall_policy.existing.name
}

output "spokes_ip_group_id" {
  description = "The resource ID of the spokes IP Group created"
  value       = azurerm_ip_group.spokes.id
}

output "spokes_ip_group_name" {
  description = "The name of the spokes IP Group"
  value       = azurerm_ip_group.spokes.name
}

output "rule_collection_groups_created" {
  description = "List of rule collection groups that were created"
  value = [
    "TIC30-100-BaselineSecurity",
    "TIC30-200-EssentialServices",
    "TIC30-300-MicrosoftServices",
    (!var.enable_high_security_mode || length(var.approved_external_fqdns) > 0) ? "TIC30-400-WorkloadSpecific" : "",
    "TIC30-500-AzurePaaS"
  ]
}

output "configuration_summary" {
  description = "Configuration summary"
  value = {
    tic30_compliance         = true
    zero_trust_enabled       = true
    high_security_mode       = var.enable_high_security_mode
    microsoft_365_enabled    = var.enable_microsoft_365
    windows_update_enabled   = var.enable_windows_update
    azure_devops_enabled     = var.enable_azure_devops
    github_enabled           = var.enable_github
    spoke_networks_configured = length(var.spoke_vnet_addresses)
    approved_external_fqdns_count = length(var.approved_external_fqdns)
  }
}
