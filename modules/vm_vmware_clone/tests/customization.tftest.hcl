mock_provider "vsphere" {}

variables {
  vsphere_user            = "test-user"
  vsphere_password        = "test-only-not-a-real-credential"
  vsphere_server          = "vcenter.example.test"
  vsphere_datacenter      = "test-datacenter"
  vsphere_datastore       = "test-datastore"
  vsphere_compute_cluster = "test-cluster"
  vsphere_network         = "test-network"
  vsphere_template        = "test-template"
  vm_name                 = "test-vm"
  vm_disk_size            = 40
}

run "linux_customization" {
  command = plan

  override_data {
    target = data.vsphere_virtual_machine.template
    values = {
      guest_id = "ubuntu64Guest"
    }
  }

  assert {
    condition = (
      length(vsphere_virtual_machine.vm.clone[0].customize[0].linux_options) == 1 &&
      length(vsphere_virtual_machine.vm.clone[0].customize[0].windows_options) == 0 &&
      vsphere_virtual_machine.vm.clone[0].customize[0].linux_options[0].host_name == var.vm_name &&
      vsphere_virtual_machine.vm.clone[0].customize[0].linux_options[0].domain == "localdomain" &&
      length(vsphere_virtual_machine.vm.clone[0].customize[0].network_interface) == 1
    )
    error_message = "Linux templates must receive only Linux customization with the VM host name, domain, and DHCP interface."
  }
}

run "windows_customization" {
  command = plan

  override_data {
    target = data.vsphere_virtual_machine.template
    values = {
      guest_id = "windows9Server64Guest"
    }
  }

  assert {
    condition = (
      length(vsphere_virtual_machine.vm.clone[0].customize[0].windows_options) == 1 &&
      length(vsphere_virtual_machine.vm.clone[0].customize[0].linux_options) == 0 &&
      vsphere_virtual_machine.vm.clone[0].customize[0].windows_options[0].computer_name == var.vm_name &&
      length(vsphere_virtual_machine.vm.clone[0].customize[0].network_interface) == 1
    )
    error_message = "Windows templates must receive only Windows customization with the VM computer name and DHCP interface."
  }
}

run "legacy_windows_customization" {
  command = plan

  override_data {
    target = data.vsphere_virtual_machine.template
    values = {
      guest_id = "longhorn64Guest"
    }
  }

  assert {
    condition = (
      length(vsphere_virtual_machine.vm.clone[0].customize[0].windows_options) == 1 &&
      length(vsphere_virtual_machine.vm.clone[0].customize[0].linux_options) == 0
    )
    error_message = "Legacy Windows guest IDs must also select Windows customization."
  }
}
