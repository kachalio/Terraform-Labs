terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    azapi = {
      source = "azure/azapi"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}

variable "enable_protection" {
  type    = bool
  default = false
}

locals {
  deployments = toset(["first", "second"])
}

module "a2a" {
  source   = "../../modules/labs/a2a"
  for_each = local.deployments

  source_rg_name         = "test-a2a-${each.key}-source"
  target_rg_name         = "test-a2a-${each.key}-target"
  cache_storage_name     = "testa2a${each.key}"
  vm_admin_username      = "azureuser"
  vm_admin_password      = "Test-only-not-a-real-credential!"
  linux_vm_name_prefix   = "a2a-${each.key}-lin"
  windows_vm_name_prefix = "a2a-${each.key}-win"
  enable_replication     = var.enable_protection
}

module "backup_saphana" {
  source = "../../modules/labs/backup-saphana"
  count  = 2

  source_rg_name       = "test-hana-${count.index}"
  vm_admin_username    = "azureuser"
  vm_admin_password    = "Test-only-not-a-real-credential!"
  hana_master_password = "Test-only-not-a-real-credential!"
  linux_vm_name_prefix = "hana-${count.index}-lin"
}

module "backup_sql" {
  source   = "../../modules/labs/backup-sql"
  for_each = local.deployments

  source_rg_name         = "test-sql-${each.key}"
  vm_admin_username      = "azureuser"
  vm_admin_password      = "Test-only-not-a-real-credential!"
  windows_vm_name_prefix = "sql-${each.key}-win"
}

module "backup_vm" {
  source = "../../modules/labs/backup-vm"
  count  = 2

  source_rg_name         = "test-backup-${count.index}"
  vm_admin_username      = "azureuser"
  vm_admin_password      = "Test-only-not-a-real-credential!"
  linux_vm_name_prefix   = "backup-${count.index}-lin"
  windows_vm_name_prefix = "backup-${count.index}-win"
  enable_backup          = var.enable_protection
}

module "migrate_vmware" {
  source   = "../../modules/labs/migrate-vmware"
  for_each = local.deployments

  resource_group_name  = "test-migrate-${each.key}"
  migrate_project_name = "migrate${each.key}"
}

module "migrate_vmware_pe" {
  source = "../../modules/labs/migrate-vmware-pe"
  count  = 2

  resource_group_name  = "test-migrate-pe-${count.index}"
  migrate_project_name = "migratepe${count.index}"
}
