terraform {
  required_providers {
    azapi = {
      source = "Azure/azapi"
    }
  }
}

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
  migrate_solutions_api_version = "@2023-01-01"
  tags = tomap({
    "MigrateProject" = var.migrate_project_name
  })
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

  rg_name     = azurerm_resource_group.rg.name
  rg_location = azurerm_resource_group.rg.location

  vnet_name          = var.source_vnet_name
  vnet_address_space = var.source_vnet_address_space

  security_rules_list = var.security_rules_list

  subnet_name             = var.source_subnet_name
  subnet_address_prefixes = var.source_subnet_address_prefixes

  tags = merge(
    local.tags,
    {
    "DeployedByTerraform" = "YouBetcha"
    }
  )
}

### Migrate Project ###
resource "azapi_resource" "migrate_project" {
  schema_validation_enabled = false
  type      = "Microsoft.Migrate/migrateProjects@2020-05-01"
  name      = var.migrate_project_name
  parent_id = azurerm_resource_group.rg.id
  location  = azurerm_resource_group.rg.location

  body = {
    properties = {
      publicNetworkAccess = "Enabled" 
    } 
  }

  tags = ({
     "Migrate Project" = var.migrate_project_name
  })

  
}

### Migrate Project Solutions ###
resource "azapi_resource" "server_assessment_solution" {
  schema_validation_enabled = false
  type = "${local.migrate_solutions_type}${local.migrate_solutions_api_version}"
  name = "${azapi_resource.migrate_project.name}/Servers-Assessment-ServerAssessment"
  parent_id = azapi_resource.migrate_project.id
  # depends_on = [  ]

  body = {
    properties = {
      "tool" = "ServerAssessment"
      "purpose" = "Assessment"
      "goal" = "Servers"
      "status" = "Active"
      "details" = null
    }
  }
}

resource "azapi_resource" "server_discovery_solution" {
  schema_validation_enabled = false
  type = "${local.migrate_solutions_type}${local.migrate_solutions_api_version}"
  name = "${azapi_resource.migrate_project.name}/Servers-Discovery-ServerDiscovery"
  parent_id = azapi_resource.server_assessment_solution.id
  # depends_on = [  ]

  body = {
    properties = {
      "tool" = "ServerDiscovery"
      "purpose" = "Discovery"
      "goal" = "Servers"
      "status" = "Inactive"
      "details" = null
    }
  }
}

resource "azapi_resource" "server_migration_solution" {
  schema_validation_enabled = false
  type = "${local.migrate_solutions_type}${local.migrate_solutions_api_version}"
  name = "${azapi_resource.migrate_project.name}/Servers-Migration-ServerMigration"
  parent_id = azapi_resource.server_discovery_solution.id
  # depends_on = [  ]

  body = {
    properties = {
      "tool" = "ServerMigration"
      "purpose" = "Migration"
      "goal" = "Servers"
      "status" = "Active"
      "details" = null
    }
  }
}

resource "azapi_resource" "server_datareplication_solution" {
  schema_validation_enabled = false
  type = "${local.migrate_solutions_type}${local.migrate_solutions_api_version}"
  name = "${azapi_resource.migrate_project.name}/Servers-Migration-ServerMigration"
  parent_id = azapi_resource.server_migration_solution.id
  # depends_on = [  ]

  body = {
    properties = {
      "tool" = "ServerMigration_DataReplication"
      "purpose" = "Migration"
      "goal" = "Servers"
      "status" = "Inactive"
      "details" = null
    }
  }
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
  
  tags = merge(
    local.tags,
    {
      "DeployedByTerraform" = "YouBetcha"
    }
  )
  
}


### Private Endpoint Stuff ###

resource "azurerm_private_dns_zone" "private_zone" {
  name = "privatelink.prod.migration.windowsazure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "private_zone_link" {
  name = "privatelink.prod.migration.windowsazure.com/${module.source_network.vnet_name}${random_string.random_string.result}vnetlink"
  private_dns_zone_id = azurerm_private_dns_zone.private_zone.id
  virtual_network_id = module.source_network.vnet_id
}


resource "azurerm_private_endpoint" "pe" {
  name = "${azapi_resource.migrate_project.name}${random_string.random_string.result}pe"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  subnet_id = module.source_network.subnet_id
  
  private_service_connection {
    name = "${azapi_resource.migrate_project.name}${random_string.random_string.result}pe"
    is_manual_connection = false
    private_connection_resource_id = azapi_resource.migrate_project.id
  }

  private_dns_zone_group {
    name = "${azapi_resource.migrate_project.name}${random_string.random_string.result}pe/${azapi_resource.migrate_project.name}${random_string.random_string.result}dnszonegroup"
    private_dns_zone_ids = []
  }
  
  tags = merge(
    local.tags,
    {
      "DeployedByTerraform" = "YouBetcha"
    }
  )
  
}



