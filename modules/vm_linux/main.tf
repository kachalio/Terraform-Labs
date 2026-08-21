
resource "azurerm_network_interface" "vm_nic" {
  name                = "${var.vm_name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "${var.vm_name}-ipconfig"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                 = var.vm_name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.linux_vm_size
  network_interface_ids = [
    azurerm_network_interface.vm_nic.id,
  ]
  admin_username                  = var.vm_admin_username
  admin_password                  = var.vm_admin_password
  disable_password_authentication = "false"

  boot_diagnostics {
    
  }
  

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

  tags = var.tags
}