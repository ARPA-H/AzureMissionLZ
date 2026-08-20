/*
Copyright (c) Microsoft Corporation.
Licensed under the MIT License.
*/

variable "location" {
  type        = string
  description = "Azure region for the Event Hub namespace deployed by this add-on."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the existing MLZ resource group (e.g. the hub or operations RG) that will host the TIC 3.0 Event Hub namespace."
}

variable "naming_prefix" {
  type        = list(string)
  description = "Prefix segments passed to the Azure/naming/azurerm module, matching the MLZ resourcePrefix."
  default     = []
}

variable "naming_suffix" {
  type        = list(string)
  description = "Suffix segments passed to the Azure/naming/azurerm module (e.g. [\"mlz\", \"tic30\"])."
  default     = ["operations", "tic30", "usc"]
}

variable "eventhub_namespace_sku" {
  type        = string
  description = "SKU for the TIC 3.0 Event Hub namespace."
  default     = "Standard"
}

variable "eventhub_namespace_capacity" {
  type        = number
  description = "Throughput units for the TIC 3.0 Event Hub namespace."
  default     = 1
}

variable "eventhub_partition_count" {
  type        = number
  description = "Partition count for each TIC 3.0 event hub."
  default     = 2
}

variable "eventhub_message_retention" {
  type        = number
  description = "Message retention in days for each TIC 3.0 event hub."
  default     = 7
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources created by this add-on."
  default     = {}
}
