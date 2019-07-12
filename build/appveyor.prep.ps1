Add-AppveyorTest -Name "appveyor.prep" -Framework NUnit -FileName "appveyor.prep.ps1" -Outcome Running
$sw = [system.diagnostics.stopwatch]::startNew()

#Get PSScriptAnalyzer (to check warnings)
Write-Host -Object "appveyor.prep: Install PSScriptAnalyzer" -ForegroundColor DarkGreen
Install-Module -Name PSScriptAnalyzer -Force -SkipPublisherCheck | Out-Null

#Get Pester (to run tests)
Write-Host -Object "appveyor.prep: Install Pester" -ForegroundColor DarkGreen
choco install pester | Out-Null

#Get PSFramework (dependency)
Write-Host -Object "appveyor.prep: Install PSFramework" -ForegroundColor DarkGreen
Install-Module -Name PSFramework -Force -SkipPublisherCheck | Out-Null

$null = mkdir C:\temp

$sw.Stop()
Update-AppveyorTest -Name "appveyor.prep" -Framework NUnit -FileName "appveyor.prep.ps1" -Outcome Passed -Duration $sw.ElapsedMilliseconds