output "resource_group_id" {
  value = azurerm_resource_group.rg.id
}

output "migrate_project_id" {
  value = azapi_resource.migrate_project.id
}

output "migrate_project_name" {
  value = azapi_resource.migrate_project.name
}

output "vnet_id" {
  value = module.source_network.vnet_id
}

output "subnet_id" {
  value = module.source_network.subnet_id
}

output "storage_account_id" {
  value = azurerm_storage_account.migrate_storage_account.id
}

output "migration_private_endpoint_id" {
  value = azurerm_private_endpoint.migration_pe.id
}

output "blob_private_endpoint_id" {
  value = azurerm_private_endpoint.blob_pe.id
}