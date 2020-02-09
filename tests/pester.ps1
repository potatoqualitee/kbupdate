param (
    $Show = "None"
)

Write-Host "Starting Tests" -ForegroundColor Green
if ($env:BUILD_BUILDURI -like "vstfs*") {
    Write-Host "Installing Pester" -ForegroundColor Cyan
    Install-Module Pester -Force -SkipPublisherCheck
    Write-Host "Installing PSFramework" -ForegroundColor Cyan
    Install-Module PSFramework -Force -SkipPublisherCheck
    Write-Host "Installing PSSQLite" -ForegroundColor Cyan
    Install-Module PSSQLite -Force -SkipPublisherCheck
    Write-Host "Installing PSSQLite" -ForegroundColor Cyan
    Install-Module PoshWSUS -Force -SkipPublisherCheck
    Write-Host "Installing kbupdate-library" -ForegroundColor Cyan
    Install-Module kbupdate-library -Force -SkipPublisherCheck -MinimumVersion 1.0.20
    Write-Host "Installing xWindowsUpdate" -ForegroundColor Cyan
    Install-Module xWindowsUpdate -Force -SkipPublisherCheck
}

Write-Host "Loading constants"
. "$PSScriptRoot\constants.ps1"

Write-Host "Importing Module"

Remove-Module kbupdate -ErrorAction Ignore
Import-Module "$PSScriptRoot\..\kbupdate.psd1"
Import-Module "$PSScriptRoot\..\kbupdate.psm1" -Force

$totalFailed = 0
$totalRun = 0

$testresults = @()
Write-Host "Proceeding with individual tests"
foreach ($file in (Get-ChildItem "$PSScriptRoot" -File -Filter "*.Tests.ps1")) {
    Write-Host "Executing $($file.Name)"
    $results = Invoke-Pester -Script $file.FullName -PassThru
    foreach ($result in $results) {
        $totalRun += $result.TotalCount
        $totalFailed += $result.FailedCount
        $result.TestResult | Where-Object { -not $_.Passed } | ForEach-Object {
            $name = $_.Name
            $testresults += [pscustomobject]@{
                Describe = $_.Describe
                Context  = $_.Context
                Name     = "It $name"
                Result   = $_.Result
                Message  = $_.FailureMessage
            }
        }
    }
}

$testresults | Sort-Object Describe, Context, Name, Result, Message | Format-List

if ($totalFailed -gt 0) {
    throw "$totalFailed / $totalRun tests failed"
}