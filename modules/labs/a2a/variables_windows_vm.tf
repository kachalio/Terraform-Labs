
### Windows VM ###

variable "windows_vm_name_prefix" {
  description = "The prefix for the Windows VM name"
  type        = string
  default     = "win-vm"
}

variable "windows_vm_count" {
  description = "The number of Windows VMs to create"
  type        = number
  default     = 1
}

variable "windows_vm_image" {
  description = "The image reference for the Windows VM"
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-g2"
    version   = "latest"
  }
}

variable "windows_vm_os_disk_storage_account_type" {
  description = "The storage account type for the Windows VM OS disk"
  type        = string
  default     = "Standard_LRS"
}

variable "secure_boot_enabled_windows" {
  description = "Whether secure boot is enabled for the Windows VMs"
  type        = bool
  default     = true
}

