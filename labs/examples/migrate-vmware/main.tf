module "lab" {
  source = "../../modules/labs/migrate-vmware"

  resource_group_name            = var.resource_group_name
  resource_group_location        = var.resource_group_location
  source_vnet_name               = var.source_vnet_name
  source_vnet_address_space      = var.source_vnet_address_space
  source_subnet_name             = var.source_subnet_name
  source_subnet_address_prefixes = var.source_subnet_address_prefixes
  security_rules_list            = var.security_rules_list
  migrate_project_name           = var.migrate_project_name
}
