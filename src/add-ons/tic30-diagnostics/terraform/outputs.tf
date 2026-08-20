/*
Copyright (c) Microsoft Corporation.
Licensed under the MIT License.
*/

output "eventhub_namespace_id" {
  value = azurerm_eventhub_namespace.tic30.id
}

output "eventhub_namespace_name" {
  value = azurerm_eventhub_namespace.tic30.name
}

output "firewall_logs_eventhub_name" {
  value = azurerm_eventhub.firewall_logs.name
}

output "entra_id_logs_eventhub_name" {
  value = azurerm_eventhub.entra_id_logs.name
}

output "diagnostic_settings_authorization_rule_id" {
  value = azurerm_eventhub_namespace_authorization_rule.send.id
}

output "diagnostic_settings_authorization_rule_name" {
  value = azurerm_eventhub_namespace_authorization_rule.send.name
}
