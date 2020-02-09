<#
.SYNOPSIS
This script will invoke Pester tests, then serialize XML results and pull them in appveyor.yml

.DESCRIPTION
This script will invoke Pester tests, then serialize XML results and pull them in appveyor.yml

.PARAMETER Finalize
If Finalize is specified, we collect XML output, upload tests, and indicate build errors

.PARAMETER PSVersion
The version of PS

.PARAMETER TestFile
The output file

.PARAMETER ProjectRoot
The appveyor project root

.PARAMETER ModuleBase
The location of the module

.EXAMPLE
.\appveyor.pester.ps1
Executes the test

.EXAMPLE
.\appveyor.pester.ps1 -Finalize
Finalizes the tests
#>
param (
    $ModuleBase = $ENV:APPVEYOR_BUILD_FOLDER
)

& "$($ModuleBase)\tests\Pester.ps1"