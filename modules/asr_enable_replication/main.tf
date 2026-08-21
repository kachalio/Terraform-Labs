
resource "azurerm_site_recovery_fabric" "source" {
  name                = "asr-a2a-default-${var.source_location}"
  location            = var.source_location
  recovery_vault_name = var.rsv_name
  resource_group_name = var.source_resource_group_name
}

resource "azurerm_site_recovery_fabric" "target" {
  name                = "asr-a2a-default-${var.target_location}"
  location            = var.target_location
  recovery_vault_name = var.rsv_name
  resource_group_name = var.target_resource_group_name
}

resource "azurerm_site_recovery_protection_container" "source" {
  name                 = "asr-a2a-default-${var.source_location}-container"
  recovery_vault_name  = var.rsv_name
  resource_group_name  = var.source_resource_group_name
  recovery_fabric_name = azurerm_site_recovery_fabric.source.name
}

resource "azurerm_site_recovery_protection_container" "target" {
  name                 = "asr-a2a-default-${var.target_location}-container"
  recovery_vault_name  = var.rsv_name
  resource_group_name  = var.target_resource_group_name
  recovery_fabric_name = azurerm_site_recovery_fabric.target.name
}

resource "azurerm_site_recovery_replication_policy" "policy" {
  name                                                 = "replication-policy"
  resource_group_name                                  = var.target_resource_group_name
  recovery_vault_name                                  = var.rsv_name
  recovery_point_retention_in_minutes                  = 24 * 60
  application_consistent_snapshot_frequency_in_minutes = 1 * 60

}

resource "azurerm_site_recovery_protection_container_mapping" "mapping" {
  name                                      = "mapping"
  resource_group_name                       = var.target_resource_group_name
  recovery_vault_name                       = var.rsv_name
  recovery_fabric_name                      = azurerm_site_recovery_fabric.source.name
  recovery_source_protection_container_name = azurerm_site_recovery_protection_container.source.id
  recovery_target_protection_container_id   = azurerm_site_recovery_protection_container.target.id
  recovery_replication_policy_id            = azurerm_site_recovery_replication_policy.policy.id
}

resource "azurerm_site_recovery_network_mapping" "network-mapping" {
  name                        = "network-mapping"
  resource_group_name         = var.target_resource_group_name
  recovery_vault_name         = var.rsv_name
  source_recovery_fabric_name = azurerm_site_recovery_fabric.source.name
  target_recovery_fabric_name = azurerm_site_recovery_fabric.target.name
  source_network_id           = var.source_network_id
  target_network_id           = var.target_network_id
}