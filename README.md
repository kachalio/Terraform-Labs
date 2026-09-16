# Azure Lab Automation

Terraform configurations for deploying disposable Azure lab environments. The repository currently includes an Azure-to-Azure Site Recovery lab and an SAP HANA backup lab, supported by reusable network and virtual machine modules.

These configurations create billable Azure resources and are intended for lab and testing use. Review every Terraform plan before applying it, and destroy resources when they are no longer needed.

## Repository Layout

```text
.
|-- labs/
|   |-- a2a/                 # Azure-to-Azure Site Recovery lab
|   `-- backup-saphana/      # SAP HANA backup lab
|-- modules/
|   |-- asr_enable_replication/
|   |-- backup_vault/
|   |-- network/
|   |-- vm_linux/
|   `-- vm_windows/
`-- scripts/                 # Supporting setup scripts
```

Each directory under `labs/` is an independent Terraform root module with its own variables and state. Run Terraform commands from the lab directory you want to deploy.

## Labs

| Lab | Description | Documentation |
| --- | --- | --- |
| Azure-to-Azure replication | Creates source and target networks, Windows and Linux VMs, a Recovery Services vault, cache storage, and optional ASR replication. | [labs/a2a/README](labs/a2a/README) |
| SAP HANA backup | Creates a network, SUSE Linux VM, Recovery Services vault, and a VM extension that downloads and installs SAP HANA Express. Some backup registration steps remain manual. | [labs/backup-saphana/README](labs/backup-saphana/README) |

## Prerequisites

- An Azure subscription
- Permissions to create the resources used by the selected lab
- [Terraform](https://developer.hashicorp.com/terraform/install)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)

Authenticate and select the subscription before running Terraform:

```powershell
az login
az account set --subscription "<subscription-name-or-id>"
```

## Quick Start

Choose a lab and change to its directory:

```powershell
Set-Location .\labs\a2a
```

Create a local `terraform.tfvars` file containing the required values. Consult the selected lab's `variables.tf` for all available settings.

```hcl
vm_admin_username = "azureuser"
source_location   = "eastus2"
create_public_ip  = false
```

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
