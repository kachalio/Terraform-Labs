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
  secure_boot_enabled = var.secure_boot_enabled

  boot_diagnostics {
    storage_account_uri = null
  }

  source_image_reference {
    publisher = var.windows_vm_image.publisher
    offer     = var.windows_vm_image.offer
    sku       = var.windows_vm_image.sku
    version   = var.windows_vm_image.version
  }

  dynamic "plan" {
    for_each = var.windows_plan == null ? [] : [var.windows_plan]

    content {
      name = plan.value.name
      product = plan.value.product
      publisher = plan.value.publisher
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.vm_os_disk_storage_account_type
  }

  tags = var.tags
}

resource "azurerm_managed_disk" "vm_data_disk" {
  count                = var.vm_data_disk_configuration == null ? 0 : length(var.vm_data_disk_configuration)
  name                 = "${var.vm_name}-data-disk-${count.index + 1}"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = var.vm_data_disk_configuration[count.index].storage_account_type
  create_option        = "Empty"
  disk_size_gb         = var.vm_data_disk_configuration[count.index].disk_size_gb
  tags                 = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "vm_data_disk_attachment" {
  count                = var.vm_data_disk_configuration == null ? 0 : length(var.vm_data_disk_configuration)
  managed_disk_id      = azurerm_managed_disk.vm_data_disk[count.index].id
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  lun                  = count.index
  caching              = "ReadWrite"
}