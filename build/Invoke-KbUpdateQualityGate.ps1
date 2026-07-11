<#
.SYNOPSIS
Runs the deterministic kbupdate quality gate.

.DESCRIPTION
Bootstraps disposable dependencies when requested, parses repository-owned PowerShell, validates the module manifest, runs PSScriptAnalyzer errors, imports the module, and runs the Pester 5 unit suite. Vendored code under library is intentionally excluded.

.PARAMETER Bootstrap
Downloads missing test dependencies into .artifacts/Modules.

.PARAMETER SkipAnalyzer
Skips PSScriptAnalyzer. Syntax, manifest, import, and unit tests still run.

.PARAMETER SkipTests
Skips the Pester unit suite.

.EXAMPLE
./build/Invoke-KbUpdateQualityGate.ps1 -Bootstrap

Bootstraps disposable dependencies and runs the complete deterministic gate.
#>
[CmdletBinding()]
param(
    [switch]$Bootstrap,
    [switch]$SkipAnalyzer,
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$moduleCache = Join-Path $repositoryRoot '.artifacts/Modules'
$requiredModules = @(
    @{ Name = 'Pester'; MinimumVersion = [version]'5.5.0' }
    @{ Name = 'PSScriptAnalyzer'; MinimumVersion = [version]'1.21.0' }
    @{ Name = 'PSFramework'; MinimumVersion = [version]'1.7.227' }
    @{ Name = 'PSSQLite'; MinimumVersion = [version]'1.1.0' }
    @{ Name = 'kbupdate-library'; MinimumVersion = [version]'1.1.24' }
)

if ($Bootstrap) {
    $null = New-Item -ItemType Directory -Path $moduleCache -Force
    foreach ($requiredModule in $requiredModules) {
        $available = Get-Module -ListAvailable -Name $requiredModule.Name |
            Where-Object Version -GE $requiredModule.MinimumVersion |
            Select-Object -First 1
        if (-not $available) {
            $saveParameters = @{
                Name           = $requiredModule.Name
                MinimumVersion = $requiredModule.MinimumVersion
                Path           = $moduleCache
                Repository     = 'PSGallery'
                Force          = $true
            }
            Save-Module @saveParameters
        }
    }
}

if (Test-Path -LiteralPath $moduleCache) {
    $env:PSModulePath = "$moduleCache$([IO.Path]::PathSeparator)$env:PSModulePath"
}

$missingModules = foreach ($requiredModule in $requiredModules) {
    $available = Get-Module -ListAvailable -Name $requiredModule.Name |
        Where-Object Version -GE $requiredModule.MinimumVersion |
        Select-Object -First 1
    if (-not $available) {
        $requiredModule.Name
    }
}

if ($missingModules) {
    throw "Missing test dependencies: $($missingModules -join ', '). Run this script with -Bootstrap."
}

Write-Host 'Parsing repository-owned PowerShell...' -ForegroundColor Cyan
$ownedPaths = @(
    (Join-Path $repositoryRoot 'public')
    (Join-Path $repositoryRoot 'private')
    (Join-Path $repositoryRoot 'build')
    (Join-Path $repositoryRoot 'tests/unit')
    (Join-Path $repositoryRoot 'tests/integration')
    (Join-Path $repositoryRoot '.claude/hooks')
)
$powerShellFiles = foreach ($ownedPath in $ownedPaths) {
    if (Test-Path -LiteralPath $ownedPath) {
        Get-ChildItem -LiteralPath $ownedPath -Recurse -File -Include '*.ps1', '*.psm1', '*.psd1'
    }
}
$powerShellFiles += Get-Item -LiteralPath (Join-Path $repositoryRoot 'kbupdate.psm1')
$powerShellFiles += Get-Item -LiteralPath (Join-Path $repositoryRoot 'kbupdate.psd1')

$syntaxFailures = foreach ($file in $powerShellFiles | Sort-Object FullName -Unique) {
    $tokens = $null
    $parseErrors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    foreach ($parseError in $parseErrors) {
        '{0}:{1}: {2}' -f $file.FullName, $parseError.Extent.StartLineNumber, $parseError.Message
    }
}
if ($syntaxFailures) {
    throw "PowerShell syntax failures:$([Environment]::NewLine)$($syntaxFailures -join [Environment]::NewLine)"
}

Write-Host 'Validating module manifest...' -ForegroundColor Cyan
$manifestPath = Join-Path $repositoryRoot 'kbupdate.psd1'
$manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
$publicFunctions = Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'public') -File -Filter '*.ps1' |
    Select-Object -ExpandProperty BaseName |
    Sort-Object
$exportedFunctions = @($manifest.ExportedFunctions.Keys) | Sort-Object
$manifestDifference = Compare-Object -ReferenceObject $publicFunctions -DifferenceObject $exportedFunctions
if ($manifestDifference) {
    throw "Manifest exports do not match public functions: $($manifestDifference | Out-String)"
}

if (-not $SkipAnalyzer) {
    Write-Host 'Running PSScriptAnalyzer error checks...' -ForegroundColor Cyan
    Import-Module PSScriptAnalyzer -Force -ErrorAction Stop
    $analysisFailures = foreach ($path in @('public', 'private', 'kbupdate.psm1')) {
        Invoke-ScriptAnalyzer -Path (Join-Path $repositoryRoot $path) -Recurse -Severity Error
    }
    if ($analysisFailures) {
        throw "PSScriptAnalyzer errors: $($analysisFailures | Format-Table -AutoSize | Out-String)"
    }
}

Write-Host 'Importing kbupdate...' -ForegroundColor Cyan
Remove-Module kbupdate -Force -ErrorAction Ignore
Import-Module $manifestPath -Force -ErrorAction Stop

if (-not $SkipTests) {
    Write-Host 'Running deterministic Pester tests...' -ForegroundColor Cyan
    Remove-Module Pester -Force -ErrorAction Ignore
    Import-Module Pester -MinimumVersion 5.5.0 -Force -ErrorAction Stop
    $configuration = New-PesterConfiguration
    $configuration.Run.Path = Join-Path $repositoryRoot 'tests/unit'
    $configuration.Run.PassThru = $true
    $configuration.Output.Verbosity = 'Detailed'
    $result = Invoke-Pester -Configuration $configuration
    if ($result.Result -ne 'Passed') {
        throw "Pester failed with result $($result.Result) and $($result.FailedCount) failed tests."
    }
}

Write-Host 'kbupdate quality gate passed.' -ForegroundColor Green
