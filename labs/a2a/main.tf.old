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
  name     = var.rg_name_source
  location = var.source_region
}

resource "azurerm_resource_group" "target_rg" {
  name     = var.rg_name_target
  location = var.target_region
}

### Network Stuff ###
resource "azurerm_network_security_group" "source_nsg" {
  name                = "${var.source_vnet_name}-nsg"
  location            = azurerm_resource_group.source_rg.location
  resource_group_name = azurerm_resource_group.source_rg.name

  security_rule {
    name                    = "Allow-Connectivity"
    priority                = 100
    direction               = "Inbound"
    access                  = "Allow"
    protocol                = "Tcp"
    source_port_range       = "*"
    destination_port_ranges = ["3389", "5985-5986", "1433"]
    source_address_prefixes = ["${local.my_ip_clean}/32"]
    # source_address_prefix    = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "target_nsg" {
  name                = "${var.target_vnet_name}-nsg"
  location            = azurerm_resource_group.target_rg.location
  resource_group_name = azurerm_resource_group.target_rg.name

  security_rule {
    name                       = "Allow-Connectivity"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["3389", "5985-5986", "1433"]
    source_address_prefixes    = ["${local.my_ip_clean}/32"]
    destination_address_prefix = "*"
  }
}

resource "azurerm_virtual_network" "source_vnet" {
  resource_group_name = azurerm_resource_group.source_rg.name
  name                = var.source_vnet_name
  address_space       = var.source_vnet_address_space
  location            = azurerm_resource_group.source_rg.location
}

resource "azurerm_virtual_network" "target_vnet" {
  resource_group_name = azurerm_resource_group.target_rg.name
  name                = var.target_vnet_name
  address_space       = var.target_vnet_address_space
  location            = azurerm_resource_group.target_rg.location
}


resource "azurerm_subnet" "source_subnet" {
  name                 = var.source_subnet_name
  resource_group_name  = azurerm_resource_group.source_rg.name
  virtual_network_name = azurerm_virtual_network.source_vnet.name
  address_prefixes     = var.source_subnet_address_prefixes
}

resource "azurerm_subnet" "target_subnet" {
  name                 = var.target_subnet_name
  resource_group_name  = azurerm_resource_group.target_rg.name
  virtual_network_name = azurerm_virtual_network.target_vnet.name
  address_prefixes     = var.target_subnet_address_prefixes
}

resource "azurerm_subnet_network_security_group_association" "source_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.source_subnet.id
  network_security_group_id = azurerm_network_security_group.source_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "target_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.target_subnet.id
  network_security_group_id = azurerm_network_security_group.target_nsg.id
}

resource "azurerm_recovery_services_vault" "asr_vault" {
  name                = var.rsv_name
  location            = azurerm_resource_group.target_rg.location
  resource_group_name = azurerm_resource_group.target_rg.name
  sku                 = var.rsv_sku
  storage_mode_type   = var.rsv_storage_mode_type
}

resource "azurerm_storage_account" "asr_storage" {
  name                     = var.cache_storage_name
  resource_group_name      = azurerm_resource_group.target_rg.name
  location                 = var.source_region
  account_tier             = var.cache_storage_account_tier
  account_replication_type = var.cache_storage_replication_type
  tags                     = { "SecurityControl" = "Ignore" }
}

resource "azurerm_public_ip" "vm_pip" {
  count               = 2
  name                = "vm${count.index}-pip"
  location            = azurerm_resource_group.source_rg.location
  resource_group_name = azurerm_resource_group.source_rg.name
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}

resource "azurerm_network_interface" "vm_nic" {
  count               = 2
  name                = "vm${count.index}-nic"
  location            = azurerm_resource_group.source_rg.location
  resource_group_name = azurerm_resource_group.source_rg.name


  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.source_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_pip[count.index].id
  }
}

resource "azurerm_linux_virtual_machine" "linux_vm" {
  name                = "${var.vm_name_prefix}-0"
  resource_group_name = azurerm_resource_group.source_rg.name
  location            = azurerm_resource_group.source_rg.location
  size                = var.vm_size
  network_interface_ids = [
    azurerm_network_interface.vm_nic[0].id,
  ]
  admin_username                  = var.vm_admin_username
  admin_password                  = var.vm_admin_password
  disable_password_authentication = "false"
  depends_on                      = [azurerm_network_interface.vm_nic]

  source_image_reference {
    publisher = var.linux_vm_image.publisher
    offer     = var.linux_vm_image.offer
    sku       = var.linux_vm_image.sku
    version   = var.linux_vm_image.version
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.vm_os_disk_storage_account_type
  }

  tags = var.vm_tags
}

resource "azurerm_windows_virtual_machine" "windows_vm" {
  name                                                   = "${var.vm_name_prefix}-1"
  resource_group_name                                    = azurerm_resource_group.source_rg.name
  location                                               = azurerm_resource_group.source_rg.location
  size                                                   = var.vm_size
  admin_username                                         = var.vm_admin_username
  admin_password                                         = var.vm_admin_password
  bypass_platform_safety_checks_on_user_schedule_enabled = true
  patch_mode                                             = "AutomaticByPlatform"
  network_interface_ids = [
    azurerm_network_interface.vm_nic[1].id,
  ]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.vm_os_disk_storage_account_type
  }


  source_image_reference {
    publisher = var.windows_vm_image.publisher
    offer     = var.windows_vm_image.offer
    sku       = var.windows_vm_image.sku
    version   = var.windows_vm_image.version
  }

  boot_diagnostics {

  }

  tags = var.vm_tags
}