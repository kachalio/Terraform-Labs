
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
  rbac_authorization_enabled = false
  public_network_access_enabled = true
  tags = var.tags

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

### Creates an authentication certificate
resource "azurerm_key_vault_certificate" "kv_cert" {
  name = "${var.project_appliance_name}${random_string.random.result}agentauthcert"
  # depends_on = [ module.migrate_project.azurerm_key_vault_access_policy.kvap ]
  key_vault_id = azurerm_key_vault.kv.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      subject            = "CN=AgentSpnCert"
      validity_in_months = 12
      key_usage          = ["cRLSign", "dataEncipherment", "digitalSignature", "keyEncipherment", "keyAgreement", "keyCertSign"]
    }
  }
}


### Creates the VMware Site.  
resource "azapi_resource" "vmwaresite" {
  schema_validation_enabled = false
  type                      = "Microsoft.OffAzure/VMwareSites@2020-07-10"
  name                      = "${local.name_prefix}site"
  parent_id                 = azurerm_resource_group.rg.id
  depends_on                = [azurerm_key_vault.kv]
  location                  = azapi_resource.migrate_project.location
  tags                      = { MigrateProject = azapi_resource.migrate_project.name }
  response_export_values    = ["properties.serviceEndpoint"]

  lifecycle {
    ignore_changes = [body]
  }

  body = {
    kind = "Migrate",
    properties = {
      agentDetails = {
        keyVaultId  = "${azurerm_key_vault.kv.id}",
        keyVaultUri = "${azurerm_key_vault.kv.vault_uri}"
      },
      applianceName       = "${var.project_appliance_name}",
      discoverySolutionId = azapi_resource.migrate_server_solutions["discovery"].id
    }
  }
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

locals {
  master_site_name = "${local.name_prefix}mastersite"
}

### Creates the MasterSite
resource "azapi_resource" "master_site" {
  schema_validation_enabled = false
  type                      = "Microsoft.OffAzure/MasterSites@2025-12-12-preview"
  name                      = local.master_site_name
  #   parent_id                 = azapi_resource.vmwaresite.id
  parent_id = azurerm_resource_group.rg.id
  location  = azapi_resource.migrate_project.location
  tags      = { MigrateProject = azapi_resource.migrate_project.name }

  body = {
    kind = "Migrate"
    properties = {
      sites = concat(
        [azapi_resource.vmwaresite.id],
        [for artifact in azapi_resource.appliance_artifacts : artifact.id],
        [azapi_resource.dependency_map.id]
      )
      allowMultipleSites = true
    }
  }

  lifecycle {
    # The post-creation update owns site membership after initial creation.
    ignore_changes = [body.properties.sites]
  }
}

### Creating an object to store details for the sites associated with the master site
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
  depends_on                = [azapi_resource.master_site]
  locks = [azapi_resource.master_site.id] # This prevents requests to the Mastersite while it is in a non terminal state (HTTP 409 errors)



  body = {
    kind = "Migrate"
    properties = {
      discoverySolutionId = azapi_resource.migrate_server_solutions["discovery"].id
      siteAppliancePropertiesCollection = [
        {
          agentDetails = {
            keyVaultId  = azurerm_key_vault.kv.id
            keyVaultUri = azurerm_key_vault.kv.vault_uri
          }
          applianceName = lower(var.project_appliance_name)
        }
      ]
    }
  }
}


### Creating an object to store details for the appliance artifacts associated with the project.
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

  body = {
    properties = {
    #   masterSiteId     = azapi_resource.master_site.id
      masterSiteId = "${azurerm_resource_group.rg.id}/providers/Microsoft.OffAzure/MasterSites/${local.master_site_name}"
      migrateProjectId = azapi_resource.migrate_project.id
    }
  }
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

### Data Replication Vault creation
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

### Link Project to Data Replication Vault
resource "azapi_resource" "link_project_to_data_replication_vault" {
  schema_validation_enabled = false
  type      = "Microsoft.Resources/links@2016-09-01"
  parent_id = azapi_resource.migrate_project.id
  name      = "projecttodatavaultlink"
  body = {
    properties = {
      notes    = ""
      targetId = "${azapi_resource.datareplication_vault.id}/"
    }
  }
}


### Register an Appliance Under A Master Site
resource "azapi_resource_action" "appliance_registration_info" {
  type                   = "Microsoft.OffAzure/MasterSites@2020-11-11-preview"
  resource_id            = azapi_resource.master_site.id
  action                 = "applianceRegistrationInfo"
  method                 = "POST"
  depends_on = [ azapi_resource.appliance_artifacts, azapi_resource.master_site_sites ]
  response_export_values = ["properties.appendedNonce"]

  body = {
    applianceName = var.project_appliance_name
  }
}

### Register tools in the project

resource "azapi_resource_action" "register_tools_in_project" {
  for_each               = azapi_resource.migrate_server_solutions
  type                   = "Microsoft.Migrate/migrateprojects@2020-06-01-preview"
  resource_id            = azapi_resource.migrate_project.id
  action                 = "registerTool"
  method                 = "POST"
  depends_on = [ azapi_resource_action.appliance_registration_info ]

  response_export_values = ["*"]
  body = {
    tool = each.value.body.properties.tool
  }
}

### Update Project Solutions

# This locals was made to store extended details for each tool used in the project
# These extended details can't be kept in the locals created for the resource creation because it will cause a circular dependency
# the update solution resource below loops through each of the migrate_server_solutions created in main.tf, then updates the extended details
# using the extended_details_by_tool local variable.
locals {
  update_solution_details_by_tool = {
    ServerAssessment = {
      extendedDetails = {
        projectId = azapi_resource.assessmentproject.id
      }
      status = "Active"

    }

    ServerDiscovery = {
      extendedDetails = {
        supportedScenarioSites     = "{\"SqlSites\":\"${azapi_resource.master_site_sites["sqlsites"].id}\",\"WebAppSites\":\"${azapi_resource.master_site_sites["webappsites"].id}\"}"
        keyVaultId                 = "${azurerm_key_vault.kv.id}"
        keyVaultUrl                = "${azurerm_key_vault.kv.vault_uri}"
        masterSiteId               = "${azapi_resource.master_site.id}"
        applianceNameToSiteIdMapV3 = "[{\"${var.project_appliance_name}\":{\"ApplianceName\":\"${var.project_appliance_name}\",\"SiteId\":\"${azapi_resource.vmwaresite.id}\",\"AadAppDetails\":{\"TenantID\":\"\",\"AppName\":\"\",\"AppID\":\"\",\"ObjectID\":\"\"},\"KeyVaultId\":\"${azurerm_key_vault.kv.id}\",\"KeyVaultUrl\":\"${azurerm_key_vault.kv.vault_uri}\",\"CertificateContents\":{\"${azurerm_key_vault_certificate.kv_cert.name}\":\"\"},\"supportAzStackTarget\":false}}]"
      }
      status = "Inactive"
    }

    ServerMigration = {
        extendedDetails = {
          vaultId = azurerm_recovery_services_vault.vault.id
        }
        status = "Active"
    }

    ServerMigration_DataReplication = {
      extendedDetails = {
        vaultId = azapi_resource.datareplication_vault.id
      }
      status = "Inactive"
    }
  }
}

# resource "azapi_update_resource" "update_vmwaresite" {
#   type        = azapi_resource.vmwaresite.type
#   resource_id = azapi_resource.vmwaresite.id
#   depends_on = [ azapi_resource.master_site ]
#   body = {
#     properties = {
#       masterSiteId = azapi_resource.master_site.id
#     }
#   }
# }

resource "azapi_update_resource" "update_solution" {
  for_each    = azapi_resource.migrate_server_solutions
  type        = each.value.type
  resource_id = each.value.id
  depends_on = [ azapi_resource_action.appliance_registration_info ]
  lifecycle {
    ignore_changes = [body]
  }

  body = {
    id   = each.value.id
    name = each.value.name
    properties = {
      tool         = each.value.body.properties.tool
      purpose      = each.value.body.properties.purpose
      goal         = each.value.body.properties.goal
      status       = local.update_solution_details_by_tool[each.value.body.properties.tool].status
      cleanupState = "None"
      summary = {
        instanceType      = "Servers"
        discoveredCount   = 0
        assessedCount     = 0
        replicatingCount  = 0
        testMigratedCount = 0
        migratedCount     = 0
      }
      details = {
        groupCount      = 0
        assessmentCount = 0
        extendedDetails = local.update_solution_details_by_tool[each.value.body.properties.tool].extendedDetails
      }
    }
  }
}