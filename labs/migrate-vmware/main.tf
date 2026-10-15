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

  tags = tomap({
    "MigrateProject" = var.migrate_project_name
  })
}

# Subscription details
data "azurerm_subscription" "primary" {}

# My account details
data "azurerm_client_config" "current" {}

resource "random_string" "migration_random_string" {
  length  = 4
  special = false
  upper   = false
  numeric = true
}

resource "random_string" "blob_random_string" {
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

  create_nat_gateway = false

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
  identity {
    type = "SystemAssigned"
  }
  

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
locals {

  migrate_solutions_type = "Microsoft.Migrate/migrateprojects/solutions"
  migrate_solutions_api_version = "@2020-06-01-preview"

  migrate_solutions = {
    assessment = {
      name = "Servers-Assessment-ServerAssessment"
      tool = "ServerAssessment"
      purpose = "Assessment"
      goal = "Servers"
      status = "Active"
      details = null
    }

    discovery = {
      name = "Servers-Discovery-ServerDiscovery"
      tool = "ServerDiscovery"
      purpose = "Discovery"
      goal = "Servers"
      status = "Inactive"
      details = {
        extendedDetails = {
          
        }
      }
    }

    migration = {
      name = "Servers-Migration-ServerMigration"
      tool = "ServerMigration"
      purpose = "Migration"
      goal = "Servers"
      status = "Active"
      details = null
    }

    datareplication = {
      name = "Servers-Migration-ServerMigration_DataReplication"
      tool = "ServerMigration_DataReplication"
      purpose = "Migration"
      goal = "Servers"
      status = "Inactive"
      details = null
    }

  }
}

resource "azapi_resource" "migrate_server_solutions" {
  for_each = local.migrate_solutions

  schema_validation_enabled = false
  type = "${local.migrate_solutions_type}${local.migrate_solutions_api_version}"
  name = "${each.value.name}"
  parent_id = azapi_resource.migrate_project.id
  depends_on = [ module.source_network ]

  body = {
    properties = {
      "tool" = each.value.tool
      "purpose" = each.value.purpose
      "goal" = each.value.goal
      "status" = each.value.status
      "details" = each.value.details
    }
  }
}

