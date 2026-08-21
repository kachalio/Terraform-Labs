
variable "rsv_name" {
  description = "The name of the Recovery Services Vault"
  type        = string
}

variable "source_location" {
  description = "The primary location of the Recovery Services Vault"
  type        = string
}

variable "source_resource_group_name" {
  description = "The primary resource group name of the Recovery Services Vault"
  type        = string
}

variable "target_location" {
  description = "The secondary location of the Recovery Services Vault"
  type        = string
}

variable "target_resource_group_name" {
  description = "The secondary resource group name of the Recovery Services Vault"
  type        = string
}

variable "source_network_id" {
  description = "The primary network ID of the Recovery Services Vault"
  type        = string
}

variable "target_network_id" {
  description = "The secondary network ID of the Recovery Services Vault"
  type        = string
}
