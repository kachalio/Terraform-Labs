mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "random" {}

run "a2a_wrapper" {
  command = plan

  module {
    source = "../../labs/a2a"
  }

  variables {
    vm_admin_username = "azureuser"
    vm_admin_password = "Test-only-not-a-real-credential!"
  }

  assert {
    condition = (
      output.linux_vm_names == module.lab.linux_vm_names &&
      output.windows_vm_names == module.lab.windows_vm_names &&
      output.linux_public_ips == [null] &&
      output.windows_public_ips == [null]
    )
    error_message = "The A2A deployment wrapper must forward the module's outputs."
  }
}

run "backup_saphana_wrapper" {
  command = plan

  module {
    source = "../../labs/backup-saphana"
  }

  variables {
    vm_admin_username    = "azureuser"
    vm_admin_password    = "Test-only-not-a-real-credential!"
    hana_master_password = "Test-only-not-a-real-credential!"
  }

  assert {
    condition = (
      output.linux_vm_names == module.lab.linux_vm_names &&
      output.windows_vm_names == module.lab.windows_vm_names
    )
    error_message = "The HANA deployment wrapper must forward the module's outputs."
  }
}

run "backup_sql_wrapper" {
  command = plan

  module {
    source = "../../labs/backup-sql"
  }

  variables {
    vm_admin_username = "azureuser"
    vm_admin_password = "Test-only-not-a-real-credential!"
  }

  assert {
    condition = (
      output.windows_vm_names == module.lab.windows_vm_names &&
      output.windows_public_ips == [null]
    )
    error_message = "The SQL backup deployment wrapper must forward the module's outputs."
  }
}

run "backup_vm_wrapper" {
  command = plan

  module {
    source = "../../labs/backup-vm"
  }

  variables {
    vm_admin_username = "azureuser"
    vm_admin_password = "Test-only-not-a-real-credential!"
  }

  assert {
    condition = (
      output.linux_vm_names == module.lab.linux_vm_names &&
      output.windows_vm_names == module.lab.windows_vm_names &&
      output.linux_public_ips == [null] &&
      output.windows_public_ips == [null]
    )
    error_message = "The VM backup deployment wrapper must forward the module's outputs."
  }
}

run "migrate_vmware_wrapper" {
  command = plan

  module {
    source = "../../labs/migrate-vmware"
  }

  variables {
    migrate_project_name = "testmigrate"
  }

  assert {
    condition     = output.migrate_project_name == "testmigrate"
    error_message = "The Migrate wrapper must expose the module's project name."
  }
}

run "migrate_vmware_pe_wrapper" {
  command = plan

  module {
    source = "../../labs/migrate-vmware-pe"
  }

  variables {
    migrate_project_name = "testmigratepe"
  }

  assert {
    condition     = output.migrate_project_name == "testmigratepe"
    error_message = "The private-endpoint Migrate wrapper must expose the module's project name."
  }
}
