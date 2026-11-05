output "server_ip" {
    value = vsphere_virtual_machine.vm.default_ip_address
}

output "server_name" {
    value = vsphere_virtual_machine.vm.name
}

# output "server_hostname" {
#     # value = vsphere_virtual_machine.vm.clone.customize[0].windows_options[0].computer_name
#     # value = vsphere_virtual_machine.appliance.clone[0].customize[0].computer_name
#     # sensitive = true
# }