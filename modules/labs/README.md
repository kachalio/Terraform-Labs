# Reusable Lab Modules

Each subdirectory is a reusable Terraform child module. Configure providers in
your deployment root and reference a lab with a `module` block. Do not run
`terraform apply` from these module directories.

The [deployment roots](../../labs/examples/) are thin wrappers for direct use. Keep each
deployment's variable files and state in its root, not in the reusable module.
These configurations target fresh deployments and do not migrate state from the
previous lab layout. Use new deployment state and distinct resource names
instead of reusing a pre-refactor lab deployment.

## Available Modules

| Module | Required inputs | Input reference | Output reference | Variable template |
| --- | --- | --- | --- | --- |
| `a2a` | `vm_admin_username`, `vm_admin_password` | [variables.tf](a2a/variables.tf) | [outputs.tf](a2a/outputs.tf) | [terraform.tfvars.example](../../labs/examples/a2a/terraform.tfvars.example) |
| `backup-saphana` | `vm_admin_username`, `vm_admin_password`, `hana_master_password` | [variables.tf](backup-saphana/variables.tf) | [outputs.tf](backup-saphana/outputs.tf) | [terraform.tfvars.example](../../labs/examples/backup-saphana/terraform.tfvars.example) |
| `backup-sql` | `vm_admin_username`, `vm_admin_password` | [variables.tf](backup-sql/variables.tf) | [outputs.tf](backup-sql/outputs.tf) | [terraform.tfvars.example](../../labs/examples/backup-sql/terraform.tfvars.example) |
| `backup-vm` | `vm_admin_username`, `vm_admin_password` | [variables.tf](backup-vm/variables.tf) | [outputs.tf](backup-vm/outputs.tf) | [terraform.tfvars.example](../../labs/examples/backup-vm/terraform.tfvars.example) |
| `migrate-vmware` | `migrate_project_name` | [variables.tf](migrate-vmware/variables.tf) | [outputs.tf](migrate-vmware/outputs.tf) | [terraform.tfvars.example](../../labs/examples/migrate-vmware/terraform.tfvars.example) |
| `migrate-vmware-pe` | `migrate_project_name` | [variables.tf](migrate-vmware-pe/variables.tf) | [outputs.tf](migrate-vmware-pe/outputs.tf) | [terraform.tfvars.example](../../labs/examples/migrate-vmware-pe/terraform.tfvars.example) |

Copy the selected template to `terraform.tfvars` in your deployment root, edit
required non-secret inputs, and uncomment optional settings to override defaults.
Supply sensitive inputs using the indicated `TF_VAR_*` environment variables.
The `.example` suffix prevents automatic loading; the copied working file is
ignored by Git. Child modules do not load variable files: your root must declare
and forward the inputs it uses. Keep templates aligned with their variable
definitions when adding or changing inputs.

Terraform 1.1 or later is required. AzureRM is required by
all labs. SQL backup and both Migrate labs also require `azure/azapi`; the Migrate
labs require `hashicorp/random`. Provider configurations belong to the caller;
the child modules only declare provider requirements. This allows `count`,
`for_each`, `depends_on`, and caller-supplied provider aliases.

The modules were validated with AzureRM 5.x, AzAPI 2.x, and Random 3.x.
Select tested provider versions and retain your deployment's dependency lock
file.

## Example: Use a Lab in Your Own Deployment

For a deployment root at `deployments/my-lab` in this repository:

```hcl
terraform {
  required_version = ">= 1.1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
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

variable "vm_admin_username" {
  type = string
}

variable "vm_admin_password" {
  type      = string
  sensitive = true
}

module "lab" {
  source = "../../modules/labs/a2a"

  vm_admin_username  = var.vm_admin_username
  vm_admin_password  = var.vm_admin_password
  source_rg_name     = "My-ASR-Source"
  target_rg_name     = "My-ASR-Target"
  cache_storage_name = "myuniquecacheprefix"
  enable_replication = false
}

output "linux_vm_names" {
  value = module.lab.linux_vm_names
}
```

Authenticate with Azure CLI, select the intended subscription, and set
`ARM_SUBSCRIPTION_ID` for AzureRM 5.x. Supply passwords through secret environment
variables or your secret-management system, not committed variable files.

The resource-group provider setting above matches the lab deployment
roots. It permits deleting a resource group that contains resources Terraform
does not manage; choose that setting deliberately in your own deployment.

To consume a lab from another repository, replace the local source with a
Git source pinned to an immutable commit or release tag:

```hcl
source = "git::https://github.com/kachalio/Terraform-Labs.git//modules/labs/a2a?ref=<commit-or-tag>"
```

Publish the module changes to that commit or tag before referencing them.
Download the repository package rather than copying only one lab directory:
the lab modules depend on shared modules elsewhere in the same package.

## Multiple Instances and Providers

Each lab supports `count` and `for_each`. Give each instance distinct resource
group names, and make all globally scoped names (including storage accounts)
unique. Defaults are convenient for one lab, not guaranteed unique across
instances. Each deployment root needs its own state; resources from multiple
module instances in one root share that root's state.

For SQL backup or Migrate, also declare `azapi` in the caller:

```hcl
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}
```

For an aliased AzureRM provider, pass
`providers = { azurerm = azurerm.lab_subscription }` to the lab module. For labs
using AzAPI, also pass the matching AzAPI configuration to ensure both providers
target the intended subscription. Use separate module blocks when instances
need different provider configurations.

## Deployment Lifecycle

The `migrate-vmware` module creates its master site before its SQL/web child sites
and appliance artifacts. An `azapi_update_resource` then sets the master site's
complete `properties.sites` list, including the VMware site. Resource references
order this update after site creation without a dependency cycle. The original
master-site resource ignores subsequent changes to this field so the two
resources do not compete over membership. The update owns the complete list;
sites added outside Terraform are not preserved.

Set `enable_replication = true` to enable A2A replication. Setting it to `false`
removes replication resources. Disable replication before destroying an A2A lab.

The HANA lab requires its documented manual backup setup. See the
[A2A instructions](../../labs/examples/a2a/README) and
[HANA instructions](../../labs/examples/backup-saphana/README) for lab-specific steps.

## Offline Validation

From the repository root, with Terraform 1.7 or later:

```powershell
terraform '-chdir=tests\reusable-labs' init -backend=false
terraform '-chdir=tests\reusable-labs' validate
terraform '-chdir=tests\reusable-labs' test
```

The native Terraform tests use mocked providers and plan-only runs. They cover
multiple instances of every lab, VM input/output behavior, public-access
defaults, enabled/disabled ASR and VM backup resource counts, SQL discovery and
registration resource counts, and the deployment wrappers.
They do not authenticate to Azure, apply real resources, or access your lab
state or variable files. Review a real Terraform plan before deploying.
