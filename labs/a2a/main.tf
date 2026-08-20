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
  name     = "Lab-ASR-Source"
  location = "eastus2"
}

resource "azurerm_resource_group" "target_rg" {
  name     = "Lab-ASR-Target"
  location = "westus2"
}

### Network Stuff ###
module "source_network" {
  source = "../../modules/network"

  rg_name                 = azurerm_resource_group.source_rg.name
  rg_location             = azurerm_resource_group.source_rg.location

  vnet_name               = "Lab-ASR-Source-VNet"
  vnet_address_space      = ["10.0.0.0/16"]
  
  subnet_name             = "default"
  subnet_address_prefixes = ["10.0.0.0/24"]
  
  tags = {
    "DeployedByTerraform" = "YouBetcha"
  }
}


### Other Stuff ###

# resource "azurerm_recovery_services_vault" "asr_vault" {
#   name                = var.rsv_name
#   location            = azurerm_resource_group.target_rg.location
#   resource_group_name = azurerm_resource_group.target_rg.name
#   sku                 = var.rsv_sku
#   storage_mode_type   = var.rsv_storage_mode_type
# }

# resource "azurerm_storage_account" "asr_storage" {
#   name                     = var.cache_storage_name
#   resource_group_name      = azurerm_resource_group.target_rg.name
#   location                 = var.source_region
#   account_tier             = var.cache_storage_account_tier
#   account_replication_type = var.cache_storage_replication_type
#   tags                     = { "SecurityControl" = "Ignore" }
# }

# resource "azurerm_public_ip" "vm_pip" {
#   count               = 2
#   name                = "vm${count.index}-pip"
#   location            = azurerm_resource_group.source_rg.location
#   resource_group_name = azurerm_resource_group.source_rg.name
#   allocation_method   = "Dynamic"
#   sku                 = "Basic"
# }

# resource "azurerm_network_interface" "vm_nic" {
#   count               = 2
#   name                = "vm${count.index}-nic"
#   location            = azurerm_resource_group.source_rg.location
#   resource_group_name = azurerm_resource_group.source_rg.name


#   ip_configuration {
#     name                          = "internal"
#     subnet_id                     = azurerm_subnet.source_subnet.id
#     private_ip_address_allocation = "Dynamic"
#     public_ip_address_id          = azurerm_public_ip.vm_pip[count.index].id
#   }
# }

# resource "azurerm_linux_virtual_machine" "linux_vm" {
#   name                = "${var.vm_name_prefix}-0"
#   resource_group_name = azurerm_resource_group.source_rg.name
#   location            = azurerm_resource_group.source_rg.location
#   size                = var.vm_size
#   network_interface_ids = [
#     azurerm_network_interface.vm_nic[0].id,
#   ]
#   admin_username                  = var.vm_admin_username
#   admin_password                  = var.vm_admin_password
#   disable_password_authentication = "false"
#   depends_on                      = [azurerm_network_interface.vm_nic]

#   source_image_reference {
#     publisher = var.linux_vm_image.publisher
#     offer     = var.linux_vm_image.offer
#     sku       = var.linux_vm_image.sku
#     version   = var.linux_vm_image.version
#   }

#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = var.vm_os_disk_storage_account_type
#   }

#   tags = var.vm_tags
# }

# resource "azurerm_windows_virtual_machine" "windows_vm" {
#   name                                                   = "${var.vm_name_prefix}-1"
#   resource_group_name                                    = azurerm_resource_group.source_rg.name
#   location                                               = azurerm_resource_group.source_rg.location
#   size                                                   = var.vm_size
#   admin_username                                         = var.vm_admin_username
#   admin_password                                         = var.vm_admin_password
#   bypass_platform_safety_checks_on_user_schedule_enabled = true
#   patch_mode                                             = "AutomaticByPlatform"
#   network_interface_ids = [
#     azurerm_network_interface.vm_nic[1].id,
#   ]
#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = var.vm_os_disk_storage_account_type
#   }


#   source_image_reference {
#     publisher = var.windows_vm_image.publisher
#     offer     = var.windows_vm_image.offer
#     sku       = var.windows_vm_image.sku
#     version   = var.windows_vm_image.version
#   }

#   boot_diagnostics {

#   }

#   tags = var.vm_tags
# }