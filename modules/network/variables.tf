variable "rg_name" {
  description = "The name of the resource group to deploy the network resources into"
  type        = string
}

variable "rg_location" {
  description = "The location of the resource group"
  type        = string
}

variable "vnet_name" {
  description = "The name of the virtual network"
  type        = string
}

variable "vnet_address_space" {
  description = "The address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_name" {
  description = "The name of the subnet"
  type        = string
  default     = "default"
}

variable "subnet_address_prefixes" {
  description = "The address prefixes for the subnet"
  type        = list(string)
  default     = ["10.0.0.0/24"]
}


variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}