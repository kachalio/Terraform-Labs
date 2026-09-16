resource "azurerm_public_ip" "vm_public_ip" {
  count = var.create_public_ip ? 1 : 0

  name                = "${var.vm_name}-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_tags             = {
    "FirstPartyUsage" = "/Unprivileged"
  }
  
  tags = var.tags
}

resource "azurerm_network_interface" "vm_nic" {
  name                = "${var.vm_name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "${var.vm_name}-ipconfig"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.create_public_ip ? azurerm_public_ip.vm_public_ip[0].id : null
  }

  tags = var.tags
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                 = var.vm_name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.windows_vm_size
  network_interface_ids = [
    azurerm_network_interface.vm_nic.id,
  ]
  admin_username                  = var.vm_admin_username
  admin_password                  = var.vm_admin_password
  # disable_password_authentication = "false"
  patch_mode = "AutomaticByPlatform"
  bypass_platform_safety_checks_on_user_schedule_enabled = true
  
  boot_diagnostics {
    
  }

  source_image_reference {
    publisher = var.windows_vm_image.publisher
    offer     = var.windows_vm_image.offer
    sku       = var.windows_vm_image.sku
    version   = var.windows_vm_image.version
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.vm_os_disk_storage_account_type
  }

  tags = var.tags
}