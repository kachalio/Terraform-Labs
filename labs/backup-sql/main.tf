# Windows and Linux VM
# Network
# Storage
# RSV

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = ">= 1.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azapi" {

}

resource "azurerm_resource_group" "source_rg" {
  name     = var.source_rg_name
  location = var.source_location
}

### Network Stuff ###
module "source_network" {
  source = "../../modules/network"

  rg_name     = azurerm_resource_group.source_rg.name
  rg_location = azurerm_resource_group.source_rg.location

  vnet_name          = var.source_vnet_name
  vnet_address_space = var.source_vnet_address_space

  security_rules_list = var.security_rules_list

  create_nat_gateway = var.create_nat_gateway 

  subnet_name             = var.source_subnet_name
  subnet_address_prefixes = var.source_subnet_address_prefixes

  tags = {
    "DeployedByTerraform" = "YouBetcha"
  }
}


### Backup Stuff ###

resource "azurerm_recovery_services_vault" "recovery_services_vault" {
  name                = var.rsv_name
  location            = azurerm_resource_group.source_rg.location
  resource_group_name = azurerm_resource_group.source_rg.name
  sku                 = "Standard"
  storage_mode_type   = var.rsv_storage_mode_type

  identity {
    type = "SystemAssigned"
  }

}

resource "azurerm_backup_policy_vm_workload" "backup_policy" {
  name                = "backup-policy"
  resource_group_name = azurerm_resource_group.source_rg.name
  recovery_vault_name = azurerm_recovery_services_vault.recovery_services_vault.name

  workload_type = "SQLDataBase"

  settings {
    time_zone = "Eastern Standard Time"
    compression_enabled = false
  }

  protection_policy{
    policy_type = "Full"

    backup {
      frequency = "Daily"
      time      = "08:00"
    }

    retention_daily {
      count = 7
    }
  }

  protection_policy {
    
    policy_type = "Log"

    backup {
      frequency_in_minutes = 15
    }

    simple_retention {
      count = 7
    }

  }

}

### VM Stuff ###

module "windows_vm" {
  source                          = "../../modules/vm_windows"
  count                           = var.windows_vm_count
  vm_name                         = "${var.windows_vm_name_prefix}-${count.index + 1}"
  resource_group_name             = azurerm_resource_group.source_rg.name
  location                        = azurerm_resource_group.source_rg.location
  windows_vm_size                 = var.vm_size
  subnet_id                       = module.source_network.subnet_id
  vm_admin_username               = var.vm_admin_username
  vm_admin_password               = var.vm_admin_password
  create_public_ip                = var.create_public_ip
  windows_vm_image                = var.windows_vm_image
  windows_plan                    = var.windows_plan
  vm_os_disk_storage_account_type = var.windows_vm_os_disk_storage_account_type
  vm_data_disk_configuration       = var.vm_data_disk_configuration
  secure_boot_enabled             = var.secure_boot_enabled_windows

  

  tags = {
    "DeployedByTerraform" = "YouBetcha"
  }
}

### Adds SQL Server Component ###
resource "azurerm_mssql_virtual_machine" "sql_vm" {
  count = var.windows_vm_count
  virtual_machine_id = module.windows_vm[count.index].vm_id
  sql_license_type   = "PAYG"
}

### Enabling Backup Protection Stuff ###

  resource "azapi_resource_action" "discover_sql_vm" {
    type = "Microsoft.RecoveryServices/vaults@2016-12-01"
    resource_id = azurerm_recovery_services_vault.recovery_services_vault.id
    action = "backupFabrics/Azure/refreshContainers"
    
    query_parameters = {
      filter = [ "backupManagementType eq 'AzureWorkload'"]
    }
  }

  