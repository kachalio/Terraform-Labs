
### Linux VM ###

variable "linux_vm_count" {
  description = "The number of Linux VMs to create"
  type        = number
  default     = 1
}

variable "linux_vm_name_prefix" {
  description = "The prefix for the Linux VM name"
  type        = string
  default     = "lin-vm"
}

variable "vm_size" {
  description = "The size of the virtual machine"
  type        = string
  default     = "Standard_D2s_v5"
}

variable "linux_vm_image" {
  description = "The image reference for the Linux VM"
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

variable "linux_vm_os_disk_storage_account_type" {
  description = "The storage account type for the Linux VM OS disk"
  type        = string
  default     = "Standard_LRS"
}

variable "secure_boot_enabled_linux" {
  description = "Whether secure boot is enabled for the Linux VMs"
  type        = bool
  default     = true
}

