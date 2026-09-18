variable "resource_group_name" {
  description = "The Resource Group where your project will be deployed."
  type        = string
  default     = "Lab-Migrate-PE"
}

variable "resource_group_location" {
  description = "The location of your resource group and project resources (unless specified otherwise)"
  type        = string
  default     = "centralus"
  validation {
    condition = contains([
      "southafricanorth",
      "eastasia",
      "australiaeast",
      "australiasoutheast",
      "brazilsouth",
      "canadacentral",
      "canadaeast",
      "northeurope",
      "westeurope",
      "francecentral",
      "germanywestcentral",
      "centralindia",
      "southindia",
      "italynorth",
      "japaneast",
      "japanwest",
      "jioindiawest",
      "koreacentral",
      "norwayeast",
      "swedencentral",
      "switzerlandnorth",
      "uaenorth",
      "uksouth",
      "ukwest",
      "centralus",
      "westus2"
    ], var.resource_group_location)
    error_message = "You must select a region supported by Azure Migrate"
  }
}

### Virtual Network ###

variable "source_vnet_name" {
  description = "The name of the source virtual network"
  type        = string
  default     = "Lab-Migrate-VNet"
}

variable "source_vnet_address_space" {
  description = "The address space of the source virtual network"
  type        = list(string)
  default     = ["10.20.0.0/16"]
}

variable "source_subnet_name" {
  description = "The name of the source subnet"
  type        = string
  default     = "default"
}

variable "source_subnet_address_prefixes" {
  description = "The address prefixes of the source subnet"
  type        = list(string)
  default     = ["10.20.0.0/24"]
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
    }
  ]
}

### Project variables

variable "migrate_project_name" {
  description = "the name of the migrate project"
  type        = string

}