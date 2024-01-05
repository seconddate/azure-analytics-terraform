output "spoke_rg" {
  value = azurerm_resource_group.spoke_rg
}

output "spoke_vnet" {
  value = azurerm_virtual_network.spoke_vnet
}

output "spoke_adls" {
  value = azurerm_storage_account.spoke_adls
}

output "spoke_eventhub_namespace" {
    value = azurerm_eventhub_namespace.spoke_eventhub_namespace
}