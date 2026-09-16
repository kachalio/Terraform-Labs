### Resource Group ###
variable "source_rg_name" {
  description = "The name of the source resource group"
  type        = string
  default     = "Lab-Backup-HANA"
}

variable "source_location" {
  description = "The region of the source resource group"
  type        = string
  default     = "eastus2"
}

### Virtual Network ###

variable "source_vnet_name" {
  description = "The name of the source virtual network"
  type        = string
  default     = "Lab-Backup-HANA-VNet"
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
    }
  ]
}

### Recovery Services Vault ###

variable "rsv_name" {
  description = "The name of the Recovery Services Vault"
  type        = string
  default     = "backup-hana"
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
  description = "The size of the virtual machine.  You will need a SKU with more than 8 GBs of Memory for HANA instances"
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
    publisher = "SUSE"
    offer     = "sles-15-sp5"
    sku       = "gen2"
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


### HANA Stuff ###
variable "hana_master_password" {
  description = "The master password for the SAP HANA instance"
  type        = string
  sensitive   = true
}