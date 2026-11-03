mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "random" {}

run "multiple_instances_with_default_protection" {
  command = plan

  assert {
    condition = (
      length(module.a2a) == 2 &&
      length(module.backup_saphana) == 2 &&
      length(module.backup_sql) == 2 &&
      length(module.backup_vm) == 2 &&
      length(module.migrate_vmware) == 2 &&
      length(module.migrate_vmware_pe) == 2
    )
    error_message = "Every reusable lab must support multiple instances using count or for_each."
  }

  assert {
    condition = (
      module.a2a["first"].linux_vm_names == ["a2a-first-lin-1"] &&
      module.a2a["second"].windows_vm_names == ["a2a-second-win-1"] &&
      module.backup_saphana[0].linux_vm_names == ["hana-0-lin-1"] &&
      length(module.backup_saphana[0].windows_vm_names) == 0 &&
      module.backup_sql["first"].windows_vm_names == ["sql-first-win-1"] &&
      module.backup_vm[1].linux_vm_names == ["backup-1-lin-1"] &&
      module.backup_vm[1].windows_vm_names == ["backup-1-win-1"]
    )
    error_message = "Lab inputs, VM count defaults, and VM name outputs must remain unchanged."
  }

  assert {
    condition = (
      module.a2a["first"].linux_public_ips == [null] &&
      module.a2a["first"].windows_public_ips == [null] &&
      module.backup_sql["first"].windows_public_ips == [null] &&
      module.backup_vm[0].linux_public_ips == [null] &&
      module.backup_vm[0].windows_public_ips == [null]
    )
    error_message = "VM public IP addresses must remain disabled by default."
  }

  assert {
    condition = (
      module.migrate_vmware["first"].migrate_project_name == "migratefirst" &&
      module.migrate_vmware["second"].migrate_project_name == "migratesecond" &&
      module.migrate_vmware_pe[0].migrate_project_name == "migratepe0" &&
      module.migrate_vmware_pe[1].migrate_project_name == "migratepe1"
    )
    error_message = "Migrate labs must expose the project name for each independent instance."
  }
}

run "multiple_instances_with_protection_enabled" {
  command = plan

  variables {
    enable_protection = true
  }

  assert {
    condition = (
      module.a2a["first"].linux_vm_names == ["a2a-first-lin-1"] &&
      module.backup_vm[0].windows_vm_names == ["backup-0-win-1"]
    )
    error_message = "Enabling ASR replication or VM backup must retain the existing VM interface."
  }
}
