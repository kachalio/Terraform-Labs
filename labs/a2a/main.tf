# Windows and Linux VM
# Network
# Storage
# RSV

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

resource "azurerm_resource_group" "source_rg" {
  name     = var.source_rg_name
  location = var.source_location
}

resource "azurerm_resource_group" "target_rg" {
  name     = var.target_rg_name
  location = var.target_location
}

### Network Stuff ###
module "source_network" {
  source = "../../modules/network"

  rg_name                 = azurerm_resource_group.source_rg.name
  rg_location             = azurerm_resource_group.source_rg.location

  vnet_name               = var.source_vnet_name
  vnet_address_space      = var.source_vnet_address_space
  
  subnet_name             = var.source_subnet_name
  subnet_address_prefixes = var.source_subnet_address_prefixes
  
  tags = {
    "DeployedByTerraform" = "YouBetcha"
  }
}

module "target_network" {
  source = "../../modules/network"

  rg_name                 = azurerm_resource_group.target_rg.name
  rg_location             = azurerm_resource_group.target_rg.location

  vnet_name               = var.target_vnet_name
  vnet_address_space      = var.target_vnet_address_space
  
  subnet_name             = var.target_subnet_name
  subnet_address_prefixes = var.target_subnet_address_prefixes
  
  tags = {
    "DeployedByTerraform" = "YouBetcha"
  }
}


### ASR Stuff ###

resource "azurerm_recovery_services_vault" "asr_vault" {
  name                = var.rsv_name
  location            = azurerm_resource_group.target_rg.location
  resource_group_name = azurerm_resource_group.target_rg.name
  sku                 = "Standard"
  storage_mode_type   = var.rsv_storage_mode_type
}

resource "azurerm_storage_account" "asr_storage" {
  name                     = var.cache_storage_name
  resource_group_name      = azurerm_resource_group.target_rg.name
  location                 = azurerm_resource_group.source_rg.location
  account_tier             = var.cache_storage_account_tier
  account_replication_type = var.cache_storage_replication_type
  tags                     = { "SecurityControl" = "Ignore" }
  shared_access_key_enabled = true
}

### VM Stuff ###

module "linux_vm" {
  source = "../../modules/vm_linux"
  count = var.linux_vm_count
  vm_name                     = "${var.linux_vm_name_prefix}-1"
  resource_group_name         = azurerm_resource_group.source_rg.name
  location                    = azurerm_resource_group.source_rg.location
  linux_vm_size               = var.vm_size
  subnet_id                   = module.source_network.subnet_id
  vm_admin_username           = var.vm_admin_username
  vm_admin_password           = var.vm_admin_password
  linux_vm_image              = var.linux_vm_image
  vm_os_disk_storage_account_type = var.linux_vm_os_disk_storage_account_type

  tags = {
    "DeployedByTerraform" = "YouBetcha"
  }
}

module "windows_vm" {
  source = "../../modules/vm_windows"
  count = var.windows_vm_count
  vm_name                     = "${var.windows_vm_name_prefix}-1"
  resource_group_name         = azurerm_resource_group.source_rg.name
  location                    = azurerm_resource_group.source_rg.location
  windows_vm_size             = var.vm_size
  subnet_id                   = module.source_network.subnet_id
  vm_admin_username           = var.vm_admin_username
  vm_admin_password           = var.vm_admin_password
  windows_vm_image            = var.windows_vm_image
  vm_os_disk_storage_account_type = var.windows_vm_os_disk_storage_account_type

  tags = {
    "DeployedByTerraform" = "YouBetcha"
  }
}

### Enabling ASR Protection Stuff ###

module "asr_enable_protection" {
  source = "../../modules/asr_enable_replication"
  count = var.enable_replication ? 1 : 0
  rsv_name                      = azurerm_recovery_services_vault.asr_vault.name
  source_location               = azurerm_resource_group.source_rg.location
  source_resource_group_name    = azurerm_resource_group.source_rg.name
  target_location               = azurerm_resource_group.target_rg.location
  target_resource_group_name  = azurerm_resource_group.target_rg.name
  source_network_id             = module.source_network.vnet_id
  target_network_id             = module.target_network.vnet_id
}

