#requires -Version 7.0
<#
.SYNOPSIS
Creates and optionally deploys an Azure lab through a guided wizard.
.EXAMPLE
.\scripts\New-Lab.ps1
.EXAMPLE
.\scripts\New-Lab.ps1 -Lab backup-vm -EnvironmentName backup-demo -PlanOnly
.EXAMPLE
.\scripts\New-Lab.ps1 -EnvironmentName backup-demo -Resume
#>
[CmdletBinding()]
param(
    [ValidateSet('a2a', 'backup-saphana', 'backup-sql', 'backup-vm', 'migrate-vmware', 'migrate-vmware-pe')]
    [string] $Lab,
    [string] $EnvironmentName,
    [switch] $PlanOnly,
    [switch] $Resume
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$script:RepositoryRoot = Split-Path $PSScriptRoot -Parent

function Invoke-LabCommand {
    param(
        [Parameter(Mandatory)] [string] $Command,
        [Parameter(Mandatory)] [string[]] $Arguments,
        [switch] $CaptureOutput
    )

    if ($CaptureOutput) {
        $output = & $Command @Arguments
    }
    else {
        & $Command @Arguments | Out-Host
    }
    if ($LASTEXITCODE -ne 0) {
        throw "$(Split-Path $Command -Leaf) $($Arguments[0]) failed (exit code $LASTEXITCODE). See the command's error above."
    }
    if ($CaptureOutput) {
        return ($output -join "`n")
    }
}

function Find-LabTool {
    param([string] $Name, [string] $InstallUrl)

    $tool = Get-Command $Name -CommandType Application -TotalCount 1 -ErrorAction SilentlyContinue
    if (-not $tool) {
        throw "$Name is required. Install it from $InstallUrl and open a new PowerShell terminal."
    }
    return $tool.Source
}

function Read-LabChoice {
    param([string] $Title, [object[]] $Items, [scriptblock] $Label)

    Write-Host "`n$Title"
    for ($index = 0; $index -lt $Items.Count; $index++) {
        Write-Host ("{0}. {1}" -f ($index + 1), (& $Label $Items[$index]))
    }
    while ($true) {
        $answer = Read-Host 'Enter a number'
        $number = 0
        if ([int]::TryParse($answer, [ref] $number) -and $number -ge 1 -and $number -le $Items.Count) {
            return $Items[$number - 1]
        }
        Write-Warning "Choose a number between 1 and $($Items.Count)."
    }
}

function Get-LabVariables {
    param([string] $Path)

    $source = (Get-Content -LiteralPath $Path -Raw) -replace "`r`n", "`n"
    $blocks = [regex]::Matches($source, '(?ms)^variable "([^"]+)" \{\n(.*?)^\}')
    if ($blocks.Count -eq 0 -or $blocks.Count -ne [regex]::Matches($source, '(?m)^variable "').Count) {
        throw "Cannot read all input definitions in $Path. Expected top-level variable blocks."
    }
    foreach ($block in $blocks) {
        $attributes = @{}
        $body = $block.Groups[2].Value
        # The repository's variable attributes use two spaces; nested expressions use more.
        $starts = [regex]::Matches($body, '(?m)^  ([a-zA-Z_]+)\s*(=|\{)[ \t]*')
        for ($index = 0; $index -lt $starts.Count; $index++) {
            if ($starts[$index].Groups[2].Value -ne '=') { continue }
            $start = $starts[$index].Index + $starts[$index].Length
            $end = if ($index + 1 -lt $starts.Count) { $starts[$index + 1].Index } else { $body.Length }
            $attributes[$starts[$index].Groups[1].Value] = $body.Substring($start, $end - $start).Trim()
        }
        if (-not $attributes.ContainsKey('description') -or -not $attributes.ContainsKey('type')) {
            throw "Missing description or type for input $($block.Groups[1].Value) in $Path."
        }
        [pscustomobject] @{
            Name = $block.Groups[1].Value
            Description = ConvertFrom-Json -InputObject $attributes.description
            Type = $attributes.type
            Required = -not $attributes.ContainsKey('default')
            Default = $attributes['default']
            Sensitive = $attributes['sensitive'] -eq 'true'
        }
    }
}

function Convert-LabInput {
    param([string] $Text, [string] $Type)

    switch ($Type) {
        'string' { return $Text }
        'bool' {
            switch -Regex ($Text.Trim()) {
                '^(true|yes|y)$' { return $true }
                '^(false|no|n)$' { return $false }
                default { throw [System.FormatException]::new('Enter yes or no (true or false).') }
            }
        }
        'number' {
            $number = [decimal] 0
            if (-not [decimal]::TryParse($Text, [System.Globalization.NumberStyles]::Float,
                    [System.Globalization.CultureInfo]::InvariantCulture, [ref] $number)) {
                throw [System.FormatException]::new('Enter a finite number using a dot as the decimal separator.')
            }
            return $number
        }
        default {
            if ($Text.StartsWith('@')) {
                $Text = Get-Content -LiteralPath $Text.Substring(1) -Raw
            }
            $value = ConvertFrom-Json -InputObject $Text -AsHashtable -NoEnumerate -Depth 100
            if ($null -ne $value) {
                if ($Type.StartsWith('object(') -or $Type.StartsWith('map(')) {
                    if ($value -isnot [System.Collections.IDictionary]) {
                        throw [System.FormatException]::new('Enter a JSON object or null.')
                    }
                }
                elseif ($Type.StartsWith('list(') -or $Type.StartsWith('set(') -or $Type.StartsWith('tuple(')) {
                    if ($value -isnot [array]) { throw [System.FormatException]::new('Enter a JSON array or null.') }
                }
                else { throw [System.InvalidOperationException]::new("Unsupported input type: $Type") }
            }
            return ,$value
        }
    }
}

function Read-LabValue {
    param([object] $Variable, [hashtable] $Values, [hashtable] $Secrets)

    Write-Host "`n$($Variable.Name): $($Variable.Description)"
    if ($Variable.Sensitive) {
        if ($Variable.Type -ne 'string') { throw "Unsupported sensitive input type for $($Variable.Name)." }
        do {
            $secret = Read-Host 'Enter the password (hidden)' -AsSecureString
            if ($secret.Length -eq 0) { Write-Warning 'A password is required.' }
        } while ($secret.Length -eq 0)
        $Secrets[$Variable.Name] = $secret
        return
    }

    $current = if ($Values.ContainsKey($Variable.Name)) {
        ConvertTo-Json -InputObject $Values[$Variable.Name] -Depth 100 -Compress
    }
    elseif (-not $Variable.Required) { $Variable.Default }
    else { '(required)' }
    Write-Host "Current value or default: $current"
    if ($Variable.Type -notin @('string', 'bool', 'number')) {
        Write-Host 'Enter JSON, or @ followed by a JSON file path. Terraform checks the fields during preview.'
        Write-Host "Expected type: $($Variable.Type)"
    }

    while ($true) {
        $text = Read-Host 'New value (Enter keeps current; DEFAULT restores an optional default)'
        if ($text.Length -eq 0) {
            if ($Values.ContainsKey($Variable.Name) -or -not $Variable.Required) { return }
            Write-Warning 'This input is required.'
            continue
        }
        if ($text -ceq 'DEFAULT' -and -not $Variable.Required) {
            $Values.Remove($Variable.Name)
            return
        }
        try {
            $Values[$Variable.Name] = Convert-LabInput -Text $text -Type $Variable.Type
            return
        }
        catch [System.ArgumentException], [System.FormatException], [System.Management.Automation.ItemNotFoundException] {
            Write-Warning $_.Exception.Message
        }
    }
}

function Get-LabNameDefaults {
    param([string] $LabName, [string] $Name, [string] $Suffix, [object[]] $Variables)

    $names = @{
        source_rg_name = "Lab-$Name-Source"
        target_rg_name = "Lab-$Name-Target"
        resource_group_name = "Lab-$Name"
        source_vnet_name = "$Name-source-vnet"
        target_vnet_name = "$Name-target-vnet"
        linux_vm_name_prefix = "lin$Suffix"
        windows_vm_name_prefix = "win$Suffix"
        cache_storage_name = "cache$Suffix"
        rsv_name = "vault-$Suffix"
        migrate_project_name = "migrate$Suffix"
        vm_admin_username = 'azureuser'
    }
    if ($LabName -eq 'backup-saphana') {
        $names.vm_size = 'Standard_D4s_v5'
    }
    $values = @{}
    foreach ($variable in $Variables) {
        if ($names.ContainsKey($variable.Name)) { $values[$variable.Name] = $names[$variable.Name] }
    }
    return $values
}

function Read-LabConfiguration {
    param([object[]] $Variables, [hashtable] $Values, [hashtable] $Secrets)

    foreach ($variable in $Variables | Where-Object Required) {
        Read-LabValue -Variable $variable -Values $Values -Secrets $Secrets
    }
    Write-Host "`nReview region, VM sizes/counts, and enable_replication/enable_backup/start_discovery below."
    Write-Host 'Public IPs remain disabled unless you explicitly enable them.'
    while ($true) {
        Write-Host "`nAvailable settings (choose a number to edit, Enter to preview, or Q to cancel):"
        for ($index = 0; $index -lt $Variables.Count; $index++) {
            $variable = $Variables[$index]
            $display = if ($variable.Sensitive) { '(hidden)' }
            elseif ($Values.ContainsKey($variable.Name)) {
                ConvertTo-Json -InputObject $Values[$variable.Name] -Depth 100 -Compress
            }
            elseif ($variable.Default -match "`n") { '(module default; select to view)' }
            else { $variable.Default }
            Write-Host ("{0}. {1} = {2}" -f ($index + 1), $variable.Name, $display)
        }
        $answer = Read-Host 'Setting'
        if ($answer.Length -eq 0) { return $true }
        if ($answer -ieq 'q') { return $false }
        $number = 0
        if ([int]::TryParse($answer, [ref] $number) -and $number -ge 1 -and $number -le $Variables.Count) {
            Read-LabValue -Variable $Variables[$number - 1] -Values $Values -Secrets $Secrets
        }
        else { Write-Warning 'Choose a setting number, Enter, or Q.' }
    }
}

function Get-LabPlanSummary {
    param([object] $Plan)

    $summary = @{ Create = 0; Update = 0; Delete = 0; Replace = 0 }
    if ($Plan.PSObject.Properties.Name -contains 'resource_changes') {
        foreach ($resource in $Plan.resource_changes) {
            if ($resource.mode -ne 'managed') { continue }
            $actions = @($resource.change.actions)
            if ('create' -in $actions -and 'delete' -in $actions) { $summary.Replace++ }
            elseif ('create' -in $actions) { $summary.Create++ }
            elseif ('delete' -in $actions) { $summary.Delete++ }
            elseif ('update' -in $actions) { $summary.Update++ }
        }
    }
    return $summary
}

function Set-LabProcessVariable {
    param([string] $Name, [AllowNull()] [object] $Value)

    if ($null -eq $Value) {
        if (Test-Path -LiteralPath "Env:$Name") { Remove-Item -LiteralPath "Env:$Name" }
    }
    else { [Environment]::SetEnvironmentVariable($Name, $Value, 'Process') }
}

function Invoke-LabDeployment {
    param(
        [string] $Terraform,
        [string] $Directory,
        [string] $Name,
        [object] $Subscription,
        [object[]] $Variables,
        [hashtable] $Secrets,
        [switch] $PreviewOnly
    )

    $planPath = Join-Path $Directory "preview-$([guid]::NewGuid().ToString('N')).tfplan"
    $previous = @{}
    $environment = @{
        ARM_SUBSCRIPTION_ID = $Subscription.id
        ARM_TENANT_ID = $Subscription.tenantId
        ARM_USE_CLI = 'true'
        ARM_USE_MSI = 'false'
        ARM_USE_OIDC = 'false'
        ARM_USE_AKS_WORKLOAD_IDENTITY = 'false'
        ARM_CLIENT_ID = $null
        ARM_CLIENT_SECRET = $null
        ARM_CLIENT_CERTIFICATE_PATH = $null
        ARM_CLIENT_CERTIFICATE_PASSWORD = $null
        TF_INPUT = 'false'
        TF_IN_AUTOMATION = 'true'
        TF_WORKSPACE = 'default'
        TF_DATA_DIR = $null
        TF_LOG = $null
        TF_LOG_PATH = $null
        TF_LOG_CORE = $null
        TF_LOG_PROVIDER = $null
    }
    foreach ($item in Get-ChildItem Env: | Where-Object { $_.Name -like 'TF_CLI_ARGS*' -or $_.Name -like 'TF_VAR_*' }) {
        $environment[$item.Name] = $null
    }
    foreach ($variable in $Variables) {
        $environment["TF_VAR_$($variable.Name)"] = $null
    }
    try {
        foreach ($key in $environment.Keys) {
            $previous[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
            Set-LabProcessVariable $key $environment[$key]
        }
        foreach ($key in $Secrets.Keys) {
            $password = [System.Net.NetworkCredential]::new('', $Secrets[$key]).Password
            Set-LabProcessVariable "TF_VAR_$key" $password
            $password = $null
        }
        Invoke-LabCommand $Terraform @("-chdir=$Directory", 'init', '-input=false', '-no-color')
        Invoke-LabCommand $Terraform @("-chdir=$Directory", 'validate', '-no-color')
        Write-Host "`nCreating a preview. No Azure resources are changed by this step."
        Invoke-LabCommand $Terraform @("-chdir=$Directory", 'plan', '-input=false', '-no-color', "-out=$planPath")
        $hash = (Get-FileHash -LiteralPath $planPath -Algorithm SHA256).Hash
        $json = Invoke-LabCommand $Terraform @("-chdir=$Directory", 'show', '-json', $planPath) -CaptureOutput
        $plan = ConvertFrom-Json -InputObject $json -Depth 100
        $json = $null
        if ('format_version' -notin $plan.PSObject.Properties.Name -or
            'planned_values' -notin $plan.PSObject.Properties.Name) {
            throw 'Terraform returned an unrecognized preview format. Nothing was applied.'
        }
        $summary = Get-LabPlanSummary $plan
        Write-Host "`nEnvironment: $Name"
        Write-Host "Subscription: $($Subscription.name) ($($Subscription.id))"
        Write-Host "New: $($summary.Create); update: $($summary.Update); remove: $($summary.Delete); replace: $($summary.Replace)"
        Write-Host 'The preview is not a cost estimate. Azure resources are billable until cleaned up.'
        if ($PreviewOnly) {
            Write-Host 'Preview only: nothing was deployed. Configuration is saved for a later run with -Resume.'
            return
        }
        if ($summary.Delete -gt 0 -or $summary.Replace -gt 0) {
            Write-Warning 'This preview removes or replaces existing resources.'
            if ((Read-Host "Type the environment name '$Name' to acknowledge removals") -cne $Name) {
                Write-Host 'Deployment cancelled; configuration is retained.'
                return
            }
        }
        if ((Read-Host 'Review the preview above. Type DEPLOY to apply exactly these changes (anything else cancels)') -cne 'DEPLOY') {
            Write-Host 'Deployment cancelled; configuration is retained.'
            return
        }
        if ((Get-FileHash -LiteralPath $planPath -Algorithm SHA256).Hash -cne $hash) {
            throw 'The saved preview changed after review. Nothing was applied; create a fresh preview.'
        }
        Invoke-LabCommand $Terraform @("-chdir=$Directory", 'apply', '-input=false', '-no-color', $planPath)
        Write-Host "`nDeployment completed. Keep $Directory and its state for later changes and cleanup."
        Invoke-LabCommand $Terraform @("-chdir=$Directory", 'output', '-no-color')
    }
    finally {
        foreach ($key in $previous.Keys) {
            Set-LabProcessVariable $key $previous[$key]
        }
        if (Test-Path -LiteralPath $planPath) { Remove-Item -LiteralPath $planPath }
    }
}

function Start-LabWizard {
    param([string] $Lab, [string] $EnvironmentName, [switch] $PlanOnly, [switch] $Resume)

    $terraform = Find-LabTool 'terraform' 'https://developer.hashicorp.com/terraform/install'
    $azure = Find-LabTool 'az' 'https://learn.microsoft.com/cli/azure/install-azure-cli'
    $version = ConvertFrom-Json (Invoke-LabCommand $terraform @('version', '-json') -CaptureOutput)
    if ([version] $version.terraform_version -lt [version] '1.1.0') { throw 'Terraform 1.1 or later is required.' }

    $metadata = $null
    if ($Resume) {
        if (-not $EnvironmentName) { throw 'Specify -EnvironmentName when using -Resume.' }
    }
    else {
        $labs = @(
            @{ Name = 'a2a'; Title = 'Azure-to-Azure Site Recovery' }
            @{ Name = 'backup-saphana'; Title = 'SAP HANA backup (manual backup setup required)' }
            @{ Name = 'backup-sql'; Title = 'SQL Server backup' }
            @{ Name = 'backup-vm'; Title = 'Azure VM backup' }
            @{ Name = 'migrate-vmware'; Title = 'VMware migration' }
            @{ Name = 'migrate-vmware-pe'; Title = 'VMware migration with private endpoints' }
        )
        if (-not $Lab) { $Lab = (Read-LabChoice 'Choose a lab' $labs { param($item) $item.Title }).Name }
        if (-not $EnvironmentName) {
            $suggested = "$Lab-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
            $EnvironmentName = Read-Host "Environment name (Enter for $suggested)"
            if (-not $EnvironmentName) { $EnvironmentName = $suggested }
        }
    }
    if ($EnvironmentName -cnotmatch '^[a-z][a-z0-9-]{2,30}$' -or
        $EnvironmentName -match '^(con|prn|aux|nul|com[1-9]|lpt[1-9])$' -or $EnvironmentName -eq 'examples') {
        throw 'Use a name of 3-31 lowercase letters, digits, or hyphens, starting with a letter. Reserved folder names are not allowed.'
    }
    $directory = Join-Path (Join-Path $script:RepositoryRoot 'labs') $EnvironmentName
    $metadataPath = Join-Path $directory 'environment.json'
    $valuesPath = Join-Path $directory 'terraform.tfvars.json'
    if ($Resume) {
        if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
            throw "No launcher-created environment named $EnvironmentName was found."
        }
        $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
        if ($metadata.schemaVersion -ne 1 -or ($Lab -and $Lab -ne $metadata.lab)) {
            throw 'The environment metadata is unsupported or does not match the selected lab.'
        }
        $Lab = $metadata.lab
        $values = Get-Content -LiteralPath $valuesPath -Raw | ConvertFrom-Json -AsHashtable
    }
    elseif (Test-Path -LiteralPath $directory) {
        throw "$directory already exists. Choose a new name, or use -Resume for a launcher-created environment."
    }
    if ($Lab -notin @('a2a', 'backup-saphana', 'backup-sql', 'backup-vm', 'migrate-vmware', 'migrate-vmware-pe')) {
        throw "Unknown lab: $Lab"
    }
    $example = Join-Path (Join-Path (Join-Path $script:RepositoryRoot 'labs') 'examples') $Lab
    foreach ($file in @('variables.tf', 'outputs.tf', 'providers.tf', 'versions.tf', 'terraform.tfvars.example')) {
        if (-not (Test-Path -LiteralPath (Join-Path $example $file) -PathType Leaf)) {
            throw "The $Lab example is missing $file. Restore the example before creating an environment."
        }
    }
    $variablePath = if ($Resume) { Join-Path $directory 'variables.tf' } else { Join-Path $example 'variables.tf' }
    $variables = @(Get-LabVariables $variablePath)
    if (-not $Resume) {
        $values = Get-LabNameDefaults $Lab $EnvironmentName ([guid]::NewGuid().ToString('N').Substring(0, 8)) $variables
    }
    foreach ($key in $values.Keys) {
        $definition = @($variables | Where-Object Name -EQ $key)
        if ($definition.Count -ne 1 -or $definition[0].Sensitive) {
            throw "Unexpected or sensitive input '$key' in the saved configuration. Remove it before continuing."
        }
    }

    $subscriptions = @(ConvertFrom-Json (Invoke-LabCommand $azure @('account', 'list', '--output', 'json', '--only-show-errors') -CaptureOutput))
    if ($subscriptions.Count -eq 0) {
        Write-Host 'Azure sign-in is required. Follow the device-code sign-in instructions.'
        Invoke-LabCommand $azure @('login', '--use-device-code', '--output', 'none', '--only-show-errors')
        $subscriptions = @(ConvertFrom-Json (Invoke-LabCommand $azure @('account', 'list', '--output', 'json', '--only-show-errors') -CaptureOutput))
    }
    $subscriptions = @($subscriptions | Where-Object state -EQ 'Enabled')
    if ($subscriptions.Count -eq 0) { throw 'No enabled Azure subscriptions are available for this account.' }
    if ($Resume) {
        $matches = @($subscriptions | Where-Object { $_.id -eq $metadata.subscriptionId -and $_.tenantId -eq $metadata.tenantId })
        if ($matches.Count -ne 1) { throw 'Sign in to the original subscription and tenant before resuming this environment.' }
        $subscription = $matches[0]
    }
    else {
        $subscription = Read-LabChoice 'Choose the Azure subscription (billable resources will be created here)' $subscriptions {
            param($item) "$($item.name) ($($item.id))"
        }
    }
    Write-Host "`nLab: $Lab; environment: $EnvironmentName; subscription: $($subscription.name)"
    if ($Lab -eq 'backup-saphana') { Write-Host 'A 16 GB VM size is suggested for HANA; installation and manual backup setup take additional time.' }
    $secrets = @{}
    try {
        if (-not (Read-LabConfiguration $variables $values $secrets)) { Write-Host 'Cancelled. No files or resources were changed.'; return }
        if (-not $Resume) {
            New-Item -ItemType Directory -Path $directory | Out-Null
            foreach ($file in @('variables.tf', 'outputs.tf', 'providers.tf', 'versions.tf', 'terraform.tfvars.example')) {
                Copy-Item -LiteralPath (Join-Path $example $file) -Destination (Join-Path $directory $file)
            }
            $main = @('module "lab" {', "  source = `"../../modules/labs/$Lab`"", '')
            $main += $variables | ForEach-Object { "  $($_.Name) = var.$($_.Name)" }
            $main += '}'
            Set-Content -LiteralPath (Join-Path $directory 'main.tf') -Value $main -Encoding utf8
            $metadata = @{
                schemaVersion = 1
                lab = $Lab
                name = $EnvironmentName
                subscriptionId = $subscription.id
                tenantId = $subscription.tenantId
            }
            $metadata | ConvertTo-Json | Set-Content -LiteralPath $metadataPath -Encoding utf8
        }
        ConvertTo-Json -InputObject $values -Depth 100 | Set-Content -LiteralPath $valuesPath -Encoding utf8
        Write-Host "Configuration saved in $directory. Passwords are not saved in the variable file."
        Write-Host "Retry or change settings with: .\scripts\New-Lab.ps1 -EnvironmentName $EnvironmentName -Resume"
        Invoke-LabDeployment $terraform $directory $EnvironmentName $subscription $variables $secrets -PreviewOnly:$PlanOnly
    }
    finally {
        foreach ($secret in $secrets.Values) { $secret.Dispose() }
        $secrets.Clear()
    }
    if ($Lab -eq 'backup-saphana') { Write-Host 'HANA backup registration still requires the manual steps in labs\examples\backup-saphana\README.' }
}

if ($MyInvocation.InvocationName -ne '.') {
    Start-LabWizard @PSBoundParameters
}
