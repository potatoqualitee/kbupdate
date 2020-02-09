<#
.Synopsis
   Unit tests for xWindowsUpdateAgent
.DESCRIPTION
   Unit tests for  xWindowsUpdateAgent

.NOTES
   Code in HEADER and FOOTER regions are standard and may be moved into DSCResource.Tools in
   Future and therefore should not be altered if possible.
#>


$Global:DSCModuleName = 'xWindowsUpdate' # Example xNetworking
$Global:DSCResourceName = 'MSFT_xWindowsUpdateAgent' # Example MSFT_xFirewall

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
    -DSCModuleName $Global:DSCModuleName `
    -DSCResourceName $Global:DSCResourceName `
    -TestType Unit
#endregion

# TODO: Other Optional Init Code Goes Here...

# Begin Testing
try {

    #region Pester Tests

    # The InModuleScope command allows you to perform white-box unit testing on the internal
    # (non-exported) code of a Script Module.
    InModuleScope $Global:DSCResourceName {

        #region Pester Test Initialization
        $Global:mockedSearchResultWithUpdate = [PSCustomObject] @{
            Updates = @{
                Count = 1
                Title = 'Mocked Update'
            }
        }

        $Global:mockedSearchResultWithoutUpdate = [PSCustomObject] @{
            Updates = @{
                Count = 0
            }
        }

        $Global:mockedSearchResultWithoutUpdatesProperty = [PSCustomObject] @{
        }

        $Global:mockedWuaDisableNotificationLevel = 'Disabled'
        $Global:mockedWuaOtherNotificationLevel = 'Notify before download'
        $Global:mockedWuaSystemInfoNoReboot = @{
            RebootRequired = $false
        }
        $Global:mockedWuaSystemInfoReboot = @{
            RebootRequired = $true
        }
        $Global:mockeWindowsUpdateServiceManager = [PSCustomObject]  @{
            Services = @(
                [PSCustomObject] @{
                    ServiceId          = '9482f4b4-e343-43b6-b170-9a65bc822c77'
                    IsDefaultAUService = $true
                    IsManaged          = $false
                }
            )
        }

        $Global:mockedMicrosoftUpdateServiceManager = [PSCustomObject]  @{
            Services = @(
                [PSCustomObject] @{
                    ServiceId          = '7971f918-a847-4430-9279-4a52d1efe18d'
                    IsDefaultAUService = $true
                    IsManaged          = $false
                }
                [PSCustomObject] @{
                    ServiceId          = '9482f4b4-e343-43b6-b170-9a65bc822c77'
                    IsDefaultAUService = $false
                    IsManaged          = $false
                }
            )
        }
        $testCategories = @('Security', 'Important')

        #endregion


        #region Function Get-TargetResource
        Describe "$($Global:DSCResourceName)\Get-TargetResource" {
            Mock Get-WuaServiceManager -MockWith { return $Global:mockeWindowsUpdateServiceManager }
            Mock New-object -MockWith { } -ParameterFilter { $ComObject -ne $null }
            Context 'MU service' {
                Mock  Get-WuaSearcher -MockWith {
                    return $null
                } -Verifiable

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaDisableNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoNoReboot
                } -Verifiable

                Mock Get-WuaServiceManager -MockWith { return $Global:mockedMicrosoftUpdateServiceManager }

                $getResult = (Get-TargetResource -IsSingleInstance 'yes' -UpdateNow $true -Category $testCategories -Notifications Disabled -Source WindowsUpdate )

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }
                it 'should return Category=$testCategories' {
                    $getResult.Category | should be $testCategories
                }

                it 'should return IsSingleInstance = Yes' {
                    $getResult.IsSingleInstance | should be 'Yes'
                }

                it "should return AutomaticUpdatesNotificationSetting = ${Global:mockedWuaDisableNotificationLevel}" {
                    $getResult.AutomaticUpdatesNotificationSetting | should be $Global:mockedWuaDisableNotificationLevel
                }

                it 'should return 0 update not installed ' {
                    $getResult.TotalUpdatesNotInstalled | should be 0
                }

                it 'should return reboot requied $false' {
                    $getResult.RebootRequired | should be $false
                }

                it 'should return Notifications=Disabled' {
                    $getResult.Notifications | should be 'Disabled'
                }

                it 'should return UpdateNome=$true' {
                    $getResult.UpdateNow | should be $true
                }
                it 'should return Source=MU' {
                    $getResult.Source | should be "MicrosoftUpdate"
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }
            Context 'null search result and disabled notification' {
                Mock  Get-WuaSearcher -MockWith {
                    return $null
                } -Verifiable

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaDisableNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoNoReboot
                } -Verifiable

                $getResult = (Get-TargetResource -IsSingleInstance 'yes' -UpdateNow $true -Category $testCategories -Notifications Disabled  -Source WindowsUpdate )

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }
                it 'should return Category=$testCategories' {
                    $getResult.Category | should be $testCategories
                }

                it 'should return IsSingleInstance = Yes' {
                    $getResult.IsSingleInstance | should be 'Yes'
                }

                it "should return AutomaticUpdatesNotificationSetting = ${Global:mockedWuaDisableNotificationLevel}" {
                    $getResult.AutomaticUpdatesNotificationSetting | should be $Global:mockedWuaDisableNotificationLevel
                }

                it 'should return 0 update not installed ' {
                    $getResult.TotalUpdatesNotInstalled | should be 0
                }

                it 'should return reboot requied $false' {
                    $getResult.RebootRequired | should be $false
                }

                it 'should return Notifications=Disabled' {
                    $getResult.Notifications | should be 'Disabled'
                }

                it 'should return UpdateNome=$true' {
                    $getResult.UpdateNow | should be $true
                }
                it 'should return Source=WU' {
                    $getResult.Source | should be "WindowsUpdate"
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }
            Context 'no updates property and disabled notification' {
                Mock  Get-WuaSearcher -MockWith {
                    return $Global:mockedSearchResultWithoutUpdatesProperty
                } -Verifiable

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaDisableNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoNoReboot
                } -Verifiable

                $getResult = (Get-TargetResource -IsSingleInstance 'yes' -UpdateNow $true -Category $testCategories -Notifications Disabled -Source WindowsUpdate )

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }

                it 'should return Category=$testCategories' {
                    $getResult.Category | should be $testCategories
                }

                it 'should return IsSingleInstance = Yes' {
                    $getResult.IsSingleInstance | should be 'Yes'
                }

                it "should return AutomaticUpdatesNotificationSetting = ${Global:mockedWuaDisableNotificationLevel}" {
                    $getResult.AutomaticUpdatesNotificationSetting | should be $Global:mockedWuaDisableNotificationLevel
                }

                it 'should return 0 update not installed ' {
                    $getResult.TotalUpdatesNotInstalled | should be 0
                }

                it 'should return reboot requied $false' {
                    $getResult.RebootRequired | should be $false
                }

                it 'should return UpdateNow=$true' {
                    $getResult.UpdateNow | should be $true
                }

                it 'should return Notifications=Disabled' {
                    $getResult.Notifications | should be 'Disabled'
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }
            Context 'no updates and disabled notification' {
                Mock  Get-WuaSearcher -MockWith {
                    return $Global:mockedSearchResultWithoutUpdate
                } -Verifiable

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaDisableNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoNoReboot
                } -Verifiable

                $getResult = (Get-TargetResource -IsSingleInstance 'yes' -UpdateNow $true -Category $testCategories -Notifications Disabled -Source WindowsUpdate )

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }

                it 'should return Category=$testCategories' {
                    $getResult.Category | should be $testCategories
                }

                it 'should return IsSingleInstance = Yes' {
                    $getResult.IsSingleInstance | should be 'Yes'
                }

                it "should return AutomaticUpdatesNotificationSetting = ${Global:mockedWuaDisableNotificationLevel}" {
                    $getResult.AutomaticUpdatesNotificationSetting | should be $Global:mockedWuaDisableNotificationLevel
                }

                it 'should return 0 update not installed ' {
                    $getResult.TotalUpdatesNotInstalled | should be 0
                }

                it 'should return reboot requied $false' {
                    $getResult.RebootRequired | should be $false
                }

                it 'should return UpdateNow=$true' {
                    $getResult.UpdateNow | should be $true
                }

                it 'should return Notifications=Disabled' {
                    $getResult.Notifications | should be 'Disabled'
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }
            Context 'no updates , disabled notification, and reboot required' {
                Mock  Get-WuaSearcher -MockWith {
                    return $Global:mockedSearchResultWithoutUpdate
                } -Verifiable

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaDisableNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoReboot
                } -Verifiable

                $getResult = (Get-TargetResource -IsSingleInstance 'yes' -UpdateNow $true -Category $testCategories -Notifications Disabled -Source WindowsUpdate )

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }

                it 'should return Category=$testCategories' {
                    $getResult.Category | should be $testCategories
                }

                it 'should return Notifications=Disabled' {
                    $getResult.Notifications | should be 'Disabled'
                }

                it 'should return UpdateNow=$false' {
                    $getResult.UpdateNow | should be $false
                }

                it 'should return IsSingleInstance = Yes' {
                    $getResult.IsSingleInstance | should be 'Yes'
                }

                it "should return AutomaticUpdatesNotificationSetting = ${Global:mockedWuaDisableNotificationLevel}" {
                    $getResult.AutomaticUpdatesNotificationSetting | should be $Global:mockedWuaDisableNotificationLevel
                }

                it 'should return 0 update not installed ' {
                    $getResult.TotalUpdatesNotInstalled | should be 0
                }

                it 'should return reboot requied $true' {
                    $getResult.RebootRequired | should be $true
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }
            Context 'updates and disable notification' {
                Mock  Get-WuaSearcher -MockWith {
                    return $Global:mockedSearchResultWithUpdate
                } -Verifiable

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaDisableNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoNoReboot
                } -Verifiable

                $getResult = (Get-TargetResource -IsSingleInstance 'yes' -UpdateNow $true -Category $testCategories  -Source WindowsUpdate)

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }

                it 'should return Category=$testCategories' {
                    $getResult.Category | should be $testCategories
                }

                it 'should return Notifications=Disabled' {
                    $getResult.Notifications | should be 'Disabled'
                }

                it 'should return UpdateNow=$false' {
                    $getResult.UpdateNow | should be $false
                }

                it 'should return IsSingleInstance = Yes' {
                    $getResult.IsSingleInstance | should be 'Yes'
                }

                it "should return AutomaticUpdatesNotificationSetting = $Global:mockedWuaDisableNotificationLevel" {
                    $getResult.AutomaticUpdatesNotificationSetting | should be $Global:mockedWuaDisableNotificationLevel
                }

                it 'should return 1 update not installed ' {
                    $getResult.TotalUpdatesNotInstalled | should be 1
                }

                it 'should return reboot requied $false' {
                    $getResult.RebootRequired | should be $false
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }
            Context 'updates and other notification' {
                Mock  Get-WuaSearcher -MockWith {
                    return $Global:mockedSearchResultWithUpdate
                } -Verifiable

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaOtherNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoNoReboot
                } -Verifiable

                $getResult = (Get-TargetResource -IsSingleInstance 'yes' -UpdateNow $true -Category $testCategories  -Source WindowsUpdate)

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }

                it 'should return Category=$testCategories' {
                    $getResult.Category | should be $testCategories
                }

                it 'should return Notifications=Notify before Download' {
                    $getResult.Notifications | should be 'Notify before Download'
                }

                it 'should return UpdateNow=$false' {
                    $getResult.UpdateNow | should be $false
                }

                it 'should return IsSingleInstance = Yes' {
                    $getResult.IsSingleInstance | should be 'Yes'
                }

                it "should return AutomaticUpdatesNotificationSetting = $Global:mockedWuaOtherNotificationLevel" {
                    $getResult.AutomaticUpdatesNotificationSetting | should be $Global:mockedWuaOtherNotificationLevel
                }

                it 'should return 1 update not installed ' {
                    $getResult.TotalUpdatesNotInstalled | should be 1
                }

                it 'should return reboot requied $false' {
                    $getResult.RebootRequired | should be $false
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }
        }
        #endregion


        #region Function Test-TargetResource
        Describe "$($Global:DSCResourceName)\Test-TargetResource" {
            Mock Get-WuaServiceManager -MockWith { return $Global:mockeWindowsUpdateServiceManager }
            Mock New-object -MockWith { } -ParameterFilter { $ComObject -ne $null }
            Context 'Ensure UpToDate with no updates and disabled notification and wu service' {
                Mock  Get-WuaSearcher -MockWith {
                    return $Global:mockedSearchResultWithoutUpdate
                } -Verifiable

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaDisableNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoNoReboot
                } -Verifiable

                it 'should return $true' {
                    (Test-TargetResource -IsSingleInstance 'yes' -UpdateNow $true -Category $testCategories -Source MicrosoftUpdate  -verbose) | should be $false
                }

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }

            Context 'Ensure UpToDate with no updates and disabled notification and mu service' {
                Mock  Get-WuaSearcher -MockWith {
                    return $Global:mockedSearchResultWithoutUpdate
                } -Verifiable

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaDisableNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoNoReboot
                } -Verifiable

                Mock Get-WuaServiceManager -MockWith { return $Global:mockedMicrosoftUpdateServiceManager }

                it 'should return $true' {
                    (Test-TargetResource -IsSingleInstance 'yes' -UpdateNow $true -Category $testCategories -Source MicrosoftUpdate  -verbose) | should be $true
                }

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }

            Context 'Ensure UpToDate with no updates and disabled notification' {
                Mock  Get-WuaSearcher -MockWith {
                    return $Global:mockedSearchResultWithoutUpdate
                } -Verifiable

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaDisableNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoNoReboot
                } -Verifiable

                it 'should return $true' {
                    (Test-TargetResource -IsSingleInstance 'yes' -UpdateNow $true -Category $testCategories  -verbose  -Source WindowsUpdate) | should be $true
                }

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }
            Context 'Ensure UpToDate with no updates, disabled notification and reboot requirde' {
                Mock  Get-WuaSearcher -MockWith {
                    return $Global:mockedSearchResultWithoutUpdate
                } -Verifiable

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaDisableNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoReboot
                } -Verifiable

                it 'should return $false' {
                    (Test-TargetResource  -IsSingleInstance 'yes' -UpdateNow $true -Category $testCategories -verbose  -Source WindowsUpdate) | should be $false
                }

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }
            Context 'Ensure UpToDate with updates and disabled notification' {
                Mock  Get-WuaSearcher -MockWith {
                    return $Global:mockedSearchResultWithUpdate
                } -Verifiable

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaDisableNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoNoReboot
                } -Verifiable

                it 'should return $false' {
                    (Test-TargetResource -IsSingleInstance 'yes' -UpdateNow $true -Category $testCategories -verbose  -Source WindowsUpdate) | should be $false
                }

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }
            Context 'Ensure Disable with updates and disable notification' {
                Mock  Get-WuaSearcher -MockWith {
                    return $Global:mockedSearchResultWithUpdate
                }

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaDisableNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoNoReboot
                }

                it 'should return $true' {
                    (Test-TargetResource  -IsSingleInstance 'yes' -UpdateNow $false -Notifications Disabled -verbose  -Source WindowsUpdate) | should be $true
                }

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }

                it 'should not have called the Get-WuaSystemInfo mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName Get-WuaSystemInfo -Times 0
                }

                it 'should not have called the get-wuasearcher mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName Get-WuaSearcher -Times 0
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }
            Context 'Ensure Disable with updates and other notification' {
                Mock  Get-WuaSearcher -MockWith {
                    return $Global:mockedSearchResultWithUpdate
                }

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaOtherNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoNoReboot
                }

                it 'should return $false' {
                    (Test-TargetResource -IsSingleInstance 'yes' -UpdateNow $false -Notifications Disabled -verbose  -Source WindowsUpdate) | should be $false
                }

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }

                it 'should not have called the Get-WuaSystemInfo mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName Get-WuaSystemInfo -Times 0
                }

                it 'should not have called the get-wuasearcher mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName Get-WuaSearcher -Times 0
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }

            Context 'Ensure UpToDate with updates and other notification' {
                Mock  Get-WuaSearcher -MockWith {
                    return $Global:mockedSearchResultWithUpdate
                } -Verifiable

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaOtherNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoNoReboot
                } -Verifiable

                it 'should return $true' {
                    (Test-TargetResource -IsSingleInstance 'yes' -UpdateNow $true -verbose -Category $testCategories -Source WindowsUpdate) | should be $false
                }

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }
            Context 'Ensure UpdateNow = $false with updates and other notification' {
                Mock  Get-WuaSearcher -MockWith {
                    return $Global:mockedSearchResultWithUpdate
                }

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaOtherNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoNoReboot
                }

                it 'should return $true' {
                    (Test-TargetResource -IsSingleInstance 'yes' -UpdateNow $false -verbose -Category $testCategories -Source WindowsUpdate) | should be $true
                }

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }

                it 'should not have called the Get-WuaSystemInfo mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName Get-WuaSystemInfo -Times 0
                }

                it 'should not have called the get-wuasearcher mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName Get-WuaSearcher -Times 0
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }
        }
        #endregion


        #region Function Set-TargetResource
        Describe "$($Global:DSCResourceName)\Set-TargetResource" {
            Mock Get-WuaServiceManager -MockWith { return $Global:mockeWindowsUpdateServiceManager }
            Mock New-object -MockWith { } -ParameterFilter { $ComObject -ne $null }
            Context 'Ensure UpToDate with null search results, disabled notification, and reboot required' {
                BeforeAll {
                    $global:DSCMachineStatus = $null
                }
                AfterAll {
                    $global:DSCMachineStatus = $null
                }

                Mock  Get-WuaSearcher -MockWith {
                    return $null
                } -Verifiable

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaDisableNotificationLevel
                } -Verifiable

                Mock Get-WuaRebootRequired -MockWith {
                    return $true
                } -Verifiable

                Mock Invoke-WuaDownloadUpdates -MockWith { }
                Mock Invoke-WuaInstallUpdates -MockWith { }
                Mock Set-WuaAuNotificationLevel -MockWith { }

                it 'should not Throw' {
                    try
                    { Set-TargetResource -IsSingleInstance 'yes' -UpdateNow $true -verbose -Category $testCategories  -Source WindowsUpdate | should be $null }
                    catch {
                        $_ | should be $null
                    }
                }

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0 -ParameterFilter { $ComObject -ne $null }
                }

                it 'should not have changed wua' {
                    Assert-MockCalled -CommandName Invoke-WuaDownloadUpdates -Times 0
                    Assert-MockCalled -CommandName Invoke-WuaInstallUpdates -Times 0
                    Assert-MockCalled -CommandName Set-WuaAuNotificationLevel -Times 0
                }

                it 'Should have triggered a reboot' {
                    $global:DSCMachineStatus | should be 1
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }
            Context 'Ensure UpToDate with no updates, mu and disabled notification' {
                BeforeAll {
                    $global:DSCMachineStatus = $null
                }
                AfterAll {
                    $global:DSCMachineStatus = $null
                }

                Mock  Get-WuaSearcher -MockWith {
                    return $Global:mockedSearchResultWithoutUpdate
                } -Verifiable

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaDisableNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoNoReboot
                } -Verifiable
                mock Add-WuaService -MockWith { } -Verifiable
                mock Remove-WuaService -MockWith { }
                Mock Invoke-WuaDownloadUpdates -MockWith { }
                Mock Invoke-WuaInstallUpdates -MockWith { }
                Mock Set-WuaAuNotificationLevel -MockWith { }

                it 'should not Throw' {
                    { Set-TargetResource -IsSingleInstance 'yes'  -UpdateNow $true -verbose -Category $testCategories -Source MicrosoftUpdate } | should not throw
                }

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }

                it 'should not have changed wua' {
                    Assert-MockCalled -CommandName Invoke-WuaDownloadUpdates -Times 0
                    Assert-MockCalled -CommandName Invoke-WuaInstallUpdates -Times 0
                    Assert-MockCalled -CommandName Set-WuaAuNotificationLevel -Times 0
                }

                it 'Should not have triggered a reboot' {
                    $global:DSCMachineStatus | should be $null
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }

            Context 'Ensure UpToDate with no updates, mu and disabled notification' {
                BeforeAll {
                    $global:DSCMachineStatus = $null
                }
                AfterAll {
                    $global:DSCMachineStatus = $null
                }

                Mock  Get-WuaSearcher -MockWith {
                    return $Global:mockedSearchResultWithoutUpdate
                } -Verifiable

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaDisableNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoNoReboot
                } -Verifiable
                mock Add-WuaService -MockWith { }
                mock Remove-WuaService -MockWith { }
                Mock Invoke-WuaDownloadUpdates -MockWith { }
                Mock Invoke-WuaInstallUpdates -MockWith { }
                Mock Set-WuaAuNotificationLevel -MockWith { }

                it 'should not Throw' {
                    { Set-TargetResource -IsSingleInstance 'yes'  -UpdateNow $true -verbose -Category $testCategories -Source WindowsUpdate } | should not throw
                }

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }

                it 'should not have changed wua' {
                    Assert-MockCalled -CommandName Invoke-WuaDownloadUpdates -Times 0
                    Assert-MockCalled -CommandName Invoke-WuaInstallUpdates -Times 0
                    Assert-MockCalled -CommandName Set-WuaAuNotificationLevel -Times 0
                    Assert-MockCalled -CommandName Add-WuaService  -Times 0
                    Assert-MockCalled -CommandName Remove-WuaService  -Times 0
                }

                it 'Should not have triggered a reboot' {
                    $global:DSCMachineStatus | should be $null
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }

            Context 'Ensure UpToDate with no updates, mu and disabled notification' {
                BeforeAll {
                    $global:DSCMachineStatus = $null
                }
                AfterAll {
                    $global:DSCMachineStatus = $null
                }

                Mock  Get-WuaSearcher -MockWith {
                    return $Global:mockedSearchResultWithoutUpdate
                } -Verifiable

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaDisableNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoNoReboot
                } -Verifiable

                Mock Get-WuaServiceManager -MockWith { return $Global:mockedMicrosoftUpdateServiceManager } -Verifiable
                mock Add-WuaService -MockWith { }
                mock Remove-WuaService -MockWith { } -Verifiable
                Mock Invoke-WuaDownloadUpdates -MockWith { }
                Mock Invoke-WuaInstallUpdates -MockWith { }
                Mock Set-WuaAuNotificationLevel -MockWith { }

                it 'should not Throw' {
                    { Set-TargetResource -IsSingleInstance 'yes'  -UpdateNow $true -verbose -Category $testCategories -Source WindowsUpdate } | should not throw
                }

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }

                it 'should not have changed wua' {
                    Assert-MockCalled -CommandName Invoke-WuaDownloadUpdates -Times 0
                    Assert-MockCalled -CommandName Invoke-WuaInstallUpdates -Times 0
                    Assert-MockCalled -CommandName Set-WuaAuNotificationLevel -Times 0
                    Assert-MockCalled -CommandName Add-WuaService  -Times 0
                }

                it 'Should not have triggered a reboot' {
                    $global:DSCMachineStatus | should be $null
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }

            Context 'Ensure UpToDate with no updates and disabled notification' {
                BeforeAll {
                    $global:DSCMachineStatus = $null
                }
                AfterAll {
                    $global:DSCMachineStatus = $null
                }

                Mock  Get-WuaSearcher -MockWith {
                    return $Global:mockedSearchResultWithoutUpdate
                } -Verifiable

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaDisableNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoNoReboot
                } -Verifiable

                Mock Invoke-WuaDownloadUpdates -MockWith { }
                Mock Invoke-WuaInstallUpdates -MockWith { }
                Mock Set-WuaAuNotificationLevel -MockWith { }

                it 'should not Throw' {
                    { Set-TargetResource -IsSingleInstance 'yes'  -UpdateNow $true -verbose -Category $testCategories  -Source WindowsUpdate } | should not throw
                }

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }

                it 'should not have changed wua' {
                    Assert-MockCalled -CommandName Invoke-WuaDownloadUpdates -Times 0
                    Assert-MockCalled -CommandName Invoke-WuaInstallUpdates -Times 0
                    Assert-MockCalled -CommandName Set-WuaAuNotificationLevel -Times 0
                }

                it 'Should not have triggered a reboot' {
                    $global:DSCMachineStatus | should be $null
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }
            Context 'Ensure UpToDate with no updates, disabled notification and reboot required' {
                BeforeAll {
                    $global:DSCMachineStatus = $null
                }
                AfterAll {
                    $global:DSCMachineStatus = $null
                }

                Mock  Get-WuaSearcher -MockWith {
                    return $Global:mockedSearchResultWithoutUpdate
                } -Verifiable

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaDisableNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoReboot
                } -Verifiable

                Mock Invoke-WuaDownloadUpdates -MockWith { }
                Mock Invoke-WuaInstallUpdates -MockWith { }
                Mock Set-WuaAuNotificationLevel -MockWith { }

                it 'should return $false' {
                    { Set-TargetResource -IsSingleInstance 'yes'  -UpdateNow $true -verbose -Category $testCategories  -Source WindowsUpdate } | should not throw
                }

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }

                it 'should not have changed wua' {
                    Assert-MockCalled -CommandName Invoke-WuaDownloadUpdates -Times 0
                    Assert-MockCalled -CommandName Invoke-WuaInstallUpdates -Times 0
                    Assert-MockCalled -CommandName Set-WuaAuNotificationLevel -Times 0
                }

                it 'Should have triggered a reboot' {
                    $global:DSCMachineStatus | should be 1
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }
            Context 'Ensure UpToDate with updates and disabled notification' {
                BeforeAll {
                    $global:DSCMachineStatus = $null
                }
                AfterAll {
                    $global:DSCMachineStatus = $null
                }

                Mock  Get-WuaSearcher -MockWith {
                    return $Global:mockedSearchResultWithUpdate
                } -Verifiable

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaDisableNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoNoReboot
                } -Verifiable

                Mock Invoke-WuaDownloadUpdates -MockWith { } -Verifiable
                Mock Invoke-WuaInstallUpdates -MockWith { } -Verifiable
                Mock Set-WuaAuNotificationLevel -MockWith { }

                it 'should return $false' {
                    { Set-TargetResource -IsSingleInstance 'yes'  -UpdateNow $true -verbose -Category $testCategories -Source WindowsUpdate } | should not throw
                }

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }


                it 'should not have changed wua notification' {
                    Assert-MockCalled -CommandName Set-WuaAuNotificationLevel -Times 0
                }

                it 'Should not have triggered a reboot' {
                    $global:DSCMachineStatus | should be $null
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }
            Context 'Ensure UpToDate with updates and disabled notification with reboot after install' {
                BeforeAll {
                    $global:DSCMachineStatus = $null
                }
                AfterAll {
                    $global:DSCMachineStatus = $null
                }

                Mock  Get-WuaSearcher -MockWith {
                    return $Global:mockedSearchResultWithUpdate
                } -Verifiable

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaDisableNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    Set-StrictMode -Off
                    if (!$callCount) {
                        $callCount = 1
                    } else {
                        $callCount++
                    }
                    if ($callCount -eq 1) {
                        Write-Verbose -Message 'return no reboot' -Verbose
                        return $Global:mockedWuaSystemInfoNoReboot
                    } else {
                        Write-Verbose -Message 'return reboot' -Verbose
                        return $Global:mockedWuaSystemInfoReboot
                    }
                } -Verifiable

                Mock Invoke-WuaDownloadUpdates -MockWith { } -Verifiable
                Mock Invoke-WuaInstallUpdates -MockWith { } -Verifiable
                Mock Set-WuaAuNotificationLevel -MockWith { }

                it 'should return $false' {
                    { Set-TargetResource -IsSingleInstance 'yes'  -UpdateNow $true -verbose -Category $testCategories -Source WindowsUpdate } | should not throw
                }

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }

                it 'should not have changed wua notification' {
                    Assert-MockCalled -CommandName Set-WuaAuNotificationLevel -Times 0
                }

                it 'Should not have triggered a reboot' {
                    $global:DSCMachineStatus | should be $null
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }
            Context 'Ensure Disable with updates and disable notification' {
                BeforeAll {
                    $global:DSCMachineStatus = $null
                }
                AfterAll {
                    $global:DSCMachineStatus = $null
                }

                Mock  Get-WuaSearcher -MockWith {
                    return $Global:mockedSearchResultWithUpdate
                }

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaDisableNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoNoReboot
                }

                Mock Invoke-WuaDownloadUpdates -MockWith { }
                Mock Invoke-WuaInstallUpdates -MockWith { }
                Mock Set-WuaAuNotificationLevel -MockWith { }


                it 'should not throw' {
                    { Set-TargetResource -IsSingleInstance 'yes' -notifications 'Disabled' -UpdateNow $false -Source WindowsUpdate } | should not throw
                }

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }

                it 'should not have called the Get-WuaSystemInfo mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName Get-WuaSystemInfo -Times 0
                }

                it 'should not have called the get-wuasearcher mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName Get-WuaSearcher -Times 0
                }

                it 'should not have changed wua' {
                    Assert-MockCalled -CommandName Invoke-WuaDownloadUpdates -Times 0
                    Assert-MockCalled -CommandName Invoke-WuaInstallUpdates -Times 0
                    Assert-MockCalled -CommandName Set-WuaAuNotificationLevel -Times 0
                }

                it 'Should not have triggered a reboot' {
                    $global:DSCMachineStatus | should be $null
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }

            Context 'Ensure Disable with updates and other notification' {
                BeforeAll {
                    $global:DSCMachineStatus = $null
                }
                AfterAll {
                    $global:DSCMachineStatus = $null
                }
                Mock  Get-WuaSearcher -MockWith {
                    return $Global:mockedSearchResultWithUpdate
                }

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaOtherNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoNoReboot
                }

                Mock Invoke-WuaDownloadUpdates -MockWith { }
                Mock Invoke-WuaInstallUpdates -MockWith { }
                Mock Set-WuaAuNotificationLevel -MockWith { }

                it 'should not throw' {
                    { Set-TargetResource -IsSingleInstance 'yes' -notifications 'Disabled'  -UpdateNow $false -Source WindowsUpdate } | should not throw
                }

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }

                it 'should not have called the Get-WuaSystemInfo mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName Get-WuaSystemInfo -Times 0
                }

                it 'should not have called the get-wuasearcher mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName Get-WuaSearcher -Times 0
                }

                it 'should have set the notification level' {
                    Assert-MockCalled -CommandName Set-WuaAuNotificationLevel -Times 1 -ParameterFilter { $NotificationLevel -eq 'Disabled' }
                }

                it 'should not have changed wua' {
                    Assert-MockCalled -CommandName Invoke-WuaDownloadUpdates -Times 0
                    Assert-MockCalled -CommandName Invoke-WuaInstallUpdates -Times 0
                }

                it 'Should not have triggered a reboot' {
                    $global:DSCMachineStatus | should be $null
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }

            Context 'Ensure UpToDate with updates and other notification' {
                BeforeAll {
                    $global:DSCMachineStatus = $null
                }
                AfterAll {
                    $global:DSCMachineStatus = $null
                }
                Mock  Get-WuaSearcher -MockWith {
                    return $Global:mockedSearchResultWithUpdate
                } -Verifiable

                Mock  Get-WuaAuNotificationLevel -MockWith {
                    return $Global:mockedWuaOtherNotificationLevel
                } -Verifiable

                Mock Get-WuaSystemInfo -MockWith {
                    return $Global:mockedWuaSystemInfoNoReboot
                } -Verifiable

                Mock Invoke-WuaDownloadUpdates -MockWith { } -Verifiable
                Mock Invoke-WuaInstallUpdates -MockWith { } -Verifiable
                Mock Set-WuaAuNotificationLevel -MockWith { }

                it 'should not throw' {
                    { Set-TargetResource -IsSingleInstance 'yes'  -UpdateNow $true -verbose -Category $testCategories -Source WindowsUpdate } | should not throw
                }

                it 'should not have called the new-object mock' {
                    # verify we mocked all WUA calls correctly
                    Assert-MockCalled -CommandName New-Object -Times 0
                }

                it 'should not have changed wua notification' {
                    Assert-MockCalled -CommandName Set-WuaAuNotificationLevel -Times 0
                }

                it 'Should not have triggered a reboot' {
                    $global:DSCMachineStatus | should be $null
                }

                it 'should have called the mock' {
                    Assert-VerifiableMock
                }
            }

        }
        #endregion

        Describe "$($Global:DSCResourceName)\Get-WuaWrapper" {
            it 'should return value based passed parameter' {
                Get-WuaWrapper -tryBlock {
                    param(
                        $a,
                        $b
                    )
                    return $a + $b
                } -argumentList @(1, 2) | should be 3
            }
            it 'should throw unexpected exception' {
                $exceptionMessage = 'foobar'
                { Get-WuaWrapper -tryBlock {
                        throw $exceptionMessage
                    } -argumentList @(1, 2) } | should throw $exceptionMessage
            }
            $exceptions = @(@{
                    hresult = -2145124322
                    Name    = 'rebooting'
                },
                @{
                    hresult = -2145107924
                    Name    = 'HostNotFound'
                },
                @{
                    hresult = -2145107940
                    Name    = 'RequestTimeout'
                },
                @{
                    hresult = -2145107921
                    Name    = 'CabProcessingSuceededWithError'
                }
            )
            foreach ($exception in $exceptions) {
                $name = $exception.Name
                $hresult = $exception.hresult
                it "should handle $name exception and return null" {
                    $exceptionMessage = 'foobar'
                    Get-WuaWrapper -tryBlock {
                        $exception = new-object -TypeName 'System.Runtime.InteropServices.COMException' -ArgumentList @('mocked com exception', $hresult)
                        throw $exception
                    } | should be $null
                }
                it "should handle $name exception and return specified value" {
                    $exceptionReturnValue = 'foobar'
                    $wrapperParams = @{
                        "ExceptionReturnValue" = $exceptionReturnValue
                    }
                    Get-WuaWrapper -tryBlock {
                        $exception = new-object -TypeName 'System.Runtime.InteropServices.COMException' -ArgumentList @('mocked com exception', $hresult)
                        throw $exception
                    } @wrapperParams | should be $exceptionReturnValue
                }
            }
        }

        Describe "$($Global:DSCResourceName)\Get-WuaSearcher" {

            $testCases = @(
                @{ Category = @('Security', 'Optional', 'Important') }
                @{ Category = @('Security', 'Optional') }
                @{ Category = @('Security', 'Important') }
                @{ Category = @('Optional', 'Important') }
                @{ Category = @('Optional') }
                @{ Category = @('Important') }
                @{ Category = @() }
            )
            Context 'Verify wua call works' {
                it "Should get a searcher - Category: <Category>" -skip -TestCases $testCases {
                    param([string[]]$category)
                    $searcher = (get-wuaSearcher -category $category -verbose)
                    $searcher | get-member
                    $searcher.GetType().FullName | should be "System.__ComObject"
                }
            }
            Context 'verify call flow' {
                mock get-wuaWrapper -MockWith { return "testResult" }
                it "should call get-wuasearchstring - Category: <Category>" -TestCases $testCases {
                    param([string[]]$category)
                    $global:ImportantExpected = ($category -contains 'Important')
                    $global:SecurityExpected = ($category -contains 'Security')
                    $global:OptionalExpected = ($category -contains 'Optional')
                    mock get-WuaSearchString -MockWith { return 'mockedSearchString' } -ParameterFilter { $security -eq $global:SecurityExpected -and $optional -eq $global:OptionalExpected -and $Important -eq $global:ImportantExpected }
                    foreach ($categoryItem in $category) {
                        Write-Verbose -Message $categoryItem -Verbose
                    }
                    get-wuaSearcher -category $category | should be "testResult"
                    #Assert-MockCalled -CommandName get-wuaSearchString -Times 1
                    Assert-MockCalled -CommandName get-wuaSearchString -Times 1
                    Assert-MockCalled -CommandName get-wuaWrapper -Times 1 -ParameterFilter { $ArgumentList -eq @('mockedSearchString') }
                }
            }

        }

        Describe "$($Global:DSCResourceName)\Get-WuaAuNotificationLevelInt" {

            $testCases = @(
                @{
                    notificationLevel    = 'Scheduled installation'
                    intNotificationLevel = 4
                }
                @{
                    notificationLevel    = 'Scheduledinstallation'
                    intNotificationLevel = 4
                }
                @{
                    notificationLevel    = 'Scheduled Installation'
                    intNotificationLevel = 4
                }
                @{
                    notificationLevel    = 'ScheduledInstallation'
                    intNotificationLevel = 4
                }
                @{
                    notificationLevel    = 'Disabled'
                    intNotificationLevel = 1
                }
                @{
                    notificationLevel    = 'disabled'
                    intNotificationLevel = 1
                }
            )

            it "Should return <intNotificationLevel> for <notificationLevel>" -TestCases $testCases {
                param($notificationLevel, $intNotificationLevel)
                Get-WuaAuNotificationLevelInt -notificationLevel $notificationLevel | should be $intNotificationLevel
            }
        }

        Describe "$($Global:DSCResourceName)\Get-WuaServiceManager" {
            it "Should return an object with an AddService2 Method" {
                Get-WuaServiceManager | Get-Member -Name AddService2 -MemberType Method | should not be null
            }
        }

        Describe "$($Global:DSCResourceName)\Add-WuaService" {

            Mock -CommandName Get-WuaServiceManager -MockWith {
                $wuaService = [PSCustomObject] @{ }
                $wuaService | Add-Member -MemberType ScriptMethod -value {
                    param([string]$string1, [String]$string2, [String]$string3)
                    "$string1|$string2|$string3" | out-file testdrive:\addservice2.txt -force
                } -name AddService2
                return $wuaService
            } -Verifiable
            $testServiceId = 'fakeServiceId'

            it "should not throw" {
                { Add-WuaService -ServiceId $testServiceId } | should not throw
            }

            it "should have called the mock" {
                Assert-VerifiableMock
            }

            it "should have created testdrive:\addservice2.txt" {
                'testdrive:\AddService2.txt' | should exist
            }
            it "It should have called AddService2" {
                Get-Content testdrive:\AddService2.txt | should be "$testServiceId|7|"
            }
        }

        Describe "$($Global:DSCResourceName)\Get-WuaSearchString" {

            $testCases = @(
                @{
                    security  = $false
                    optional  = $false
                    important = $false
                    result    = "CategoryIds contains '0FA1201D-4330-4FA8-8AE9-B877473B6441' and IsHidden=0 and IsInstalled=0"
                }
                @{
                    security  = $true
                    optional  = $false
                    important = $false
                    result    = "CategoryIds contains '0FA1201D-4330-4FA8-8AE9-B877473B6441' and IsHidden=0 and IsInstalled=0"
                }
                @{
                    security  = $true
                    optional  = $true
                    important = $false
                    result    = "(IsAssigned=0 and IsHidden=0 and IsInstalled=0) or (CategoryIds contains '0FA1201D-4330-4FA8-8AE9-B877473B6441' and IsHidden=0 and IsInstalled=0)"
                }
                @{
                    security  = $true
                    optional  = $true
                    important = $true
                    result    = "IsHidden=0 and IsInstalled=0"
                }
                @{
                    security  = $false
                    optional  = $true
                    important = $false
                    result    = "IsAssigned=0 and IsHidden=0 and IsInstalled=0"
                }
                @{
                    security  = $false
                    optional  = $true
                    important = $true
                    result    = "IsHidden=0 and IsInstalled=0"
                }
                @{
                    security  = $false
                    optional  = $false
                    important = $true
                    result    = "IsAssigned=1 and IsHidden=0 and IsInstalled=0"
                }
            )
            $testServiceId = 'fakeServiceId'
            it "Calling with -security:<security> -optional:<optional> -important:<important> should result in expected query" -TestCases $testCases {
                param($security, $optional, $important, $result)
                Get-WuaSearchString -security:$security -optional:$optional -important:$important | should be $result
            }
        }
        Describe "$($Global:DSCResourceName)\Get-WuaAuNotificationLevel" {

            $testCases = @(
                @{
                    NotificationLevel = 0
                    Result            = 'Not Configured'
                }
                @{
                    NotificationLevel = 1
                    Result            = 'Disabled'
                }
                @{
                    NotificationLevel = 2
                    Result            = 'Notify before download'
                }
                @{
                    NotificationLevel = 3
                    Result            = 'Notify before installation'
                }
                @{
                    NotificationLevel = 4
                    Result            = 'Scheduled installation'
                }
            )

            Mock -CommandName Get-WuaAuSettings -MockWith {
                $wuaService = [PSCustomObject] @{ }
                $wuaService | Add-Member -MemberType ScriptProperty -value {
                    return [int] (Get-Content testdrive:\NotificationLevel.txt)
                } -name NotificationLevel
                return $wuaService
            }

            it "Should return <result> when notification level is <NotificationLevel>" -TestCases $testCases {
                param([int]$NotificationLevel, $result)

                $NotificationLevel | Out-File testdrive:\NotificationLevel.txt -Force
                Get-WuaAuNotificationLevel | should be $result
            }
        }

        Describe "$($Global:DSCResourceName)\Test-TargetResourceProperties" {
            Mock -CommandName Write-Warning -MockWith { } -Verifiable
            Mock -CommandName Write-Verbose -MockWith { }

            It 'Calls write-warning when no categories are passed' {
                $PropertiesToTest = @{
                    IsSingleInstance = 'Yes'
                    Notifications    = 'Disabled'
                    Source           = 'WindowsUpdate'
                    Category         = @()
                    UpdateNow        = $True
                }
                Test-TargetResourceProperties @PropertiesToTest

                Assert-MockCalled -CommandName Write-Warning -Times 1 -Exactly -Scope It
            }

            It 'Calls write-warning when Important updates are requested but not Security updates' {
                $PropertiesToTest = @{
                    IsSingleInstance = 'Yes'
                    Notifications    = 'Disabled'
                    Source           = 'WindowsUpdate'
                    Category         = 'Important'
                }
                Test-TargetResourceProperties @PropertiesToTest

                Assert-MockCalled -CommandName Write-Warning -Times 1 -Exactly -Scope It
            }

            It 'Calls write-warning when Optional updates are requested but not Security updates' {
                $PropertiesToTest = @{
                    IsSingleInstance = 'Yes'
                    Notifications    = 'Disabled'
                    Source           = 'WindowsUpdate'
                    Category         = 'Optional'
                    UpdateNow        = $True
                }
                Test-TargetResourceProperties @PropertiesToTest

                Assert-MockCalled -CommandName Write-Verbose -Times 1 -Exactly -Scope It
            }

            It 'Throws an exception when passed WSUS as a source' {
                $PropertiesToTest = @{
                    IsSingleInstance = 'Yes'
                    Category         = 'Security'
                    Notifications    = 'Disabled'
                    Source           = 'WSUS'
                }
                { Test-TargetResourceProperties @PropertiesToTest } | Should Throw
            }
        }

        Describe "$($Global:DSCResourceName)\Get-WuaAuNotificationLevelInt" {
            It 'Gets int for notification level of Not Configured' {
                Get-WuaAuNotificationLevelInt -notificationLevel 'Not Configured' | Should be 0
            }
            It 'Gets int for notification level of Disabled' {
                Get-WuaAuNotificationLevelInt -notificationLevel 'Disabled' | Should be 1
            }
            It 'Gets int for notification level of Notify before download' {
                Get-WuaAuNotificationLevelInt -notificationLevel 'Notify before download' | Should be 2
            }
            It 'Gets int for notification level of Notify before installation' {
                Get-WuaAuNotificationLevelInt -notificationLevel 'Notify before installation' | Should be 3
            }
            It 'Gets int for notification level of Scheduled Installation' {
                Get-WuaAuNotificationLevelInt -notificationLevel 'Scheduled Installation' | Should be 4
            }
            It 'Gets int for notification level of ScheduledInstallation' {
                Get-WuaAuNotificationLevelInt -notificationLevel 'ScheduledInstallation' | Should be 4
            }
            It 'Gets int for notification level when nothing is provided' {
                { Get-WuaAuNotificationLevelInt } | Should Throw
            }
        }
    }

    #endregion

} finally {
    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion

    # TODO: Other Optional Cleanup Code Goes Here...
}