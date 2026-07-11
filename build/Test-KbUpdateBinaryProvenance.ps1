<#
.SYNOPSIS
Verifies every vendored DLL against the tracked SHA-256 manifest.

.DESCRIPTION
Fails when a vendored DLL is missing, an untracked DLL is present, or a file hash differs from library/binary-hashes.sha256.

.EXAMPLE
./build/Test-KbUpdateBinaryProvenance.ps1

Verifies the vendored binary inventory from the repository root.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifestPath = Join-Path $repositoryRoot 'library/binary-hashes.sha256'

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Binary hash manifest not found: $manifestPath"
}

$expected = @{}
foreach ($line in Get-Content -LiteralPath $manifestPath) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('#')) {
        continue
    }

    if ($line -notmatch '^([A-Fa-f0-9]{64}) \*(.+)$') {
        throw "Invalid binary hash manifest entry: $line"
    }

    $relativePath = $Matches[2].Replace('/', [IO.Path]::DirectorySeparatorChar)
    $expected[$relativePath] = $Matches[1].ToUpperInvariant()
}

$actualFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'library') -Recurse -Filter '*.dll' -File |
        ForEach-Object { $PSItem.FullName.Substring($repositoryRoot.Length + 1) }
)

$missing = @($expected.Keys | Where-Object { $PSItem -notin $actualFiles })
$untracked = @($actualFiles | Where-Object { $PSItem -notin $expected.Keys })
$changed = @()

foreach ($relativePath in $expected.Keys) {
    $fullPath = Join-Path $repositoryRoot $relativePath
    if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
        $actualHash = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
        if ($actualHash -ne $expected[$relativePath]) {
            $changed += $relativePath
        }
    }
}

if ($missing -or $untracked -or $changed) {
    $messages = @()
    if ($missing) {
        $messages += "Missing DLLs: $($missing -join ', ')"
    }
    if ($untracked) {
        $messages += "Untracked DLLs: $($untracked -join ', ')"
    }
    if ($changed) {
        $messages += "Hash mismatches: $($changed -join ', ')"
    }
    throw ($messages -join [Environment]::NewLine)
}

Write-Host "Verified $($actualFiles.Count) vendored DLLs against $manifestPath"
