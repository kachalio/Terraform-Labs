output "source_resource_group_id" {
  value = module.lab.source_resource_group_id
}

output "linux_vm_names" {
  value = module.lab.linux_vm_names
}

output "windows_vm_names" {
  value = module.lab.windows_vm_names
}

output "linux_public_ips" {
  value = module.lab.linux_public_ips
}

output "windows_public_ips" {
  value = module.lab.windows_public_ips
}
