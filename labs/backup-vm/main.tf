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

module "target_network" {
  source = "../../modules/network"

  rg_name     = azurerm_resource_group.target_rg.name
  rg_location = azurerm_resource_group.target_rg.location

  vnet_name          = var.target_vnet_name
  vnet_address_space = var.target_vnet_address_space

  security_rules_list = var.security_rules_list
  create_nat_gateway = var.create_nat_gateway

  subnet_name             = var.target_subnet_name
  subnet_address_prefixes = var.target_subnet_address_prefixes

  tags = {
    "DeployedByTerraform" = "YouBetcha"
  }
}


### Backup Stuff ###

resource "azurerm_recovery_services_vault" "recovery_services_vault" {
  name                = var.rsv_name
  location            = azurerm_resource_group.target_rg.location
  resource_group_name = azurerm_resource_group.target_rg.name
  sku                 = "Standard"
  storage_mode_type   = var.rsv_storage_mode_type

  identity {
    type = "SystemAssigned"
  }

}

### VM Stuff ###

module "linux_vm" {
  source                          = "../../modules/vm_linux"
  count                           = var.linux_vm_count
  vm_name                         = "${var.linux_vm_name_prefix}-${count.index + 1}"
  resource_group_name             = azurerm_resource_group.source_rg.name
  location                        = azurerm_resource_group.source_rg.location
  linux_vm_size                   = var.vm_size
  subnet_id                       = module.source_network.subnet_id
  vm_admin_username               = var.vm_admin_username
  vm_admin_password               = var.vm_admin_password
  create_public_ip                = var.create_public_ip
  linux_vm_image                  = var.linux_vm_image
  vm_os_disk_storage_account_type = var.linux_vm_os_disk_storage_account_type
  secure_boot_enabled              = var.secure_boot_enabled_linux
  

  tags = {
    "DeployedByTerraform" = "YouBetcha"
  }
}

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
  vm_os_disk_storage_account_type = var.windows_vm_os_disk_storage_account_type
  secure_boot_enabled              = var.secure_boot_enabled_windows

  tags = {
    "DeployedByTerraform" = "YouBetcha"
  }
}

### Enabling Backup Protection Stuff ###
