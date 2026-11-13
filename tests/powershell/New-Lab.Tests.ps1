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

function Assert-LabThrows {
    param([scriptblock] $Action, [string] $Pattern)
    $exception = $null
    try { & $Action | Out-Null }
    catch { $exception = $_.Exception }
    Assert-LabTest ($null -ne $exception -and $exception.Message -match $Pattern) "Expected error matching '$Pattern'."
}

$labs = @('a2a', 'backup-saphana', 'backup-sql', 'backup-vm', 'migrate-vmware', 'migrate-vmware-pe')
$counts = @(36, 23, 25, 29, 8, 9)
for ($index = 0; $index -lt $labs.Count; $index++) {
    $path = Join-Path (Join-Path (Join-Path $repository 'modules') 'labs') $labs[$index]
    $variables = @(Get-LabVariables (Join-Path $path 'variables.tf'))
    Assert-LabTest ($variables.Count -eq $counts[$index]) "Read all inputs for $($labs[$index])."
    Assert-LabTest (@($variables | Where-Object Sensitive).Count -eq $(if ($labs[$index] -eq 'backup-saphana') { 2 }
            elseif ($labs[$index] -like 'migrate*') { 0 } else { 1 })) "Read password sensitivity for $($labs[$index])."
}
Assert-LabTest ((Convert-LabInput 'yes' 'bool') -eq $true) 'Parse yes.'
Assert-LabTest ((Convert-LabInput 'false' 'bool') -eq $false) 'Parse false.'
Assert-LabTest ((Convert-LabInput '1.5' 'number') -eq [decimal] 1.5) 'Parse invariant numbers.'
Assert-LabTest ((Convert-LabInput 'text' 'string') -ceq 'text') 'Keep literal strings.'
$empty = Convert-LabInput '[]' 'list(string)'
Assert-LabTest ($empty -is [array] -and $empty.Count -eq 0) 'Preserve empty arrays.'
$single = Convert-LabInput '[{"disk_size_gb":128}]' 'list(object({disk_size_gb=number}))'
Assert-LabTest ($single -is [array] -and $single.Count -eq 1 -and $single[0].disk_size_gb -eq 128) 'Preserve single-item object arrays.'
Assert-LabTest ($null -eq (Convert-LabInput 'null' 'object({name=string})')) 'Accept nullable objects.'
Assert-LabThrows { Convert-LabInput 'maybe' 'bool' } 'yes or no'
Assert-LabThrows { Convert-LabInput 'NaN' 'number' } 'finite number'
Assert-LabThrows { Convert-LabInput '{}' 'list(string)' } 'JSON array'
Assert-LabThrows { Convert-LabInput '[]' 'object({name=string})' } 'JSON object'
Assert-LabThrows { Convert-LabInput '{broken' 'map(string)' } 'JSON|Conversion'

$pwsh = (Get-Command pwsh -CommandType Application).Source
Assert-LabThrows { Invoke-LabCommand $pwsh @('-NoProfile', '-Command', 'exit 7') -CaptureOutput } 'exit code 7'
Assert-LabTest ((Invoke-LabCommand $pwsh @('-NoProfile', '-Command', 'Write-Output ready') -CaptureOutput) -eq 'ready') 'Capture native command output.'
$findToolImplementation = (Get-Command Find-LabTool).ScriptBlock
$invokeCommandImplementation = (Get-Command Invoke-LabCommand).ScriptBlock

$temporary = Join-Path ([System.IO.Path]::GetTempPath()) "lab-launcher-tests-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $temporary | Out-Null
$script:Calls = [System.Collections.Generic.List[object]]::new()
$script:PromptQueue = [System.Collections.Generic.Queue[string]]::new()
$script:FailStep = ''
$script:MutatePlan = $false
$script:NeedLogin = $false
$script:AccountLists = 0
$script:PlanPath = ''
$script:Subscription = @{
    id = '11111111-1111-1111-1111-111111111111'
    tenantId = '22222222-2222-2222-2222-222222222222'
    name = 'Offline test subscription'
    state = 'Enabled'
}
$script:Plan = @{
    format_version = '1.2'
    planned_values = @{ root_module = @{} }
    resource_changes = @(
        @{ mode = 'managed'; change = @{ actions = @('create') } }
    )
}

function Find-LabTool {
    param([string] $Name, [string] $InstallUrl)
    return $Name
}

function Read-Host {
    param([string] $Prompt, [switch] $AsSecureString)
    if ($script:PromptQueue.Count -eq 0) { throw "Unexpected prompt: $Prompt" }
    if ($script:MutatePlan -and $Prompt -like '*Type DEPLOY*') {
        Set-Content -LiteralPath $script:PlanPath -Value 'modified-plan'
    }
    $answer = $script:PromptQueue.Dequeue()
    if ($AsSecureString) { return ConvertTo-SecureString $answer -AsPlainText -Force }
    return $answer
}

function Invoke-LabCommand {
    param([string] $Command, [string[]] $Arguments, [switch] $CaptureOutput)
    $step = if ($Arguments[0] -like '-chdir=*') { $Arguments[1] } else { $Arguments[0] }
    $script:Calls.Add([pscustomobject] @{ Command = $Command; Step = $step; Arguments = $Arguments })
    if ($step -eq $script:FailStep) { throw "Mock $step failed." }
    if ($Command -eq 'az') {
        if ($step -eq 'account') {
            $script:AccountLists++
            if ($script:NeedLogin -and $script:AccountLists -eq 1) { return '[]' }
            return ConvertTo-Json -InputObject @($script:Subscription)
        }
        if ($step -eq 'login') { return }
        throw "Unexpected Azure command: $Arguments"
    }
    if ($step -eq 'version') { return '{"terraform_version":"1.16.6"}' }
    if ($step -eq 'plan') {
        Assert-LabTest ($env:ARM_SUBSCRIPTION_ID -eq $script:Subscription.id) 'Use the selected subscription for planning.'
        Assert-LabTest ([string]::IsNullOrEmpty($env:ARM_CLIENT_SECRET)) 'Do not inherit service-principal secrets.'
        Assert-LabTest ([string]::IsNullOrEmpty($env:TF_CLI_ARGS)) 'Do not inherit additional Terraform arguments.'
        Assert-LabTest ([string]::IsNullOrEmpty($env:TF_VAR_enable_backup)) 'Do not inherit optional TF_VAR overrides.'
        $script:PlanPath = ($Arguments | Where-Object { $_.StartsWith('-out=') }).Substring(5)
        Set-Content -LiteralPath $script:PlanPath -Value 'reviewed-plan'
        return
    }
    if ($step -eq 'show') { return ConvertTo-Json -InputObject $script:Plan -Depth 100 }
    if ($step -eq 'apply') {
        Assert-LabTest ($Arguments[-1] -ceq $script:PlanPath) 'Apply the exact reviewed plan.'
        Assert-LabTest ('-auto-approve' -notin $Arguments) 'Do not use blanket automatic approval.'
    }
    if ($step -notin @('init', 'validate', 'apply', 'output')) { throw "Unexpected Terraform command: $Arguments" }
}

function Reset-LabTest {
    param([string[]] $Responses = @())
    $script:Calls.Clear()
    $script:PromptQueue.Clear()
    foreach ($answer in $Responses) { $script:PromptQueue.Enqueue($answer) }
    $script:FailStep = ''
    $script:MutatePlan = $false
    $script:NeedLogin = $false
    $script:AccountLists = 0
}

$savedEnvironment = @{}
foreach ($key in @('TF_VAR_vm_admin_password', 'TF_VAR_enable_backup', 'ARM_SUBSCRIPTION_ID', 'ARM_CLIENT_SECRET', 'TF_CLI_ARGS', 'TF_WORKSPACE', 'TF_PLUGIN_CACHE_DIR', 'PATH')) {
    $savedEnvironment[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
}
try {
    if ($IsWindows) {
        $tools = Join-Path $temporary 'tools with spaces'
        New-Item -ItemType Directory -Path $tools | Out-Null
        Set-Content -LiteralPath (Join-Path $tools 'lab-tool-resolution.cmd') -Value "@echo off`r`necho preferred-tool`r`nexit /b 0" -Encoding ascii
        Set-Content -LiteralPath (Join-Path $tools 'lab-tool-resolution') -Value 'extensionless companion' -Encoding ascii
        $env:PATH = "$tools$([System.IO.Path]::PathSeparator)$env:PATH"
        $matches = @(Get-Command 'lab-tool-resolution' -CommandType Application)
        Assert-LabTest ($matches.Count -eq 2) 'Reproduce a Windows CLI with both .cmd and extensionless launchers.'
        $resolved = & $findToolImplementation 'lab-tool-resolution' 'https://example.invalid/install'
        Assert-LabTest ($resolved -is [string] -and $resolved -ceq (Join-Path $tools 'lab-tool-resolution.cmd')) 'Resolve exactly one preferred executable path.'
        $result = & $invokeCommandImplementation -Command $resolved -Arguments @('--version') -CaptureOutput
        Assert-LabTest ($result -eq 'preferred-tool') 'Invoke the resolved native command when its path contains spaces.'
        Set-LabProcessVariable 'PATH' $savedEnvironment.PATH
    }
    $env:TF_VAR_vm_admin_password = 'prior-test-value'
    $env:TF_VAR_enable_backup = 'true'
    $env:ARM_SUBSCRIPTION_ID = 'prior-test-subscription'
    $env:ARM_CLIENT_SECRET = 'prior-test-client-secret'
    $env:TF_CLI_ARGS = '-input=true'
    $env:TF_WORKSPACE = 'prior-workspace'

    $workingRepository = Join-Path $temporary 'repository'
    New-Item -ItemType Directory -Path (Join-Path $workingRepository 'labs') -Force | Out-Null
    $moduleRoot = Join-Path $repository 'modules'
    foreach ($file in Get-ChildItem -LiteralPath $moduleRoot -Recurse -Filter '*.tf' |
            Where-Object FullName -NotMatch '[\\/]\.terraform[\\/]') {
        $relative = [System.IO.Path]::GetRelativePath($repository, $file.FullName)
        $destination = Join-Path $workingRepository $relative
        New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $destination
    }
    Assert-LabTest (-not (Test-Path -LiteralPath (Join-Path (Join-Path $workingRepository 'labs') 'examples'))) 'Run creation and resume without any example directories.'
    $backupModule = Join-Path (Join-Path (Join-Path $workingRepository 'modules') 'labs') 'backup-vm'
    $moduleVariablesPath = Join-Path $backupModule 'variables.tf'
    $moduleVariables = (Get-Content -LiteralPath $moduleVariablesPath -Raw).Replace('"eastus2"', '"westus2"')
    $moduleVariables += "`nvariable `"seed_note`" {`n  description = `"New module input`"`n  type = string`n  default = `"module-input`"`n}`n"
    Set-Content -LiteralPath $moduleVariablesPath -Value $moduleVariables -Encoding utf8
    Add-Content -LiteralPath (Join-Path $backupModule 'outputs.tf') -Value "`noutput `"seed_note`" {`n  value = var.seed_note`n  description = `"New module output`"`n  sensitive = true`n}`n" -Encoding utf8
    $script:RepositoryRoot = $workingRepository
    Reset-LabTest @('invalid', 'no')
    $inputValues = @{}
    $inputSecrets = @{}
    Read-LabValue ([pscustomobject] @{
        Name = 'flag'; Description = 'Test flag'; Type = 'bool'; Sensitive = $false; Required = $false; Default = 'true'
    }) $inputValues $inputSecrets
    Assert-LabTest ($inputValues.ContainsKey('flag') -and $inputValues.flag -eq $false) 'Reprompt invalid input and preserve an explicit false override.'
    Reset-LabTest @('DEFAULT')
    Read-LabValue ([pscustomobject] @{
        Name = 'flag'; Description = 'Test flag'; Type = 'bool'; Sensitive = $false; Required = $false; Default = 'true'
    }) $inputValues $inputSecrets
    Assert-LabTest (-not $inputValues.ContainsKey('flag')) 'Restore an optional default by removing the override.'
    $jsonPath = Join-Path $temporary 'input.json'
    Set-Content -LiteralPath $jsonPath -Value '[{"storage_account_type":"Standard_LRS","disk_size_gb":128}]'
    $fromFile = Convert-LabInput "@$jsonPath" 'list(object({storage_account_type=string,disk_size_gb=number}))'
    Assert-LabTest ($fromFile -is [array] -and $fromFile[0].disk_size_gb -eq 128) 'Read advanced JSON from a file.'
    Set-LabProcessVariable 'TF_VAR_lab_absent_test' $null
    Assert-LabTest (-not (Test-Path -LiteralPath 'Env:TF_VAR_lab_absent_test')) 'Remove absent variables rather than creating empty overrides.'
    for ($index = 0; $index -lt $labs.Count; $index++) {
        $lab = $labs[$index]
        $name = "test-$lab"
        $answers = @('1', '1')
        if ($lab -notlike 'migrate*') { $answers += @('', 'Test-only-not-a-real-credential!') }
        else { $answers += '' }
        if ($lab -eq 'backup-saphana') { $answers += 'Test-only-not-a-real-credential!' }
        $answers += @('', 'DEPLOY')
        Reset-LabTest $answers
        Start-LabWizard -Lab $lab -EnvironmentName $name | Out-Null
        $directory = Join-Path (Join-Path $workingRepository 'labs') $name
        $main = Get-Content -LiteralPath (Join-Path $directory 'main.tf') -Raw
        Assert-LabTest ($main.Contains("source = `"../../modules/labs/$lab`"")) "Generate a correct module source for $lab."
        $moduleDirectory = Join-Path (Join-Path (Join-Path $workingRepository 'modules') 'labs') $lab
        foreach ($file in @('variables.tf', 'versions.tf')) {
            Assert-LabTest ((Get-Content -LiteralPath (Join-Path $directory $file) -Raw) -ceq
                (Get-Content -LiteralPath (Join-Path $moduleDirectory $file) -Raw)) "Seed $file directly from the $lab module."
        }
        $seededVariables = @(Get-LabVariables (Join-Path $moduleDirectory 'variables.tf'))
        $template = (Get-Content -LiteralPath (Join-Path $directory 'terraform.tfvars.example') -Raw) -replace "`r`n", "`n"
        foreach ($variable in $seededVariables) {
            Assert-LabTest ($template -match "(?m)^# $($variable.Name) = ") "Include $($variable.Name) in the generated $lab template."
            if (-not $variable.Required -and -not $variable.Sensitive) {
                $default = ("$($variable.Name) = $($variable.Default)" -split '\r?\n' | ForEach-Object { "# $_" }) -join "`n"
                Assert-LabTest ($template.Contains($default)) "Document the module default for $($variable.Name)."
            }
        }
        $moduleOutputs = Get-Content -LiteralPath (Join-Path $moduleDirectory 'outputs.tf') -Raw
        $rootOutputs = Get-Content -LiteralPath (Join-Path $directory 'outputs.tf') -Raw
        foreach ($output in [regex]::Matches($moduleOutputs, '(?m)^output "([^"]+)"')) {
            Assert-LabTest ($rootOutputs.Contains("value = module.lab.$($output.Groups[1].Value)")) "Forward $lab output $($output.Groups[1].Value)."
        }
        $providers = Get-Content -LiteralPath (Join-Path $directory 'providers.tf') -Raw
        Assert-LabTest ($providers.Contains('prevent_deletion_if_contains_resources = false')) 'Retain the lab resource-group provider behavior.'
        Assert-LabTest ($providers.Contains('provider "azapi"') -eq ($lab -eq 'backup-sql' -or $lab -like 'migrate*')) 'Configure AzAPI only when declared by the module.'
        if ($lab -eq 'backup-vm') {
            Assert-LabTest ($main.Contains('seed_note = var.seed_note')) 'Automatically forward newly added module inputs.'
            Assert-LabTest ($rootOutputs.Contains('sensitive = true') -and $rootOutputs.Contains('description = "New module output"')) 'Preserve output sensitivity and descriptions.'
            Assert-LabTest (@($seededVariables | Where-Object Name -EQ 'source_location')[0].Default -ceq '"westus2"') 'Use a changed module region default.'
        }
        $inputs = Read-LabValues (Join-Path $directory 'terraform.tfvars')
        Assert-LabTest (-not $inputs.ContainsKey('vm_admin_password') -and -not $inputs.ContainsKey('hana_master_password')) "Never persist passwords for $lab."
        if ($lab -eq 'backup-saphana') { Assert-LabTest ($inputs.vm_size -eq 'Standard_D4s_v5') 'Suggest 16 GB for HANA.' }
        if ($inputs.ContainsKey('windows_vm_name_prefix')) {
            Assert-LabTest ("$($inputs.windows_vm_name_prefix)-1".Length -le 15) 'Generate short Windows VM names.'
        }
        if ($inputs.ContainsKey('cache_storage_name')) {
            Assert-LabTest ("$($inputs.cache_storage_name)source".Length -le 24) 'Generate valid cache-storage name lengths.'
        }
        if ($inputs.ContainsKey('migrate_project_name')) {
            Assert-LabTest ($inputs.migrate_project_name -cmatch '^[a-z0-9]{1,17}$') 'Keep Migrate storage prefixes lowercase and short.'
        }
        Assert-LabTest (@($script:Calls | Where-Object Step -EQ 'apply').Count -eq 1) "Apply only after approval for $lab."
        Assert-LabTest (@(Get-ChildItem -LiteralPath $directory -Filter '*.tfplan').Count -eq 0) 'Delete the sensitive saved plan.'
        Assert-LabTest ($env:TF_VAR_vm_admin_password -eq 'prior-test-value') 'Restore prior secret variables.'
        Assert-LabTest ($env:ARM_SUBSCRIPTION_ID -eq 'prior-test-subscription') 'Restore the prior subscription.'
        Assert-LabTest ($env:ARM_CLIENT_SECRET -eq 'prior-test-client-secret') 'Restore prior authentication variables.'
        Assert-LabTest ($env:TF_CLI_ARGS -eq '-input=true' -and $env:TF_WORKSPACE -eq 'prior-workspace') 'Restore Terraform environment settings.'
    }

    $directory = Join-Path (Join-Path $workingRepository 'labs') 'test-backup-vm'
    $variables = @(Get-LabVariables (Join-Path $directory 'variables.tf'))
    $secrets = @{ vm_admin_password = ConvertTo-SecureString 'Test-only-not-a-real-credential!' -AsPlainText -Force }
    foreach ($answer in @('no', 'deploy', '')) {
        Reset-LabTest @($answer)
        Invoke-LabDeployment 'terraform' $directory 'test-backup-vm' ([pscustomobject] $script:Subscription) $variables $secrets | Out-Null
        Assert-LabTest (@($script:Calls | Where-Object Step -EQ 'apply').Count -eq 0) 'Do not deploy after cancellation or lowercase approval.'
    }
    Reset-LabTest
    Invoke-LabDeployment 'terraform' $directory 'test-backup-vm' ([pscustomobject] $script:Subscription) $variables $secrets -PreviewOnly | Out-Null
    Assert-LabTest (@($script:Calls | Where-Object Step -EQ 'apply').Count -eq 0) 'Plan-only never applies or requests approval.'
    $script:Plan.resource_changes = @(
        @{ mode = 'managed'; change = @{ actions = @('create') } },
        @{ mode = 'managed'; change = @{ actions = @('update') } },
        @{ mode = 'managed'; change = @{ actions = @('delete') } },
        @{ mode = 'managed'; change = @{ actions = @('delete', 'create') } },
        @{ mode = 'data'; change = @{ actions = @('read') } }
    )
    $summary = Get-LabPlanSummary ([pscustomobject] $script:Plan)
    Assert-LabTest ($summary.Create -eq 1 -and $summary.Update -eq 1 -and $summary.Delete -eq 1 -and $summary.Replace -eq 1) 'Count creates, updates, removals, and replacements separately.'
    Reset-LabTest @('wrong-environment')
    Invoke-LabDeployment 'terraform' $directory 'test-backup-vm' ([pscustomobject] $script:Subscription) $variables $secrets | Out-Null
    Assert-LabTest (@($script:Calls | Where-Object Step -EQ 'apply').Count -eq 0) 'Require acknowledgment before destructive changes.'
    Reset-LabTest @('test-backup-vm', 'DEPLOY')
    Invoke-LabDeployment 'terraform' $directory 'test-backup-vm' ([pscustomobject] $script:Subscription) $variables $secrets | Out-Null
    Assert-LabTest (@($script:Calls | Where-Object Step -EQ 'apply').Count -eq 1) 'Allow explicitly acknowledged destructive changes.'
    $script:Plan.resource_changes = @(@{ mode = 'managed'; change = @{ actions = @('create') } })
    Reset-LabTest @('DEPLOY')
    $script:MutatePlan = $true
    Assert-LabThrows {
        Invoke-LabDeployment 'terraform' $directory 'test-backup-vm' ([pscustomobject] $script:Subscription) $variables $secrets
    } 'changed after review'
    Assert-LabTest (@($script:Calls | Where-Object Step -EQ 'apply').Count -eq 0) 'Reject a changed saved plan.'
    Reset-LabTest
    $script:Plan.Remove('planned_values')
    Assert-LabThrows {
        Invoke-LabDeployment 'terraform' $directory 'test-backup-vm' ([pscustomobject] $script:Subscription) $variables $secrets
    } 'unrecognized preview format'
    Assert-LabTest (@($script:Calls | Where-Object Step -EQ 'apply').Count -eq 0) 'Reject an invalid preview instead of treating it as successful.'
    $script:Plan.planned_values = @{ root_module = @{} }
    $statePath = Join-Path $directory 'terraform.tfstate'
    $state = '{"version":4,"terraform_version":"1.16.6","serial":0,"lineage":"33333333-3333-3333-3333-333333333333","outputs":{},"resources":[]}'
    Set-Content -LiteralPath $statePath -Value $state
    foreach ($step in @('init', 'validate', 'plan', 'show', 'apply', 'output')) {
        Reset-LabTest @('DEPLOY')
        $script:FailStep = $step
        Assert-LabThrows {
            Invoke-LabDeployment 'terraform' $directory 'test-backup-vm' ([pscustomobject] $script:Subscription) $variables $secrets
        } "Mock $step failed"
        Assert-LabTest ($env:TF_VAR_vm_admin_password -eq 'prior-test-value' -and $env:ARM_CLIENT_SECRET -eq 'prior-test-client-secret') 'Restore secrets and identity after failures.'
        Assert-LabTest (@(Get-ChildItem -LiteralPath $directory -Filter '*.tfplan').Count -eq 0) 'Clean up saved plans after failures.'
        Assert-LabTest (Test-Path -LiteralPath (Join-Path $directory 'environment.json')) 'Retain the environment after failures.'
        Assert-LabTest ((Get-Content -LiteralPath $statePath -Raw).Trim() -ceq $state) 'Never delete or rewrite existing state on failure.'
    }
    $savedSeedHashes = @{}
    foreach ($file in @('main.tf', 'variables.tf', 'versions.tf', 'outputs.tf', 'providers.tf', 'terraform.tfvars.example')) {
        $savedSeedHashes[$file] = (Get-FileHash -LiteralPath (Join-Path $directory $file)).Hash
    }
    Set-Content -LiteralPath $moduleVariablesPath -Value $moduleVariables.Replace('"westus2"', '"centralus"') -Encoding utf8
    Reset-LabTest @('', 'Test-only-not-a-real-credential!', '')
    Start-LabWizard -EnvironmentName 'test-backup-vm' -Resume -PlanOnly | Out-Null
    foreach ($file in $savedSeedHashes.Keys) {
        Assert-LabTest ((Get-FileHash -LiteralPath (Join-Path $directory $file)).Hash -ceq $savedSeedHashes[$file]) "Do not reseed $file during resume after module inputs change."
    }
    Assert-LabTest (@($script:Calls | Where-Object Step -EQ 'apply').Count -eq 0) 'Resume in preview-only mode.'
    Assert-LabTest (@($script:Calls | Where-Object { $_.Command -eq 'az' -and 'set' -in $_.Arguments }).Count -eq 0) 'Do not change the global Azure CLI subscription.'
    $script:Subscription.id = '44444444-4444-4444-4444-444444444444'
    Reset-LabTest
    Assert-LabThrows { Start-LabWizard -EnvironmentName 'test-backup-vm' -Resume } 'original subscription and tenant'
    $script:Subscription.id = '11111111-1111-1111-1111-111111111111'
    Reset-LabTest
    Assert-LabThrows { Start-LabWizard -Lab backup-vm -EnvironmentName 'test-backup-vm' } 'already exists'
    Assert-LabThrows { Start-LabWizard -Resume } 'Specify -EnvironmentName'
    foreach ($name in @('examples', '..\escape', 'CON', 'com1', 'a', 'invalid/name')) {
        Assert-LabThrows { Start-LabWizard -Lab backup-vm -EnvironmentName $name } 'Reserved folder names'
    }
    Reset-LabTest @('1', '1', '', 'Test-only-not-a-real-credential!', 'q')
    $script:NeedLogin = $true
    Start-LabWizard -Lab backup-vm -EnvironmentName 'cancelled-lab' | Out-Null
    Assert-LabTest (@($script:Calls | Where-Object Step -EQ 'login').Count -eq 1) 'Offer device-code login when no Azure subscriptions are cached.'
    Assert-LabTest (-not (Test-Path -LiteralPath (Join-Path (Join-Path $workingRepository 'labs') 'cancelled-lab'))) 'Cancel configuration without creating an environment.'
    $secrets.vm_admin_password.Dispose()

    if ($ValidateTerraform) {
        foreach ($key in @('TF_VAR_vm_admin_password', 'TF_VAR_enable_backup', 'TF_CLI_ARGS')) {
            Set-LabProcessVariable $key $null
        }
        Set-LabProcessVariable 'TF_WORKSPACE' 'default'
        $terraform = (Get-Command terraform -CommandType Application).Source
        $providerCache = Join-Path $temporary 'provider-cache'
        New-Item -ItemType Directory -Path $providerCache | Out-Null
        Set-LabProcessVariable 'TF_PLUGIN_CACHE_DIR' $providerCache
        foreach ($lab in $labs) {
            $directory = Join-Path (Join-Path $workingRepository 'labs') "test-$lab"
            & $terraform "-chdir=$directory" init -backend=false -input=false -no-color | Out-Host
            Assert-LabTest ($LASTEXITCODE -eq 0) "Initialize generated $lab root."
            & $terraform "-chdir=$directory" validate -no-color | Out-Host
            Assert-LabTest ($LASTEXITCODE -eq 0) "Validate generated $lab root."
            $test = @('mock_provider "azurerm" {}')
            if ($lab -eq 'backup-sql' -or $lab -like 'migrate*') { $test += 'mock_provider "azapi" {}' }
            if ($lab -like 'migrate*') { $test += 'mock_provider "random" {}' }
            $test += @('run "generated_environment" {', '  command = plan')
            if ($lab -notlike 'migrate*') {
                $test += @('  variables {', '    vm_admin_password = "Test-only-not-a-real-credential!"')
                if ($lab -eq 'backup-saphana') { $test += '    hana_master_password = "Test-only-not-a-real-credential!"' }
                $test += '  }'
            }
            $test += '}'
            Set-Content -LiteralPath (Join-Path $directory 'launcher.tftest.hcl') -Value $test -Encoding utf8
            & $terraform "-chdir=$directory" test -no-color | Out-Host
            Assert-LabTest ($LASTEXITCODE -eq 0) "Plan generated $lab root with mocked providers and saved inputs."
        }
    }
}
finally {
    foreach ($key in $savedEnvironment.Keys) {
        Set-LabProcessVariable $key $savedEnvironment[$key]
    }
    Remove-Item -LiteralPath $temporary -Recurse
}
Write-Host "PASS: $script:Checks checks. No Azure resources were deployed."
