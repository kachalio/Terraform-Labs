output "subnet_id" {
  description = "The Id of the subnet"
  value = azurerm_subnet.subnet.id
}

output "subnet_name" {
  description = "The name of the subnet"
  value = azurerm_subnet.subnet.name
}

output "vnet_id" {
  description = "The id of the virtual network"
  value = azurerm_virtual_network.vnet.id
}