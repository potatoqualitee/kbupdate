<#
.SYNOPSIS
Runs local-only live catalog and authorized lab integration tests.

.DESCRIPTION
Runs the Pester tests under tests/integration. The suite always probes the live Microsoft Update Catalog. When computer names and a credential are supplied, it also exercises kbupdate read-only operations against the authorized Windows lab.

Mutation is disabled by default. To install an update, the caller must supply AllowMutation, one explicit MutationComputerName, and one explicit MutationKb. Nothing in this runner is used by GitHub Actions.

.PARAMETER ComputerName
Authorized lab computers. If omitted, comma-separated names are read from KBUPDATE_LAB_COMPUTERS.

.PARAMETER Credential
Credential for the authorized lab computers. The credential remains in memory and is never serialized.

.PARAMETER IncludeDownloads
Downloads a small catalog fixture and verifies its file output.

.PARAMETER ScanNeededUpdates
Runs Windows Update Agent needed-update scans on every supplied lab computer.

.PARAMETER ScanFilePath
Uses an existing offline scan CAB for needed-update scans. The path must be usable by kbupdate for the selected targets.

.PARAMETER AllowMutation
Allows the explicitly named mutation update to be installed. Requires MutationComputerName and MutationKb.

.PARAMETER MutationComputerName
The one authorized lab computer that may be changed.

.PARAMETER MutationKb
The one KB identifier that may be installed.

.EXAMPLE
./build/Invoke-KbUpdateIntegration.ps1

Runs live catalog tests without requiring a lab.

.EXAMPLE
./build/Invoke-KbUpdateIntegration.ps1 -ComputerName $servers -Credential $credential -IncludeDownloads -ScanNeededUpdates

Runs catalog, download, remoting, inventory, and needed-update tests against the authorized lab.
#>
[CmdletBinding()]
param(
    [string[]]$ComputerName,
    [pscredential]$Credential,
    [switch]$IncludeDownloads,
    [switch]$ScanNeededUpdates,
    [string]$ScanFilePath,
    [switch]$AllowMutation,
    [string]$MutationComputerName,
    [string]$MutationKb
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$moduleCache = Join-Path $repositoryRoot '.artifacts/Modules'

if (-not $ComputerName -and $env:KBUPDATE_LAB_COMPUTERS) {
    $ComputerName = @(
        $env:KBUPDATE_LAB_COMPUTERS -split ',' |
            ForEach-Object { $PSItem.Trim() } |
            Where-Object { $PSItem }
    )
}

if ($ComputerName -and -not $Credential) {
    throw 'Credential is required when ComputerName or KBUPDATE_LAB_COMPUTERS supplies lab targets.'
}

if ($AllowMutation) {
    if (-not $MutationComputerName -or -not $MutationKb) {
        throw 'AllowMutation requires one explicit MutationComputerName and one explicit MutationKb.'
    }
    if ($MutationComputerName -notin $ComputerName) {
        throw 'MutationComputerName must also be present in ComputerName.'
    }
}

if (Test-Path -LiteralPath $moduleCache) {
    $env:PSModulePath = "$moduleCache$([IO.Path]::PathSeparator)$env:PSModulePath"
}

$requiredModules = 'Pester', 'PSFramework', 'PSSQLite', 'kbupdate-library'
$missingModules = foreach ($requiredModule in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $requiredModule | Select-Object -First 1)) {
        $requiredModule
    }
}
if ($missingModules) {
    throw "Missing integration dependencies: $($missingModules -join ', '). Run ./build/Invoke-KbUpdateQualityGate.ps1 -Bootstrap first."
}

$downloadPath = Join-Path $repositoryRoot '.artifacts/IntegrationDownloads'
$null = New-Item -ItemType Directory -Path $downloadPath -Force

$global:KbUpdateIntegrationContext = @{
    RepositoryRoot      = $repositoryRoot
    ComputerName        = @($ComputerName | Where-Object { -not [string]::IsNullOrWhiteSpace($PSItem) })
    Credential          = $Credential
    IncludeDownloads    = [bool]$IncludeDownloads
    ScanNeededUpdates   = [bool]$ScanNeededUpdates
    ScanFilePath        = $ScanFilePath
    AllowMutation       = [bool]$AllowMutation
    MutationComputerName = $MutationComputerName
    MutationKb          = $MutationKb
    DownloadPath        = $downloadPath
}

try {
    Import-Module Pester -MinimumVersion 5.5.0 -Force -ErrorAction Stop
    $configuration = New-PesterConfiguration
    $configuration.Run.Path = Join-Path $repositoryRoot 'tests/integration'
    $configuration.Run.PassThru = $true
    $configuration.Output.Verbosity = 'Detailed'
    $result = Invoke-Pester -Configuration $configuration
    if ($result.Result -ne 'Passed') {
        throw "Integration tests failed with result $($result.Result) and $($result.FailedCount) failed tests."
    }
} finally {
    Remove-Variable -Name KbUpdateIntegrationContext -Scope Global -ErrorAction Ignore
}

