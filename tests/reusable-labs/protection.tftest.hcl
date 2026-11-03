mock_provider "azurerm" {}
mock_provider "azapi" {}

run "a2a_protection_disabled" {
  command = plan

  module {
    source = "../../modules/labs/a2a"
  }

  variables {
    vm_admin_username = "azureuser"
    vm_admin_password = "Test-only-not-a-real-credential!"
  }

  assert {
    condition = (
      length(module.asr_enable_protection) == 0 &&
      length(azurerm_site_recovery_replicated_vm.linux_vm_replication) == 0 &&
      length(azurerm_site_recovery_replicated_vm.windows_vm_replication) == 0
    )
    error_message = "ASR infrastructure and VM replication must remain absent when replication is disabled."
  }
}

run "a2a_protection_enabled" {
  command = plan

  module {
    source = "../../modules/labs/a2a"
  }

  variables {
    vm_admin_username  = "azureuser"
    vm_admin_password  = "Test-only-not-a-real-credential!"
    enable_replication = true
  }

  assert {
    condition = (
      length(module.asr_enable_protection) == 1 &&
      length(azurerm_site_recovery_replicated_vm.linux_vm_replication) == 1 &&
      length(azurerm_site_recovery_replicated_vm.windows_vm_replication) == 1
    )
    error_message = "Enabling replication must create one ASR module and protect each default VM."
  }
}

run "vm_backup_disabled" {
  command = plan

  module {
    source = "../../modules/labs/backup-vm"
  }

  variables {
    vm_admin_username = "azureuser"
    vm_admin_password = "Test-only-not-a-real-credential!"
  }

  assert {
    condition = (
      length(azurerm_backup_protected_vm.linux_vm_backup) == 0 &&
      length(azurerm_backup_protected_vm.windows_vm_backup) == 0
    )
    error_message = "VM backup protection must remain absent by default."
  }
}

run "vm_backup_enabled" {
  command = plan

  module {
    source = "../../modules/labs/backup-vm"
  }

  variables {
    vm_admin_username = "azureuser"
    vm_admin_password = "Test-only-not-a-real-credential!"
    enable_backup     = true
  }

  assert {
    condition = (
      length(azurerm_backup_protected_vm.linux_vm_backup) == 1 &&
      length(azurerm_backup_protected_vm.windows_vm_backup) == 1
    )
    error_message = "Enabling backup must protect each default VM."
  }
}

run "sql_discovery_disabled" {
  command = plan

  module {
    source = "../../modules/labs/backup-sql"
  }

  variables {
    vm_admin_username = "azureuser"
    vm_admin_password = "Test-only-not-a-real-credential!"
  }

  assert {
    condition = (
      length(azapi_resource_action.discover_sql_vm) == 0 &&
      length(azapi_resource_action.get_protectable_containers) == 0 &&
      length(azapi_resource_action.register_sql_vm) == 0
    )
    error_message = "SQL discovery and registration must remain absent by default."
  }
}

run "sql_discovery_enabled" {
  command = plan

  module {
    source = "../../modules/labs/backup-sql"
  }

  variables {
    vm_admin_username = "azureuser"
    vm_admin_password = "Test-only-not-a-real-credential!"
    start_discovery   = true
  }

  assert {
    condition = (
      length(azapi_resource_action.discover_sql_vm) == 1 &&
      length(azapi_resource_action.get_protectable_containers) == 1 &&
      length(azapi_resource_action.register_sql_vm) == 1
    )
    error_message = "Enabling SQL discovery must include discovery, container lookup, and VM registration."
  }
}
