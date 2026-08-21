output "subnet_id" {
  description = "The Id of the subnet"
  value = azurerm_subnet.subnet.id
}

output "vnet_id" {
  description = "The id of the virtual network"
  value = azurerm_virtual_network.vnet.id
}