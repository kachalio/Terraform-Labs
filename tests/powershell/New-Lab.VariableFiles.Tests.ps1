#requires -Version 7.0
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
    Assert-LabTest (($Variables.Name -join ',') -ceq 'base,appliance_password,extra') 'Discover all inputs in deterministic order during creation and resume.'
    Assert-LabTest ($Secrets.ContainsKey('appliance_password')) 'Prompt securely for required inputs from additional files.'
}

$temporary = Join-Path ([System.IO.Path]::GetTempPath()) "lab-variable-files-$([guid]::NewGuid().ToString('N'))"
try {
    $script:RepositoryRoot = $temporary
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
    foreach ($answer in @('1', 'Test-only-password!', '3', 'true', '')) { $script:Answers.Enqueue($answer) }
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
    $values = Get-Content -LiteralPath (Join-Path $directory 'terraform.tfvars.json') -Raw | ConvertFrom-Json -AsHashtable
    Assert-LabTest ($values.extra -eq $true -and -not $values.ContainsKey('appliance_password')) 'Save extra overrides without secrets.'

    Set-Content -LiteralPath (Join-Path $module 'variables_appliance.tf') -Value 'changed module definition'
    Set-Content -LiteralPath (Join-Path $module 'variables_new.tf') -Value 'new module definition'
    foreach ($answer in @('Test-only-password!', '')) { $script:Answers.Enqueue($answer) }
    Start-LabWizard -EnvironmentName test-files -Resume -PlanOnly | Out-Null
    Assert-LabTest ($script:Answers.Count -eq 0) 'Consume resume prompts from saved definitions.'
    Assert-LabTest (-not (Test-Path -LiteralPath (Join-Path $directory 'variables_new.tf'))) 'Do not copy new module files during resume.'

    Remove-Item -LiteralPath (Join-Path $directory 'variables_appliance.tf'), (Join-Path $directory 'variables_zextra.tf')
    Assert-LabTest (@(Get-LabVariableFiles $directory).Count -eq 1) 'Continue supporting environments with only variables.tf.'
}
finally {
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Recurse }
}
Write-Host "PASS: $script:Checks checks. No Azure resources were deployed."
