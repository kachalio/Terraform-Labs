
### Create the keyvault used for authentication

# Depends on: Keyvault, VMwareSite, Dependency Map maps, MasterSite (which also depends on a bunch of things), SQLsites,

resource "random_string" "random" {
  length  = 4 #Probably will need to update this
  upper   = false
  special = false
}

locals {
  name_prefix = "${azapi_resource.migrate_project.name}${random_string.random.result}"
}


### Key Vault creation
resource "azurerm_key_vault" "kv" {
  name                       = "${local.name_prefix}kv"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Backup", "Create", "Decrypt", "Delete", "Encrypt", "Get", "Import", "List", "Purge", "Recover", "Restore", "Sign", "UnwrapKey", "Update", "Verify", "WrapKey"
    ]

    secret_permissions = [
      "Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set"
    ]

    storage_permissions = [
      "Backup", "Delete", "DeleteSAS", "Get", "GetSAS", "List", "ListSAS", "Purge", "Recover", "RegenerateKey", "Restore", "Set", "SetSAS", "Update"
    ]

    certificate_permissions = [
      "Backup", "Create", "Delete", "DeleteIssuers", "Get", "GetIssuers", "Import", "List", "ListIssuers", "ManageContacts", "ManageIssuers", "Purge", "Recover", "Restore", "SetIssuers", "Update", "Purge"
    ]
  }
}



### Creates the VMware Site.  This is also what creates the appliance object.
resource "azapi_resource" "vmwaresite" {
  schema_validation_enabled = false
  type                      = "Microsoft.OffAzure/VMwareSites@2020-07-10"
  name                      = "${local.name_prefix}site"
  parent_id                 = azurerm_resource_group.rg.id
  depends_on                = [azurerm_key_vault.kv]
  location                  = azapi_resource.migrate_project.location
  tags                      = { MigrateProject = azapi_resource.migrate_project.name }
  response_export_values    = ["*"]

  body = jsonencode({
    kind = "Migrate",
    properties = {
      agentDetails = {
        keyVaultId  = "${azurerm_key_vault.kv.id}",
        keyVaultUri = "${azurerm_key_vault.kv.vault_uri}"
      },
      applianceName = "${var.project_appliance_name}",
      # discoverySolutionId = jsondecode(azapi_resource_action.put_server_discovery.output).id
      discoverySolutionId = azapi_resource.migrate_server_solutions["discovery"].id
    }
  })
}


### Creates the Dependency Maps/maps 
resource "azapi_resource" "dependency_map" {
  schema_validation_enabled = false
  type                      = "Microsoft.DependencyMap/maps@2025-05-01-preview"
  name                      = "${local.name_prefix}depmap"
  parent_id                 = azurerm_resource_group.rg.id
  location                  = azapi_resource.migrate_project.location
  #   tags                   = { MigrateProject = azapi_resource.migrate_project.name }
  #   response_export_values = ["*"]

  body = {
    properties = {}
  }
}

resource "azapi_resource" "dependency_map_discovery_sources" {
  schema_validation_enabled = false
  type                      = "Microsoft.DependencyMap/maps/discoverySources@2025-05-01-preview"
  #   name                   = "${azapi_resource.dependency_map.name}/${var.project_appliance_name}${random_string.suffix.result}src"
  name      = "${var.project_appliance_name}${random_string.random.result}src"
  parent_id = azapi_resource.dependency_map.id
  location  = azapi_resource.migrate_project.location
  tags      = { MigrateProject = azapi_resource.migrate_project.name }

  body = {
    properties = {
      sourceType = "OffAzure"
      sourceId   = azapi_resource.vmwaresite.id
    }
  }
}

### Creates the MasterSite
resource "azapi_resource" "master_site" {
  schema_validation_enabled = false
  type                      = "Microsoft.OffAzure/VMwareSites/masterSites@2025-12-12-preview"
  name                      = "${local.name_prefix}mastersite"
  parent_id                 = azurerm_resource_group.rg.id
  location                  = azapi_resource.migrate_project.location
  tags                      = { MigrateProject = azapi_resource.migrate_project.name }
}

locals {
  master_site_sites = [
    {
      name        = "sqlsites"
      type        = "Microsoft.OffAzure/MasterSites/SqlSites"
      api-version = "2022-10-27"
    },
    {
      name        = "webappsites"
      type        = "Microsoft.OffAzure/MasterSites/WebAppSites"
      api-version = "2020-11-11-preview"
    },
  ]
}

### Creates  the sites inside the master site
resource "azapi_resource" "master_site_sites" {
  for_each                  = { for site in local.master_site_sites : site.name => site }
  schema_validation_enabled = false
  type                      = "${each.value.type}@${each.value.api-version}"
  name                      = "${local.name_prefix}${each.value.name}"
  parent_id                 = azapi_resource.master_site.id
  location                  = azapi_resource.migrate_project.location
  tags                      = { MigrateProject = azapi_resource.migrate_project.name }
  depends_on                = [azapi_resource.master_site]
  response_export_values    = ["*"]


  body = jsonencode({
    kind = "Migrate"
    properties = {
      discovery_solution_id = azapi_resource.migrate_server_solutions["discovery"].id
      siteAppliancePropertiesCollection = [
        {
          agentDetails = {
            keyVaultId  = azurerm_key_vault.kv.id
            keyVaultUri = azurerm_key_vault.kv.vault_uri
          }
          appliancename = var.project_appliance_name
        }
      ]
    }
  })
}

locals {
  appliance_artifacts = [
    {
      name        = "mysql"
      type        = "Microsoft.MySqlDiscovery/mysqlsites"
      api-version = "2025-03-30-preview"
    },
    {
      name        = "pgsql"
      type        = "Microsoft.ApplicationMigration/PGSQLSites"
      api-version = "2025-02-01-preview"
    },
    {
      name        = "mongo"
      type        = "Microsoft.ApplicationMigration/MongoSites"
      api-version = "2025-02-01-preview"
    },
    {
      name        = "oracle"
      type        = "Microsoft.ApplicationMigration/oracleSites"
      api-version = "2026-02-01-preview"
    },
    {
      name        = "storage"
      type        = "Microsoft.ApplicationMigration/StorageSites"
      api-version = "2025-02-01-preview"
    }
  ]
}

### Creates each of the appliance artifacts as shown in the locals variable above
resource "azapi_resource" "appliance_artifacts" {
  for_each                  = { for artifact in local.appliance_artifacts : artifact.name => artifact }
  schema_validation_enabled = false
  type                      = "${each.value.type}@${each.value.api-version}"
  name                      = "${local.name_prefix}${each.value.name}"
  parent_id                 = azurerm_resource_group.rg.id
  location                  = azapi_resource.migrate_project.location
  tags                      = { MigrateProject = azapi_resource.migrate_project.name }

  body = jsonencode({
    properties = {
      masterSiteId = azapi_resource.master_site.id
    }
  })
}



### Creates the Assessment Project

resource "azapi_resource" "assessmentproject" {
  schema_validation_enabled = false
  type                      = "Microsoft.Migrate/assessmentProjects@2020-05-01-preview"
  name                      = "${var.project_appliance_name}${random_string.random.result}project"
  location                  = azapi_resource.migrate_project.location
  depends_on                = []
  tags                      = { MigrateProject = azapi_resource.migrate_project.name }
  parent_id                 = azurerm_resource_group.rg.id
  response_export_values    = ["*"]

  body = {
    kind = "Migrate"
    properties = {
      projectStatus        = "Active"
      assessmentSolutionId = azapi_resource.migrate_server_solutions["assessment"].id
    }
  }
}

### Vault Creation

resource "azurerm_recovery_services_vault" "vault" {
  name                = "${var.project_appliance_name}${random_string.random.result}vault"
  location            = azapi_resource.migrate_project.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  tags                = { MigrateProject = azapi_resource.migrate_project.name }
  identity {
    type = "SystemAssigned"
  }
}

resource "azapi_resource" "datareplication_vault" {
  schema_validation_enabled = false
  type                      = "Microsoft.DataReplication/replicationVaults@2026-05-01"
  name                      = "${azapi_resource.migrate_project.name}${random_string.random.result}replicationvault"
  location                  = azapi_resource.migrate_project.location
  parent_id                 = azurerm_resource_group.rg.id
  tags                      = { MigrateProject = azapi_resource.migrate_project.name }
  identity {
    type = "SystemAssigned"
  }
  body = {
    properties = { vaultType = "Migrate" }
  }
}

