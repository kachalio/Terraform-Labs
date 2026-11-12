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

output "appliance_ip" {
  value = module.appliance.server_ip
}

output "server_name" {
  value = module.appliance.server_name
}

# # This is the appliance registration key used for registering your appliance with the migration project
output "appliance_registration_key" {
  value = join(";",
    [
      var.project_appliance_name,
      "PROD",
      data.azurerm_client_config.current.tenant_id,
      data.azurerm_client_config.current.subscription_id,
      azurerm_resource_group.rg.name,
      azapi_resource.migrate_project.name,
      azapi_resource_action.appliance_registration_info.output.properties.appendedNonce,      
      azapi_resource.vmwaresite.output.properties.serviceEndpoint,
      azapi_resource.migrate_project.location,
      "false"
    ]
  )
}

output "appliance_registration_info" {
  value = azapi_resource_action.appliance_registration_info.output
}