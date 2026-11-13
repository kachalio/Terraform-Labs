###
### This configuration deployes the following resources:
### - Azure Migrate Project
### - Azure Migrate Project Solutions (Assessment, Discovery, Migration, Data Replication)
### - VMware Server Appliance Deployment
###

locals {

  tags = tomap({
    "MigrateProject" = var.migrate_project_name
  })
}

# Subscription details
data "azurerm_subscription" "primary" {}

# My account details
data "azurerm_client_config" "current" {}

# Resource Group for project
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

### Network Stuff ###
module "source_network" {
  source = "../../network"

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
  type                      = "Microsoft.Migrate/MigrateProjects@2020-05-01"
  name                      = var.migrate_project_name
  parent_id                 = azurerm_resource_group.rg.id
  location                  = azurerm_resource_group.rg.location
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

  migrate_solutions_type        = "Microsoft.Migrate/MigrateProjects/Solutions"
  migrate_solutions_api_version = "@2020-06-01-preview"

  migrate_solutions = {
    assessment = {
      name    = "Servers-Assessment-ServerAssessment"
      tool    = "ServerAssessment"
      purpose = "Assessment"
      goal    = "Servers"
      status  = "Active"
      details = null
    }

    discovery = {
      name    = "Servers-Discovery-ServerDiscovery"
      tool    = "ServerDiscovery"
      purpose = "Discovery"
      goal    = "Servers"
      status  = "Inactive"
      details = {
        extendedDetails = {

        }
      }
    }

    migration = {
      name    = "Servers-Migration-ServerMigration"
      tool    = "ServerMigration"
      purpose = "Migration"
      goal    = "Servers"
      status  = "Active"
      details = null
    }

    datareplication = {
      name    = "Servers-Migration-ServerMigration_DataReplication"
      tool    = "ServerMigration_DataReplication"
      purpose = "Migration"
      goal    = "Servers"
      status  = "Inactive"
      details = null
    }
  }
}

resource "azapi_resource" "migrate_server_solutions" {
  for_each = local.migrate_solutions

  schema_validation_enabled = false
  type                      = "${local.migrate_solutions_type}${local.migrate_solutions_api_version}"
  name                      = each.value.name
  parent_id                 = azapi_resource.migrate_project.id
  depends_on                = [module.source_network]
  # Ignore changes to the body of the resource.  This is updated later, and those changes should be preserved.
  lifecycle {
    ignore_changes = [body]
  }


  body = {
    properties = {
      "tool"    = each.value.tool
      "purpose" = each.value.purpose
      "goal"    = each.value.goal
      "status"  = each.value.status
      "details" = each.value.details
    }
  }
}


### VMware Server Appliance Deployment ###

module "appliance" {
  source = "../../vm_vmware_clone"

  # count = var.deploy_appliance ? 1 : 0

  vsphere_user            = var.vsphere_user
  vsphere_password        = var.vsphere_password
  vsphere_server          = var.vsphere_server
  vsphere_datacenter      = var.vsphere_datacenter
  vsphere_datastore       = var.vsphere_datastore
  vsphere_compute_cluster = var.vsphere_compute_cluster
  vsphere_network         = var.vsphere_network
  vsphere_template        = var.vsphere_template
  vsphere_resource_pool   = var.vsphere_resource_pool
  vsphere_folder          = var.vsphere_folder
  vm_name                 = var.vm_name
  vm_hostname             = var.vm_hostname
  vm_admin_password       = var.vm_admin_password
  vm_num_cpus             = var.vm_num_cpus
  vm_memory               = var.vm_memory
  vm_firmware             = var.vm_firmware
  vm_network_adapter_type = var.vm_network_adapter_type
  vm_disk_size            = var.vm_disk_size
  vm_thin_provisioned     = var.vm_thin_provisioned
  vm_data_disks           = var.vm_data_disks
}