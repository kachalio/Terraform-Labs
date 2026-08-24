
output "source_container_name" {
  value = azurerm_site_recovery_protection_container.source.name
}

output "source_recovery_fabric_name" {
  value = azurerm_site_recovery_fabric.source.name
}

output "target_recovery_fabric_id" {
  value = azurerm_site_recovery_fabric.target.id
}

output "target_recovery_protection_container_id" {
  value = azurerm_site_recovery_protection_container.target.id
}

output "azurerm_site_recovery_replication_policy_id" {
  value = azurerm_site_recovery_replication_policy.policy.id
}