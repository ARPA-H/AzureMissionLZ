/*
Copyright (c) Microsoft Corporation.
Licensed under the MIT License.
*/

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.3"
  prefix  = var.naming_prefix
  suffix  = var.naming_suffix
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

resource "azurerm_eventhub_namespace" "tic30" {
  name                = module.naming.eventhub_namespace.name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  sku                 = var.eventhub_namespace_sku
  capacity            = var.eventhub_namespace_capacity
  tags                = var.tags
}

resource "azurerm_eventhub" "firewall_logs" {
  name              = "${module.naming.eventhub.name}-firewall-logs"
  namespace_id      = azurerm_eventhub_namespace.tic30.id
  partition_count   = var.eventhub_partition_count
  message_retention = var.eventhub_message_retention
}

resource "azurerm_eventhub" "entra_id_logs" {
  name              = "${module.naming.eventhub.name}-entra-id-logs"
  namespace_id      = azurerm_eventhub_namespace.tic30.id
  partition_count   = var.eventhub_partition_count
  message_retention = var.eventhub_message_retention
}
