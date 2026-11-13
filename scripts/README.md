# Guided Lab Deployment

[New-Lab.ps1](New-Lab.ps1) lets users create an Azure lab without running
Terraform commands themselves. Run it from a PowerShell terminal; Terraform
still performs the infrastructure deployment behind the scenes.

## Prerequisites

- PowerShell 7 or later.
- Terraform 1.1 or later, available on `PATH`.
- Azure CLI, available on `PATH`.
- An Azure account with an enabled subscription and permission to create the
  selected lab's resources. Region availability, quotas, role-assignment
  permissions, and Marketplace requirements still apply.
- Permission to run the script under your organization's execution policy.

The launcher checks prerequisites but does not install software. Terraform's
initialization downloads required providers when needed.

## Seeding Source

New environments are seeded directly from the selected reusable module under
`modules/labs/<lab>`, not from `labs/examples`. The launcher copies the module's
variable definitions and version/provider requirements, generates a wrapper
forwarding every input and output, and generates a commented variable reference
from the module's descriptions and defaults.

Input definitions are discovered in `variables.tf` and any `variables_*.tf`
files (for example, `variables_appliance.tf`) directly inside the module.
The launcher reads `variables.tf` first, then additional files in filename order,
and copies all of them into the environment. Their inputs are included in the
wizard, generated wrapper, and variable reference.

Provider configuration stays in the generated deployment root. AzureRM retains
the lab resource-group deletion setting. When the module declares vSphere, the
launcher configures its `user`, `password`, and `vsphere_server` arguments from
`var.vsphere_user`, `var.vsphere_password`, and `var.vsphere_server`, respectively.
The module must declare these inputs and mark `vsphere_password` as sensitive.
Other declared providers receive default configurations.
The reusable module itself does not configure providers.
`labs/examples` remains available for manual deployment and documentation, but
is not required to create or resume environments through the launcher.

Resume reads the environment's saved variable definitions and leaves its seeded
Terraform files and variable reference unchanged. Changes to module inputs or
defaults affect newly created environments, not the saved input defaults of
existing ones. The module implementation is still referenced locally, so changes
to its resources can affect subsequent plans.
Existing environments are not updated with newly generated provider
configuration on resume; update their root `providers.tf` manually if needed.

Resume discovers the same filename patterns in the saved environment, not in
the module, so newly added module variable files are not pulled into existing
environments.

## Create a Lab

From the repository root:

```powershell
.\scripts\New-Lab.ps1
```

The wizard:

1. Lets you choose one of the six labs and name the environment.
2. Asks whether to enter values individually or create files for manual editing.
3. Offers Azure device-code sign-in if necessary and lets you select a
   subscription. It does not change Azure CLI's global default subscription.
4. In individual-entry mode, prompts for required inputs, with passwords hidden.
5. Lists every available setting so you can change regions, VM sizes/counts,
   networking, and lab-specific options.
6. Saves a separate deployment root under `labs\<environment-name>`.
7. Initializes Terraform, validates the configuration, and creates a preview.
8. Shows proposed resources and a summary of additions, updates, removals, and
   replacements. This is not a price estimate.
9. Requires typing **DEPLOY** before applying that exact saved preview.
   Any other answer cancels deployment.

### Create Files for Manual Editing

Choose **Create deployment files and exit so I can edit terraform.tfvars** to
skip all individual input prompts. After subscription selection, the launcher
creates the deployment root and exits without initializing, planning, or
deploying, even when `-PlanOnly` is specified.

The generated `terraform.tfvars` contains descriptions, editable non-secret
defaults, suggested distinct resource names, and clearly marked `null`
placeholders for required inputs without suggestions. Replace those placeholders
before planning. Sensitive inputs are omitted; comments identify the `TF_VAR_*`
environment variables to supply securely.

The launcher prints the environment path, selected subscription/tenant
environment settings, and commands for `terraform init`, `terraform plan`, and
`terraform apply`. Continue with Terraform manually after editing. `-Resume`
does not support file-edit environments and stops without overwriting their
inputs; arbitrary HCL edits are not compatible with the wizard's literal parser.

If the preview removes or replaces resources, you must also type the environment
name to acknowledge that before approving deployment. There is no unattended
approval option. The saved preview is deleted after approval, cancellation, or
failure because it can contain secrets.

To preselect a lab and environment name:

```powershell
.\scripts\New-Lab.ps1 -Lab backup-vm -EnvironmentName backup-demo
```

Each new environment gets suggested distinct resource names, including short
VM names and randomized storage prefixes. Customize these if needed; storage
account names must be globally unique. Environment folder names must be 3-31
lowercase letters, digits, or hyphens, beginning with a letter. Reserved names,
including `examples`, are rejected. An existing folder is never overwritten by
a new-environment run.

## Set Variables

For required non-secret inputs, Enter accepts the suggestion. Required passwords
must be entered on every individual-entry run; the script never saves them in
the variable file.

In the optional-settings menu, enter a setting number to edit it:

- **Strings:** enter plain text.
- **Booleans:** enter `yes`/`no` or `true`/`false`.
- **Numbers:** enter a number, using a dot for a decimal separator.
- **Objects and lists:** enter JSON, or `@` followed by a path to a JSON file.
  The wizard shows the expected type and Terraform validates its fields.
- **Enter:** retain the current value or module default.
- **DEFAULT:** remove an optional override and use the module default.
- **Q** in the settings menu: cancel without writing environment configuration.

For example, the SQL data disk configuration accepts:

```json
[{"storage_account_type":"Standard_LRS","disk_size_gb":128}]
```

Refer to the generated `terraform.tfvars.example` for input descriptions and
complete commented module defaults. It is an input reference; the wizard saves
your selected values separately in `terraform.tfvars`, using HCL assignments.
The wizard writes one JSON-compatible literal per line (including JSON-style
objects and arrays, which are valid HCL). Use the wizard to edit settings;
resume reads this generated literal format, not arbitrary HCL expressions.

Public IPs stay disabled unless you enable them. Review security rules before
exposing access. A2A replication, VM backup protection, and SQL discovery are
disabled by default; set `enable_replication`, `enable_backup`, or
`start_discovery` when appropriate.

The HANA wizard suggests `Standard_D4s_v5` (16 GB) instead of the module's 8 GB
default. HANA installation takes additional time and its backup setup still has
[manual steps](../labs/examples/backup-saphana/README).

## Preview or Resume

Preview without deploying:

```powershell
.\scripts\New-Lab.ps1 -Lab a2a -EnvironmentName recovery-demo -PlanOnly
```

Later, resume that environment, re-enter passwords, and approve a fresh preview:

```powershell
.\scripts\New-Lab.ps1 -EnvironmentName recovery-demo -Resume
```

For individual-entry environments, combine `-Resume` with `-PlanOnly` to review
changes without applying them.
Resume keeps the existing configuration and state, allows settings to be edited,
and uses the subscription and tenant originally recorded for the environment.
It refuses to switch an existing environment to another subscription.
Older environments using `terraform.tfvars.json` are migrated to
`terraform.tfvars` when settings are saved during resume. Cancelling leaves
the original file unchanged. If both files exist, resume stops so conflicting
overrides cannot silently take precedence.

The saved files are:

- `main.tf` and supporting Terraform files: deployment root pointing to the
  reusable lab module.
- `terraform.tfvars`: non-secret input overrides.
- `environment.json`: lab name and subscription/tenant selection.
- Terraform working files, provider lock file, and local state after deployment.

Do not delete or move the environment directory after deployment. Its module
reference is relative to this repository and its state is needed for changes
and cleanup. Local environment folders are ignored by Git.

## Secrets, Errors, and Cleanup

Passwords are held temporarily in process environment variables for Terraform.
The launcher restores previous authentication and Terraform environment
settings afterward, including inherited variable overrides. It uses the
selected Azure CLI account and the environment's local default workspace.

**Terraform state can still contain passwords.** Restrict access to environment
directories and use a secured remote backend before adopting shared usage.
Do not commit state, working variable files, saved plans, or credentials.

Command failures stop the script explicitly. Configuration and state remain in
place, including after a partial deployment; correct the problem and use
`-Resume`. The script does not roll back or delete partially created resources.
Resources that were created can continue to incur charges.

This version creates and updates environments; guided destruction is not
included. Use the repository's [cleanup instructions](../README.md#cleanup)
from the generated environment directory, with the same inputs, subscription,
and passwords. Disable A2A replication with `-Resume` before destroying an A2A
environment. Do not simply delete its local folder to clean up Azure resources.

## Tests

Run the PowerShell tests without Azure access or third-party test frameworks:

```powershell
pwsh -NoProfile -File .\tests\powershell\New-Lab.Tests.ps1
pwsh -NoProfile -File .\tests\powershell\New-Lab.VariableFiles.Tests.ps1
```

To also verify generated HCL literals with Terraform (no providers or Azure
access required):

```powershell
pwsh -NoProfile -File .\tests\powershell\New-Lab.VariableFiles.Tests.ps1 -ValidateTerraform
```

To also initialize, validate, and run mocked Terraform plans against all six
generated deployment roots (Terraform 1.7 or later):

```powershell
pwsh -NoProfile -File .\tests\powershell\New-Lab.Tests.ps1 -ValidateTerraform
```

The extra validation may download provider plugins. It uses temporary
directories, fake credentials, and mocked providers; it never deploys to Azure.
