

data "vsphere_datacenter" "dc" {
  name = var.vsphere_datacenter
}

data "vsphere_datastore" "datastore" {
  name          = var.vsphere_datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.vsphere_compute_cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = var.vsphere_network
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.vsphere_template
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  name          = var.vsphere_resource_pool
  datacenter_id = data.vsphere_datacenter.dc.id
}

resource "random_string" "suffix" {
  length  = 9
  special = false
  upper   = false
}


locals {
  template_is_windows = length(regexall("^(win|longhorn)", lower(data.vsphere_virtual_machine.template.guest_id))) > 0
  hostname = var.vm_hostname != null ? var.vm_hostname : random_string.suffix.result
}

resource "vsphere_virtual_machine" "vm" {
  name             = var.vm_name
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = data.vsphere_datastore.datastore.id

  num_cpus = var.vm_num_cpus
  memory   = var.vm_memory
  guest_id = data.vsphere_virtual_machine.template.guest_id
  firmware = var.vm_firmware
  folder   = var.vsphere_folder != null ? "${var.vsphere_datacenter}/vm/${var.vsphere_folder}" : null
  
  sync_time_with_host = false

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = var.vm_network_adapter_type
  }

  disk {
    label            = "osdisk"
    size             = var.vm_disk_size != null ? var.vm_disk_size : data.vsphere_virtual_machine.template.disks[0].size
    eagerly_scrub    = false
    thin_provisioned = var.vm_thin_provisioned
  }

  dynamic "disk" {
    for_each = var.vm_data_disks
    content {
      label            = disk.value.label
      size             = disk.value.size
      eagerly_scrub    = disk.value.eagerly_scrub
      thin_provisioned = disk.value.thin_provisioned
      unit_number      = disk.value.unit_number
    }
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
    customize {
      dynamic "windows_options" {
        for_each = local.template_is_windows ? [1] : []
        content {
          computer_name = local.hostname
          admin_password = var.vm_admin_password
          auto_logon_count = 1
            auto_logon       = true
            run_once_command_list = ["powershell.exe -Command \"Set-NetConnectionProfile -NetworkCategory 'Private'\""]
        }
      }

      dynamic "linux_options" {
        for_each = local.template_is_windows ? [] : [1]
        content {
          host_name = local.hostname
          domain    = "localdomain"
        }
      }

      network_interface {

      }
    }
  }
}