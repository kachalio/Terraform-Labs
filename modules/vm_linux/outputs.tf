output "vm_name" {
  value = azurerm_linux_virtual_machine.vm.name
}

output "vm_id" {
  value = azurerm_linux_virtual_machine.vm.id
}

output "os_disk_id" {
  value = azurerm_linux_virtual_machine.vm.os_disk[0].id
}

output "nic_id" {
  value = azurerm_linux_virtual_machine.vm.network_interface_ids[0]
}

output "public_ip_address" {
  value = var.create_public_ip ? azurerm_public_ip.vm_public_ip[0].ip_address : null
}