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

variable "create_nat_gateway" {
  description = "Whether to create a NAT gateway for the subnets"
  type        = bool
  default     = false
}

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

variable "security_rules_list" {
  description = "List of security rules for the target NSG"
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
  }))
  default = [
    {
      name                       = "AllowSSH"
      priority                   = 100
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    },
    {
      name                       = "AllowRDP"
      priority                   = 110
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "3389"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    },
    {
      name                       = "AllowStorage"
      priority                   = 120
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = "Storage"
    },
    {
      name                       = "AllowEntra"
      priority                   = 130
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = "AzureActiveDirectory"
    },
    {
      name                       = "AllowEventsHub"
      priority                   = 140
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = "EventHub"
    },
    {
      name                       = "AllowASR"
      priority                   = 150
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = "AzureSiteRecovery"
    },
    {
      name                       = "AllowGuestAndHybridManagement"
      priority                   = 160
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = "GuestAndHybridManagement"
    }
  ]
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

variable "create_public_ip" {
  description = "Whether to create and attach a public IP address to the VM"
  type        = bool
  default     = false
}

variable "secure_boot_enabled" {
  description = "Whether secure boot is enabled for the VMs"
  type        = bool
  default     = false
}

variable "vm_data_disk_configuration" {
  description = "Configuration for the data disk attached to the Windows VM"
  type = list(object({
    storage_account_type = string
    disk_size_gb         = number
  }))
  default = null
}


### Linux VM ###
# See variables_linux_vm.terraform 

### Windows VM ###
# See variables_windows_vm.terraform 

### Enabling ASR stuff ###
variable "enable_replication" {
  description = "Flag to enable or disable ASR resources"
  type        = bool
  default     = false
}