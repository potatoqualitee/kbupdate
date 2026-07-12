[CmdletBinding()]
param (
    [string]$OutputPath = (Join-Path (Split-Path $PSScriptRoot -Parent) '.artifacts\kbupdate-library'),

    [string]$CatalogFingerprint,

    [string]$CatalogETag,

    [string]$CatalogLastModified,

    [string]$CatalogContentLength
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot -Parent

$requiredModules = 'PSFramework', 'PSSQLite', 'kbupdate-library'
foreach ($requiredModule in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $requiredModule | Select-Object -First 1)) {
        throw "Required module $requiredModule is not installed."
    }
    Import-Module -Name $requiredModule -ErrorAction Stop
}

Import-Module (Join-Path $repositoryRoot 'kbupdate.psm1') -Force -ErrorAction Stop

$database = Update-KbDatabase -EnableException
$database = @($database | Where-Object { $PSItem -is [System.IO.FileInfo] }) | Select-Object -Last 1
if (-not $database -or -not (Test-Path -LiteralPath $database.FullName -PathType Leaf)) {
    throw 'Update-KbDatabase did not return an updated SQLite database.'
}

$libraryModule = Get-Module -Name kbupdate-library | Select-Object -Last 1
$libraryRoot = Split-Path $libraryModule.Path -Parent
$libraryData = Join-Path $libraryRoot 'library'

# Force the module initialization path to rebuild its precomputed lookup caches from the
# updated SQLite database. Each GitHub Actions step has a fresh PowerShell process, but this
# script also clears the current process so it behaves the same way when run locally.
Get-Job -Name kbupdate_cache_import -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue
Remove-Variable -Name kbupdate -Scope Global -Force -ErrorAction SilentlyContinue
Get-ChildItem -LiteralPath $libraryData -Filter '*.dat' -File -ErrorAction SilentlyContinue |
    Remove-Item -Force
Remove-Module kbupdate -Force -ErrorAction SilentlyContinue
Import-Module (Join-Path $repositoryRoot 'kbupdate.psm1') -Force -ErrorAction Stop

$manifestSource = $libraryModule.Path
$manifest = Import-PowerShellDataFile -Path $manifestSource
[version]$currentVersion = $manifest.ModuleVersion
[version]$candidateVersion = '{0}.{1}.{2}' -f $currentVersion.Major, $currentVersion.Minor, ($currentVersion.Build + 1)

if (Test-Path -LiteralPath $OutputPath) {
    Remove-Item -LiteralPath $OutputPath -Recurse -Force
}
$outputLibrary = New-Item -ItemType Directory -Path (Join-Path $OutputPath 'library') -Force
$outputManifest = Join-Path $OutputPath 'kbupdate-library.psd1'

Copy-Item -LiteralPath $manifestSource -Destination $outputManifest
Update-ModuleManifest -Path $outputManifest -ModuleVersion $candidateVersion
Copy-Item -LiteralPath $database.FullName -Destination $outputLibrary.FullName
Get-ChildItem -LiteralPath $libraryData -Filter '*.dat' -File |
    Copy-Item -Destination $outputLibrary.FullName

$db = Join-Path $outputLibrary.FullName 'kb.sqlite'
$metadata = [ordered]@{
    GeneratedAtUtc       = (Get-Date).ToUniversalTime().ToString('o')
    CandidateVersion     = "$candidateVersion"
    PreviousVersion      = "$currentVersion"
    CatalogFingerprint   = $CatalogFingerprint
    CatalogETag          = $CatalogETag
    CatalogLastModified  = $CatalogLastModified
    CatalogContentLength = $CatalogContentLength
    DatabaseBytes        = (Get-Item -LiteralPath $db).Length
    KbRows               = (Invoke-SqliteQuery -DataSource $db -Query 'select count(*) as Count from Kb').Count
    LinkRows             = (Invoke-SqliteQuery -DataSource $db -Query 'select count(*) as Count from Link').Count
    NewestDateAdded      = (Invoke-SqliteQuery -DataSource $db -Query 'select max(DateAdded) as Value from Kb').Value
}
$metadata | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutputPath 'refresh-metadata.json') -Encoding UTF8

Get-Item -LiteralPath $OutputPath
