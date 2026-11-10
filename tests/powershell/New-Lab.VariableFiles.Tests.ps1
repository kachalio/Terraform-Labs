#requires -Version 7.0
[CmdletBinding()]
param([switch] $ValidateTerraform)

$ErrorActionPreference = 'Stop'
$repository = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path (Join-Path $repository 'scripts') 'New-Lab.ps1')

$script:Checks = 0
function Assert-LabTest {
    param([bool] $Condition, [string] $Message)
    if (-not $Condition) { throw "FAILED: $Message" }
    $script:Checks++
}

function Find-LabTool {
    param([string] $Name, [string] $InstallUrl)
    return $Name
}

function Invoke-LabCommand {
    param([string] $Command, [string[]] $Arguments, [switch] $CaptureOutput)
    if ($Command -eq 'terraform' -and $Arguments[0] -eq 'version') {
        return '{"terraform_version":"1.9.0"}'
    }
    if ($Command -eq 'az' -and $Arguments[0] -eq 'account') {
        return '[{"id":"test-subscription","tenantId":"test-tenant","name":"Offline test","state":"Enabled"}]'
    }
    throw "Unexpected command: $Command $Arguments"
}

function Read-Host {
    param([string] $Prompt, [switch] $AsSecureString)
    if ($script:Answers.Count -eq 0) { throw "Unexpected prompt: $Prompt" }
    $answer = $script:Answers.Dequeue()
    if ($AsSecureString) { return ConvertTo-SecureString $answer -AsPlainText -Force }
    return $answer
}

function Invoke-LabDeployment {
    param($Terraform, $Directory, $Name, $Subscription, $Variables, $Secrets, [switch] $PreviewOnly)
    $script:DeploymentCalls++
    Assert-LabTest (($Variables.Name -join ',') -ceq 'base,appliance_password,extra') 'Discover all inputs in deterministic order during creation and resume.'
    Assert-LabTest ($Secrets.ContainsKey('appliance_password')) 'Prompt securely for required inputs from additional files.'
}

$temporary = Join-Path ([System.IO.Path]::GetTempPath()) "lab-variable-files-$([guid]::NewGuid().ToString('N'))"
try {
    $script:RepositoryRoot = $temporary
    $script:DeploymentCalls = 0
    $literalDirectory = Join-Path $temporary 'literals'
    New-Item -ItemType Directory -Path $literalDirectory | Out-Null
    $literalPath = Join-Path $literalDirectory 'terraform.tfvars'
    $literalValues = @{
        text = "Quotes `" and backslash \, newline`nwith`t tabs`r and controls $([char]8)$([char]12)"
        templates = '${literal} %{literal} $${already} %%{already}'
        paths = 'C:\before\folder'
        enabled = $false
        quantity = 1.5
        absent = $null
        empty = @()
        single = @('one')
        nested = @{ disks = @(@{ size = 128; label = '${disk}' }); nullable = $null }
    }
    Write-LabValues $literalPath $literalValues
    $roundTrip = Read-LabValues $literalPath
    foreach ($name in $literalValues.Keys) {
        Assert-LabTest ((ConvertTo-Json -InputObject $roundTrip[$name] -Depth 100 -Compress) -ceq
            (ConvertTo-Json -InputObject $literalValues[$name] -Depth 100 -Compress)) "Round-trip literal $name."
    }
    Write-LabValues $literalPath @{}
    Assert-LabTest ((Read-LabValues $literalPath).Count -eq 0) 'Round-trip empty overrides.'
    foreach ($invalid in @('broken', 'name = invalid', "name = true`nname = false")) {
        Set-Content -LiteralPath $literalPath -Value $invalid
        $failure = $null
        try { Read-LabValues $literalPath | Out-Null }
        catch { $failure = $_ }
        Assert-LabTest ($null -ne $failure) 'Reject malformed or duplicate assignments.'
    }
    Write-LabValues $literalPath $literalValues
    if ($ValidateTerraform) {
        $terraform = (Get-Command terraform -CommandType Application).Source
        $definitions = foreach ($name in $literalValues.Keys | Sort-Object) {
            "variable `"$name`" {`n  type = any`n}"
        }
        $definitions += "output `"values`" {`n  value = {"
        $definitions += foreach ($name in $literalValues.Keys | Sort-Object) { "    $name = var.$name" }
        $definitions += @('  }', '}')
        Set-Content -LiteralPath (Join-Path $literalDirectory 'main.tf') -Value $definitions
        & $terraform "-chdir=$literalDirectory" init -backend=false -input=false -no-color | Out-Host
        Assert-LabTest ($LASTEXITCODE -eq 0) 'Initialize provider-free literal validation.'
        & $terraform "-chdir=$literalDirectory" plan -input=false -no-color '-out=values.tfplan' | Out-Host
        Assert-LabTest ($LASTEXITCODE -eq 0) 'Accept generated tfvars as native HCL.'
        $plan = & $terraform "-chdir=$literalDirectory" show -json values.tfplan | ConvertFrom-Json -AsHashtable -Depth 100
        Assert-LabTest ($LASTEXITCODE -eq 0) 'Read Terraform literal results.'
        $actual = $plan.planned_values.outputs.values.value
        foreach ($name in @('text', 'templates', 'paths', 'enabled', 'quantity')) {
            Assert-LabTest ($actual[$name] -ceq $literalValues[$name]) "Terraform preserves literal $name."
        }
        Assert-LabTest ($null -eq $actual.absent -and $actual.empty.Count -eq 0 -and
            $actual.single.Count -eq 1 -and $actual.nested.disks[0].label -ceq '${disk}' -and
            $actual.nested.disks[0].size -eq 128 -and $null -eq $actual.nested.nullable) 'Terraform preserves nulls and nested collections.'
    }
    $module = Join-Path $temporary 'modules\labs\a2a'
    New-Item -ItemType Directory -Path $module -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $module 'variables.tf') -Value @'
variable "base" {
  description = "Base input"
  type = string
  default = "base-default"
}
'@
    Set-Content -LiteralPath (Join-Path $module 'variables_appliance.tf') -Value @'
variable "appliance_password" {
  description = "Appliance password"
  type = string
  sensitive = true
}
'@
    Set-Content -LiteralPath (Join-Path $module 'variables_zextra.tf') -Value @'
variable "extra" {
  description = "Extra input"
  type = bool
  default = false
}
'@
    Set-Content -LiteralPath (Join-Path $module 'versions.tf') -Value @'
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}
'@
    foreach ($file in @('main.tf', 'outputs.tf', 'variables_appliance.tf.bak', 'variables-other.tf')) {
        Set-Content -LiteralPath (Join-Path $module $file) -Value ''
    }
    $nested = Join-Path $module 'nested'
    New-Item -ItemType Directory -Path $nested | Out-Null
    Set-Content -LiteralPath (Join-Path $nested 'variables_nested.tf') -Value ''

    $script:Answers = [System.Collections.Generic.Queue[string]]::new()
    foreach ($answer in @('1', '1', 'Test-only-password!', '3', 'true', '')) { $script:Answers.Enqueue($answer) }
    Start-LabWizard -Lab a2a -EnvironmentName test-files -PlanOnly | Out-Null
    Assert-LabTest ($script:Answers.Count -eq 0) 'Consume creation prompts including editing an additional input.'
    $directory = Join-Path $temporary 'labs\test-files'
    $files = @(Get-LabVariableFiles $directory)
    Assert-LabTest (($files.Name -join ',') -ceq 'variables.tf,variables_appliance.tf,variables_zextra.tf') 'Copy only matching top-level variable files.'
    foreach ($file in $files) {
        Assert-LabTest ((Get-FileHash -LiteralPath $file.FullName).Hash -ceq
            (Get-FileHash -LiteralPath (Join-Path $module $file.Name)).Hash) "Preserve $($file.Name) verbatim."
    }
    $main = Get-Content -LiteralPath (Join-Path $directory 'main.tf') -Raw
    $template = Get-Content -LiteralPath (Join-Path $directory 'terraform.tfvars.example') -Raw
    foreach ($name in @('base', 'appliance_password', 'extra')) {
        Assert-LabTest ($main.Contains("$name = var.$name")) "Forward $name."
        Assert-LabTest ($template.Contains("# $name = ")) "Document $name."
    }
    $values = Read-LabValues (Join-Path $directory 'terraform.tfvars')
    Assert-LabTest ($values.extra -eq $true -and -not $values.ContainsKey('appliance_password')) 'Save extra overrides without secrets.'
    Assert-LabTest (-not (Test-Path -LiteralPath (Join-Path $directory 'terraform.tfvars.json'))) 'Create HCL tfvars rather than JSON files.'
    $providers = Get-Content -LiteralPath (Join-Path $directory 'providers.tf') -Raw
    Assert-LabTest (-not $providers.Contains('provider "vsphere"')) 'Do not configure vSphere when the module does not require it.'
    Assert-LabTest ($providers.Contains('prevent_deletion_if_contains_resources = false')) 'Preserve AzureRM provider configuration.'

    Set-Content -LiteralPath (Join-Path $module 'variables_manual.tf') -Value @'
variable "resource_group_name" {
  description = "Suggested name"
  type = string
}
variable "required_number" {
  description = "Required number"
  type = number
}
variable "settings" {
  description = "Nested default"
  type = object({
    disks = list(number)
  })
  default = {
    disks = [128, 256]
  }
}
'@
    $deploymentCalls = $script:DeploymentCalls
    foreach ($answer in @('test-file-edit', 'invalid', '2', '1')) { $script:Answers.Enqueue($answer) }
    Start-LabWizard -Lab a2a -PlanOnly | Out-Null
    Assert-LabTest ($script:Answers.Count -eq 0) 'Choose file editing immediately after naming, retry invalid choices, and skip input prompts.'
    Assert-LabTest ($script:DeploymentCalls -eq $deploymentCalls) 'Do not initialize, plan, or deploy in file-edit mode.'
    $manualDirectory = Join-Path $temporary 'labs\test-file-edit'
    $manualPath = Join-Path $manualDirectory 'terraform.tfvars'
    $manualValues = (Get-Content -LiteralPath $manualPath -Raw) -replace "`r`n", "`n"
    Assert-LabTest ($manualValues.Contains('base = "base-default"') -and $manualValues.Contains('extra = false')) 'Include editable module defaults.'
    Assert-LabTest ($manualValues.Contains('resource_group_name = "Lab-test-file-edit"')) 'Include suggested distinct names.'
    Assert-LabTest ($manualValues.Contains("# Required: replace null with a value before planning.`nrequired_number = null")) 'Clearly mark missing required non-secret values.'
    Assert-LabTest ($manualValues.Contains("settings = {`n    disks = [128, 256]`n  }")) 'Preserve multiline HCL defaults.'
    Assert-LabTest ($manualValues.Contains('TF_VAR_appliance_password') -and $manualValues -notmatch '(?m)^appliance_password\s*=') 'Document secret inputs without saving passwords.'
    foreach ($file in @('main.tf', 'providers.tf', 'versions.tf', 'outputs.tf', 'variables.tf', 'variables_manual.tf', 'terraform.tfvars.example')) {
        Assert-LabTest (Test-Path -LiteralPath (Join-Path $manualDirectory $file)) "Seed $file in file-edit mode."
    }
    $manualMetadata = Get-Content -LiteralPath (Join-Path $manualDirectory 'environment.json') -Raw | ConvertFrom-Json
    Assert-LabTest ($manualMetadata.inputMode -eq 'file' -and $manualMetadata.subscriptionId -eq 'test-subscription') 'Save the manual mode and selected subscription.'
    $savedManualHash = (Get-FileHash -LiteralPath $manualPath).Hash
    $manualResumeError = $null
    try { Start-LabWizard -EnvironmentName test-file-edit -Resume | Out-Null }
    catch { $manualResumeError = $_ }
    Assert-LabTest ($null -ne $manualResumeError -and $manualResumeError.Exception.Message -match 'run Terraform directly') 'Explain how to continue a manual environment instead of parsing arbitrary HCL.'
    Assert-LabTest ((Get-FileHash -LiteralPath $manualPath).Hash -ceq $savedManualHash) 'Never overwrite manually edited inputs during resume.'
    foreach ($answer in @('2', '1')) { $script:Answers.Enqueue($answer) }
    Start-LabWizard -Lab a2a -EnvironmentName test-file-normal | Out-Null
    Assert-LabTest ($script:Answers.Count -eq 0 -and $script:DeploymentCalls -eq $deploymentCalls) 'File editing exits without deployment even when PlanOnly is not specified.'
    if ($ValidateTerraform) {
        & $terraform fmt -write=false $manualPath | Out-Host
        Assert-LabTest ($LASTEXITCODE -eq 0) 'Generate syntactically valid HCL for manual editing.'
    }

    Set-Content -LiteralPath (Join-Path $module 'variables_appliance.tf') -Value 'changed module definition'
    Set-Content -LiteralPath (Join-Path $module 'variables_new.tf') -Value 'new module definition'
    foreach ($answer in @('Test-only-password!', '')) { $script:Answers.Enqueue($answer) }
    Start-LabWizard -EnvironmentName test-files -Resume -PlanOnly | Out-Null
    Assert-LabTest ($script:Answers.Count -eq 0) 'Consume resume prompts from saved definitions.'
    Assert-LabTest (-not (Test-Path -LiteralPath (Join-Path $directory 'variables_new.tf'))) 'Do not copy new module files during resume.'

    $legacyPath = Join-Path $directory 'terraform.tfvars.json'
    $values | ConvertTo-Json | Set-Content -LiteralPath $legacyPath
    $conflict = $null
    try { Start-LabWizard -EnvironmentName test-files -Resume -PlanOnly | Out-Null }
    catch { $conflict = $_ }
    Assert-LabTest ($null -ne $conflict -and $conflict.Exception.Message -match 'Both terraform.tfvars') 'Reject conflicting input files.'
    Remove-Item -LiteralPath (Join-Path $directory 'terraform.tfvars')
    foreach ($answer in @('Test-only-password!', 'q')) { $script:Answers.Enqueue($answer) }
    Start-LabWizard -EnvironmentName test-files -Resume -PlanOnly | Out-Null
    Assert-LabTest (Test-Path -LiteralPath $legacyPath) 'Retain legacy JSON on cancellation.'
    foreach ($answer in @('Test-only-password!', '')) { $script:Answers.Enqueue($answer) }
    Start-LabWizard -EnvironmentName test-files -Resume -PlanOnly | Out-Null
    Assert-LabTest (-not (Test-Path -LiteralPath $legacyPath)) 'Remove legacy JSON after saving HCL overrides.'
    Assert-LabTest ((Read-LabValues (Join-Path $directory 'terraform.tfvars')).extra -eq $true) 'Preserve legacy overrides during migration.'

    $providerModule = Join-Path $temporary 'modules\labs\provider-test'
    $providerRoot = Join-Path $temporary 'labs\provider-test'
    New-Item -ItemType Directory -Path $providerModule, $providerRoot | Out-Null
    Set-Content -LiteralPath (Join-Path $providerModule 'versions.tf') -Value @'
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    vsphere = {
      source = "hashicorp/vsphere"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}
'@
    $definitions = foreach ($name in @('vsphere_user', 'vsphere_password', 'vsphere_server')) {
        "variable `"$name`" {"
        "  description = `"$name input`""
        '  type = string'
        if ($name -eq 'vsphere_password') { '  sensitive = true' }
        '}'
    }
    Set-Content -LiteralPath (Join-Path $providerModule 'variables.tf') -Value $definitions
    Set-Content -LiteralPath (Join-Path $providerModule 'outputs.tf') -Value ''
    $providerVariables = @(Get-LabVariables (Join-Path $providerModule 'variables.tf'))
    New-LabSeedFiles -LabName provider-test -ModuleDirectory $providerModule -Directory $providerRoot -Variables $providerVariables
    $providers = (Get-Content -LiteralPath (Join-Path $providerRoot 'providers.tf') -Raw) -replace "`r`n", "`n"
    $expectedVsphere = @'
provider "vsphere" {
  user           = var.vsphere_user
  password       = var.vsphere_password
  vsphere_server = var.vsphere_server
'@
    Assert-LabTest ($providers.Contains($expectedVsphere.Replace("`r`n", "`n"))) 'Configure vSphere with root variable references and correct provider argument names.'
    Assert-LabTest ([regex]::Matches($providers, 'provider "vsphere"').Count -eq 1) 'Generate exactly one vSphere configuration.'
    Assert-LabTest ($providers.Contains('provider "random" {}')) 'Retain default configuration for other providers.'
    Assert-LabTest ($providers.Contains('prevent_deletion_if_contains_resources = false')) 'Retain AzureRM configuration alongside vSphere.'
    $providerTemplate = Get-Content -LiteralPath (Join-Path $providerRoot 'terraform.tfvars.example') -Raw
    Assert-LabTest ($providerTemplate.Contains('# Sensitive input: supply through the wizard or TF_VAR_vsphere_password.')) 'Keep vSphere passwords out of generated input examples.'
    if ($ValidateTerraform) {
        & $terraform fmt -write=false (Join-Path $providerRoot 'providers.tf') | Out-Host
        Assert-LabTest ($LASTEXITCODE -eq 0) 'Generate syntactically valid provider blocks.'
    }

    Remove-Item -LiteralPath (Join-Path $directory 'variables_appliance.tf'), (Join-Path $directory 'variables_zextra.tf')
    Assert-LabTest (@(Get-LabVariableFiles $directory).Count -eq 1) 'Continue supporting environments with only variables.tf.'
}
finally {
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Recurse }
}
Write-Host "PASS: $script:Checks checks. No Azure resources were deployed."
