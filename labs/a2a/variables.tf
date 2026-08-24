### Resource Group ###
variable "source_rg_name" {
  description = "The name of the source resource group"
  type        = string
  default     = "Lab-ASR-Source"
}

variable "source_location" {
  description = "The region of the source resource group"
  type        = string
  default     = "eastus2"
}

variable "target_rg_name" {
  description = "The name of the target resource group"
  type        = string
  default     = "Lab-ASR-Target"
}

variable "target_location" {
  description = "The region of the target resource group"
  type        = string
  default     = "westus2"
}

### Virtual Network ###

variable "source_vnet_name" {
  description = "The name of the source virtual network"
  type        = string
  default     = "Lab-ASR-Source-VNet"
}

variable "source_vnet_address_space" {
  description = "The address space of the source virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "source_subnet_name" {
  description = "The name of the source subnet"
  type        = string
  default     = "default"
}

variable "source_subnet_address_prefixes" {
  description = "The address prefixes of the source subnet"
  type        = list(string)
  default     = ["10.0.0.0/24"]
}

variable "target_vnet_name" {
  description = "The name of the target virtual network"
  type        = string
  default     = "Lab-ASR-Target-VNet"
}
variable "target_vnet_address_space" {
  description = "The address space of the target virtual network"
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "target_subnet_name" {
  description = "The name of the target subnet"
  type        = string
  default     = "default"
}

variable "target_subnet_address_prefixes" {
  description = "The address prefixes of the target subnet"
  type        = list(string)
  default     = ["10.1.0.0/24"]
}

### Recovery Services Vault ###

variable "rsv_name" {
  description = "The name of the Recovery Services Vault"
  type        = string
  default     = "tf-asr-vault"
}

variable "rsv_sku" {
  description = "The SKU of the Recovery Services Vault"
  type        = string
  default     = "Standard"
}

variable "rsv_storage_mode_type" {
  description = "The storage mode type of the Recovery Services Vault"
  type        = string
  default     = "LocallyRedundant"
}

### Cache Storage Account ###

variable "cache_storage_name" {
  description = "The name of the cache storage account"
  type        = string
  default     = "tfasrcachestorage"
}

variable "cache_storage_account_tier" {
  description = "The tier of the cache storage account"
  type        = string
  default     = "Standard"
}

variable "cache_storage_replication_type" {
  description = "The replication type of the cache storage account"
  type        = string
  default     = "LRS"
}

### Shared VM ###

variable "vm_admin_username" {
  description = "The admin username for the virtual machine"
  type        = string
}

variable "vm_admin_password" {
  description = "The admin password for the virtual machine"
  type        = string
  sensitive   = true
}

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
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

variable "windows_vm_os_disk_storage_account_type" {
  description = "The storage account type for the Windows VM OS disk"
  type        = string
  default     = "Standard_LRS"
}

### Enabling ASR stuff ###
variable "enable_replication" {
  description = "Flag to enable or disable ASR resources"
  type        = bool
  default     = false
}