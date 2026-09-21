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

data "azurerm_subscription" "primary" {
}

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


### Storage Account ###

resource "azurerm_storage_account" "migrate_storage_account" {
  name = "${azapi_resource.migrate_project.name}${random_string.blob_random_string.result}usa"

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

resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  scope = data.azurerm_subscription.primary.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id = azapi_resource.migrate_project.identity[0].principal_id
}

resource "azurerm_role_assignment" "azure_migrate_service_reader" {
  scope = data.azurerm_subscription.primary.id
  role_definition_name = "Azure Migrate Service Reader"
  principal_id = azapi_resource.migrate_project.identity[0].principal_id
}

### Migration Private Endpoint Stuff ###

resource "azurerm_private_dns_zone" "migration_private_zone" {
  name = "privatelink.prod.migration.windowsazure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "migration_private_zone_link" {
  name = "${module.source_network.vnet_name}${random_string.migration_random_string.result}vnetlink"
  private_dns_zone_id = azurerm_private_dns_zone.migration_private_zone.id
  virtual_network_id = module.source_network.vnet_id

}

# Using this locals here to create the pe name so the same object can be reused
locals {
  migration_pe_name = "${azapi_resource.migrate_project.name}${random_string.migration_random_string.result}pe"
}

resource "azurerm_private_endpoint" "migration_pe" {
  name = local.migration_pe_name
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id = module.source_network.subnet_id
  depends_on = [ azurerm_private_dns_zone.migration_private_zone ]
  
  private_service_connection {
    name = "${azapi_resource.migrate_project.name}${random_string.migration_random_string.result}pe"
    is_manual_connection = false
    private_connection_resource_id = azapi_resource.migrate_project.id
    subresource_names = ["Default"]
  }

  private_dns_zone_group {
    name = "${azapi_resource.migrate_project.name}${random_string.migration_random_string.result}dnszonegroup"
    private_dns_zone_ids = []
  }
  
  tags = merge(
    local.tags,
    {
      "DeployedByTerraform" = "YouBetcha"
    }
  )
  
}


### Blob Private Endpoint Stuff ###

resource "azurerm_private_dns_zone" "blob_private_zone" {
  name = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_private_zone_link" {
  name = "${module.source_network.vnet_name}${random_string.blob_random_string.result}vnetlink"
  private_dns_zone_id = azurerm_private_dns_zone.blob_private_zone.id
  virtual_network_id = module.source_network.vnet_id
}

# Using this locals here to create the pe name so the same object can be reused
locals {
  blob_pe_name = "${azapi_resource.migrate_project.name}${random_string.blob_random_string.result}pe"
}

resource "azurerm_private_endpoint" "blob_pe" {
  name = local.blob_pe_name
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id = module.source_network.subnet_id
  depends_on = [ azurerm_private_dns_zone.blob_private_zone ]
  
  private_service_connection {
    name = "${azapi_resource.migrate_project.name}${random_string.blob_random_string.result}pe"
    is_manual_connection = false
    private_connection_resource_id = azurerm_storage_account.migrate_storage_account.id
    subresource_names = ["blob"]
  }

  private_dns_zone_group {
    name = "${azapi_resource.migrate_project.name}${random_string.blob_random_string.result}dnszonegroup"
    private_dns_zone_ids = []
  }
  
  tags = merge(
    local.tags,
    {
      "DeployedByTerraform" = "YouBetcha"
    }
  )
  
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
          privateEndpointDetails = "{\"subnetId\":\"${module.source_network.subnet_id}\",\"virtualNetworkLocation\":\"${azurerm_resource_group.rg.location}\",\"skipPrivateDnsZoneCreation\":false}"
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

/*



*/