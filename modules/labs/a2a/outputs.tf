output "source_resource_group_id" {
  value = azurerm_resource_group.source_rg.id
}

output "target_resource_group_id" {
  value = azurerm_resource_group.target_rg.id
}

output "linux_vm_names" {
  value = [for vm in module.linux_vm : vm.vm_name]
}

output "windows_vm_names" {
  value = [for vm in module.windows_vm : vm.vm_name]
}

output "linux_public_ips" {
  value = [for vm in module.linux_vm : vm.public_ip_address]
}

output "windows_public_ips" {
  value = [for vm in module.windows_vm : vm.public_ip_address]
}
