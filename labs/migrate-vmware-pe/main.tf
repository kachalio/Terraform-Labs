provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azapi" {
  
}

locals {
  migrate_solutions_type = "Microsoft.Migrate/MigrateProjects/Solutions"
  migrate_solutions_api_version = "2020-06-01-preview"
}

resource "random_string" "random_string" {
  length  = 4
  special = false
  upper   = false
  numeric = true
}

# Resource Group for project
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

### Network Stuff ###
module "source_network" {
  source = "../../modules/network"

  rg_name     = azurerm_resource_group.source_rg.name
  rg_location = azurerm_resource_group.source_rg.location

  vnet_name          = var.source_vnet_name
  vnet_address_space = var.source_vnet_address_space

  security_rules_list = var.security_rules_list

  subnet_name             = var.source_subnet_name
  subnet_address_prefixes = var.source_subnet_address_prefixes

  tags = {
    "DeployedByTerraform" = "YouBetcha"
  }
}

### Migrate Project ###
resource "azapi_resource" "migrate_project" {

  type      = "Microsoft.Migrate/migrateProjects@2020-06-01-preview"
  name      = var.migrate_project_name
  parent_id = azurerm_resource_group.id
  location  = azurerm_resource_group.rg.location

  body = jsonencode({
    properties = {
      publicNetworkAccess = true
    }
  })

  tags = ({
     "Migrate Project" = var.migrate_project_name
  })
}

### Migrate Project Solutions ###
resource "azapi_resource" "server_assessment_solution" {
  type = "${local.migrate_solutions_type}${local.migrate_solutions_api_version}"
  name = "${azapi_resource.migrate_project.name}/Servers-Assessment-ServerAssessment"
  parent_id = azapi_resource.migrate_project.id
  # depends_on = [  ]

  body = jsonencode({
    properties = {
      "tool" = "ServerAssessment"
      "purpose" = "Assessment"
      "goal" = "Servers"
      "Status" = "Active"
      "details" = null
    }
  })
}

resource "azapi_resource" "server_discovery_solution" {
  type = "${local.migrate_solutions_type}${local.migrate_solutions_api_version}"
  name = "${azapi_resource.migrate_project.name}/Servers-Discovery-ServerDiscovery"
  parent_id = azapi_resource.server_assessment_solution.id
  # depends_on = [  ]

  body = jsonencode({
    properties = {
      "tool" = "ServerDiscovery"
      "purpose" = "Discovery"
      "goal" = "Servers"
      "Status" = "Inactive"
      "details" = null
    }
  })
}

resource "azapi_resource" "server_migration_solution" {
  type = "${local.migrate_solutions_type}${local.migrate_solutions_api_version}"
  name = "${azapi_resource.migrate_project.name}/Servers-Migration-ServerMigration"
  parent_id = azapi_resource.server_discovery_solution.id
  # depends_on = [  ]

  body = jsonencode({
    properties = {
      "tool" = "ServerMigration"
      "purpose" = "Migration"
      "goal" = "Servers"
      "Status" = "Active"
      "details" = null
    }
  })
}

resource "azapi_resource" "server_datareplication_solution" {
  type = "${local.migrate_solutions_type}${local.migrate_solutions_api_version}"
  name = "${azapi_resource.migrate_project.name}/Servers-Migration-ServerMigration"
  parent_id = azapi_resource.server_migration_solution.id
  # depends_on = [  ]

  body = jsonencode({
    properties = {
      "tool" = "ServerMigration_DataReplication"
      "purpose" = "Migration"
      "goal" = "Servers"
      "Status" = "Inactive"
      "details" = null
    }
  })
}

### Storage Account ###

resource "azurerm_storage_account" "migrate_storage_account" {
  name = "${azapi_resource.migrate_project.name}${random_string.random_string.result}usa"

  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  account_replication_type = "LRS"
  account_tier = "Standard"
  account_kind = "StorageV2"
  access_tier = "Hot"
  min_tls_version = "TLS1_2"
  https_traffic_only_enabled = true
  
}


### Private Endpoint Stuff ###

