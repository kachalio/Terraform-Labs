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
  description = "The name of the Linux VM"
  type        = string
  default     = "tf-asr-linux-vm"
}

variable "linux_vm_size" {
  description = "The size of the Linux VM"
  type        = string
  default     = "Standard_B2s"
}

variable "vm_admin_username" {
  description = "The admin username for the Linux VM"
  type        = string
}

variable "vm_admin_password" {
  description = "The admin password for the Linux VM"
  type        = string
  sensitive   = true
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