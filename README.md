# Azure Lab Automation

Terraform configurations and reusable modules for deploying disposable Azure lab environments. The repository includes Site Recovery, backup, and VMware migration labs, supported by reusable network and virtual machine modules.

These configurations create billable Azure resources and are intended for lab and testing use. Review every Terraform plan before applying it, and destroy resources when they are no longer needed.

## Repository Layout

```text
.
|-- labs/
|   `-- examples/
|       |-- a2a/                 # Azure-to-Azure Site Recovery lab
|       |-- backup-saphana/       # SAP HANA backup lab
|       |-- backup-sql/           # SQL Server backup lab
|       |-- backup-vm/            # Azure VM backup lab
|       |-- migrate-vmware/       # VMware migration lab
|       `-- migrate-vmware-pe/    # VMware migration with private endpoints
|-- modules/
|   |-- labs/               # Reusable implementations of all six labs
|   |-- asr_enable_replication/
|   |-- backup_vault/
|   |-- network/
|   |-- vm_linux/
|   `-- vm_windows/
|-- scripts/                # Supporting setup scripts
`-- tests/reusable-labs/     # Offline Terraform module tests
```

Each lab directory under `labs/examples/` is an independent deployment root with its own variables and state. It calls the corresponding reusable child module under `modules/labs/`. Each includes a `terraform.tfvars.example` template listing every available input. Run Terraform commands from the example lab directory you want to deploy, or reference a child module from your own deployment root. Other folders under `labs/` are ignored for local deployments.

See [Reusable Lab Modules](modules/labs/README.md) for module sources, required inputs, provider configuration, multiple instances, and offline tests. These configurations target fresh deployments and do not migrate state from the previous lab layout. Use new deployment state and distinct resource names instead of reusing a pre-refactor lab deployment.

## Labs

| Lab | Description | Documentation |
| --- | --- | --- |
| Azure-to-Azure replication | Creates source and target networks, Windows and Linux VMs, a Recovery Services vault, cache storage, and optional ASR replication. | [labs/examples/a2a/README](labs/examples/a2a/README) |
| SAP HANA backup | Creates a network, SUSE Linux VM, Recovery Services vault, and a VM extension that downloads and installs SAP HANA Express. Some backup registration steps remain manual. | [labs/examples/backup-saphana/README](labs/examples/backup-saphana/README) |
| SQL Server backup | Creates Windows SQL VMs, a Recovery Services vault, a workload backup policy, and optional discovery and registration actions. | [Module reference](modules/labs/README.md) |
| Azure VM backup | Creates Windows and Linux VMs, a Recovery Services vault, a VM backup policy, and optional VM protection. | [Module reference](modules/labs/README.md) |
| VMware migration | Creates a network, Azure Migrate project, and migration solutions. | [Module reference](modules/labs/README.md) |
| VMware migration with private endpoints | Adds storage, private endpoints, DNS resources, and role assignments to the migration lab. | [Module reference](modules/labs/README.md) |

## Prerequisites

- An Azure subscription
- Permissions to create the resources used by the selected lab
- [Terraform](https://developer.hashicorp.com/terraform/install) 1.1 or later (1.7 or later for offline tests)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)

Authenticate and select the subscription before running Terraform:

```powershell
az login
az account set --subscription "<subscription-name-or-id>"
```

## Quick Start

### Guided PowerShell Deployment

For users unfamiliar with Terraform:

```powershell
.\scripts\New-Lab.ps1
```

The wizard selects a lab and Azure subscription, prompts for inputs, and creates
an isolated environment under `labs\<environment-name>`. It previews changes
and requires typing `DEPLOY` before applying the reviewed plan. PowerShell 7 or
later is required; Terraform and Azure CLI must be installed.

Use `-PlanOnly` to preview without deploying and
`-EnvironmentName <name> -Resume` to retry or update a saved environment.
See [Guided Lab Deployment](scripts/README.md) for input examples, secret/state
handling, lab-specific caveats, and cleanup.

### Manual Terraform Deployment

Choose a lab and change to its directory:

```powershell
Set-Location .\labs\examples\a2a
Copy-Item .\terraform.tfvars.example .\terraform.tfvars
```

Edit the required non-secret values in the copied file. Optional settings show
their actual defaults and are commented out; uncomment only what you want to
override. Objects and lists are shown in full, including example replacements
for nullable plans and data disk configuration.

Terraform does not automatically load `terraform.tfvars.example`. The template
is safe to commit; the working `terraform.tfvars` remains ignored. Keep templates
in sync with the selected lab's `variables.tf` when inputs or defaults change.

Supply secrets through environment variables instead of writing them to shell history:

```powershell
$credential = Get-Credential -UserName "azureuser"
$env:TF_VAR_vm_admin_password = $credential.GetNetworkCredential().Password
```

The SAP HANA lab also requires its master password:

```powershell
$hanaCredential = Get-Credential -UserName "SYSTEM"
$env:TF_VAR_hana_master_password = $hanaCredential.GetNetworkCredential().Password
```

Initialize, validate, review, and deploy:

```powershell
terraform init
terraform fmt -check
terraform validate
terraform plan -out lab.tfplan
terraform apply lab.tfplan
```

Remove secret environment variables when finished:

```powershell
Remove-Item Env:TF_VAR_vm_admin_password -ErrorAction SilentlyContinue
Remove-Item Env:TF_VAR_hana_master_password -ErrorAction SilentlyContinue
```

## Public Access

Linux VM public IP addresses are disabled by default. Set `create_public_ip = true` in the selected lab's variables to create and attach a Standard static public IP. Restrict network security rules to trusted source addresses before exposing SSH, RDP, or application ports.

## Cleanup

Run the destroy command from the same lab directory and with the same variable values used during deployment:

```powershell
terraform plan -destroy
terraform destroy
```

For the A2A lab, disable replication before destroying the environment. See the lab-specific README for the required sequence.

## State and Secrets

This repository currently uses local Terraform state. State can contain passwords and other sensitive values even when Terraform variables are marked `sensitive` or Azure extension values use `protected_settings`.

The `.gitignore` excludes state, variable files, saved plans, and Terraform working directories. Do not force-add these files. For shared or persistent use, configure a secured remote backend with encryption, locking, versioning, and restricted access.

## Troubleshooting

- Run `terraform init -upgrade` after changing provider or module requirements.
- Run `terraform validate` from the selected lab directory to check its configuration.
- Confirm the active Azure subscription with `az account show`.
- Verify that the selected Azure region supports the requested VM sizes and image SKUs.
- Review VM extension logs in Azure when guest installation scripts fail.
- Review the generated plan carefully before applying or destroying resources.

## Scope

The code is designed for repeatable lab deployments, not production workloads. Production use requires additional design for remote state, identity, secret management, network isolation, monitoring, policy, availability, backup retention, and disaster recovery operations.
