/*
Copyright (c) Microsoft Corporation.
Licensed under the MIT License.

TIC 3.0 Firewall Rules - Terraform Variables
*/

variable "hub_subscription_id" {
  description = "The subscription ID where the Hub resources exist"
  type        = string
}

variable "hub_resource_group_name" {
  description = "The resource group containing the Firewall Policy"
  type        = string
}

variable "firewall_policy_name" {
  description = "The name of the existing Firewall Policy"
  type        = string
}

variable "spoke_vnet_addresses" {
  description = "Array of spoke VNet CIDR ranges for Zero Trust segmentation"
  type        = list(string)
  
  validation {
    condition     = length(var.spoke_vnet_addresses) > 0
    error_message = "At least one spoke VNet address range must be provided."
  }
}

variable "enable_high_security_mode" {
  description = "Enable TIC 3.0 high-security mode (more restrictive rules)"
  type        = bool
  default     = true
}

variable "enable_microsoft_365" {
  description = "Enable Microsoft 365 access"
  type        = bool
  default     = true
}

variable "enable_windows_update" {
  description = "Enable Windows Update access"
  type        = bool
  default     = true
}

variable "enable_azure_devops" {
  description = "Enable Azure DevOps access"
  type        = bool
  default     = false
}

variable "enable_github" {
  description = "Enable GitHub access"
  type        = bool
  default     = false
}

variable "approved_external_fqdns" {
  description = "Array of approved external FQDNs (e.g., [\"api.example.com\", \"*.partner.com\"])"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    "Compliance"      = "TIC 3.0"
    "Architecture"    = "Zero Trust"
    "ManagedBy"       = "Terraform"
    "DeploymentType"  = "FirewallRules"
  }
}
