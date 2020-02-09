<#
    .SYNOPSIS
        Unit tests for xWindowsUpdate
    .DESCRIPTION
        Unit tests for  xWindowsUpdate

    .NOTES
        Code in HEADER and FOOTER regions are standard and may be moved into DSCResource.Tools in
        Future and therefore should not be altered if possible.
#>


$Script:DSCModuleName = 'xWindowsUpdate' # Example xNetworking
$Script:DSCResourceName = 'MSFT_xWindowsUpdate' # Example MSFT_xFirewall

#region HEADER
[String] $moduleRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path))
if ( (-not (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
    (-not (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) ) {
    & git @('clone', 'https://github.com/PowerShell/DscResource.Tests.git', (Join-Path -Path $moduleRoot -ChildPath '\DSCResource.Tests\'))
} else {
    & git @('-C', (Join-Path -Path $moduleRoot -ChildPath '\DSCResource.Tests\'), 'pull')
}
Import-Module (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $Script:DSCModuleName `
    -DSCResourceName $Script:DSCResourceName `
    -TestType Unit
#endregion

# Begin Testing
try {

    #region Pester Tests

    # The InModuleScope command allows you to perform white-box unit testing on the internal
    # (non-exported) code of a Script Module.
    InModuleScope $Script:DSCResourceName {

        #region Function Get-TargetResource
        Describe "$($Script:DSCResourceName)\Get-TargetResource" {
            Mock Get-HotFix -MockWith { return [PSCustomObject]@{HotFixId = 'KB123456' } } -Verifiable
            Context 'Get hotfix' {

                $getResult = (Get-TargetResource -Path 'C:\test.msu' -Id 'KB123457' )

                it 'should have called get-hotfix' {
                    Assert-VerifiableMock
                }

                it 'should return id="KB123456"' {
                    $getResult.id | should be 'KB123456'
                }

                it 'should return path=""' {
                    $getResult.path | should be ([String]::Empty)
                }

                it 'should return log=""' {
                    $getResult.log | should be ([String]::Empty)
                }
            }
        }
        Describe "$($Script:DSCResourceName)\Test-TargetResource" {
            Context 'Hot fix exists' {
                Mock Get-HotFix -MockWith { return [PSCustomObject]@{HotFixId = 'KB123456' } } -Verifiable

                $getResult = (Test-TargetResource -Path 'C:\test.msu' -Id 'KB123456' )

                it 'should have called get-hotfix' {
                    Assert-VerifiableMock
                }

                it 'should return $true' {
                    $getResult | should be $true
                }
            }

            Context 'Hot fix does not exists' {
                Mock Get-HotFix -MockWith { return [PSCustomObject]@{HotFixId = 'KB123456' } } -Verifiable

                $getResult = (Test-TargetResource -Path 'C:\test.msu' -Id 'KB123457' )

                it 'should have called get-hotfix' {
                    Assert-VerifiableMock
                }

                it 'should return $true' {
                    $getResult | should be $true
                }
            }
        }
    }
    #endregion
} finally {
    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion
}