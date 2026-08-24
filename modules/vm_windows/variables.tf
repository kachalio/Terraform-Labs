variable "location" {
  description = "The location of the resource group"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "subnet_id" {
  description = "The ID of the subnet"
  type        = string
}

variable "vm_name" {
  description = "The name of the Windows VM"
  type        = string
  default     = "tf-asr-windows-vm"
}

variable "windows_vm_size" {
  description = "The size of the Windows VM"
  type        = string
  default     = "Standard_B2s"
}

variable "vm_admin_username" {
  description = "The admin username for the Windows VM"
  type        = string
}

variable "vm_admin_password" {
  description = "The admin password for the Windows VM"
  type        = string
  sensitive   = true
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
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

variable "vm_os_disk_storage_account_type" {
  description = "The storage account type for the OS disk"
  type        = string
  default     = "Standard_LRS"
}


variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}