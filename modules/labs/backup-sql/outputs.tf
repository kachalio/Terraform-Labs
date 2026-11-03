output "source_resource_group_id" {
  value = azurerm_resource_group.source_rg.id
}

output "windows_vm_names" {
  value = [for vm in module.windows_vm : vm.vm_name]
}

output "windows_public_ips" {
  value = [for vm in module.windows_vm : vm.public_ip_address]
}
