@{
    # Version number of this module.
    moduleVersion     = '3.0.0'

    # ID used to uniquely identify this module
    GUID              = 'a9cba250-ea73-4d82-b31b-7e58cc50ffd1'

    # Author of this module
    Author            = 'DSC Community'

    # Company or vendor of this module
    CompanyName       = 'DSC Community'

    # Copyright statement for this module
    Copyright         = 'Copyright the DSC Community contributors. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'This module contains DSC resources for configuration of Microsoft Windows Update and installing Windows updates.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '4.0'

    # Minimum version of the common language runtime (CLR) required by this module
    CLRVersion        = '4.0'

    # Functions to export from this module
    FunctionsToExport = @()

    # Cmdlets to export from this module
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport   = @()

    DscResourcesToExport = @(
        'xHotFix'
        'xWindowsUpdateAgent'
    )

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{
        PSData = @{
            # Set to a prerelease string value if the release should be a prerelease.
            Prerelease   = 'preview0001'

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('DesiredStateConfiguration', 'DSC', 'DSCResourceKit', 'DSCResource')

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/dsccommunity/xWindowsUpdate/blob/master/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/dsccommunity/xWindowsUpdate'

            # A URL to an icon representing this module.
            IconUri = 'https://dsccommunity.org/images/DSC_Logo_300p.png'

            # ReleaseNotes of this module
            ReleaseNotes = '## [3.0.0-preview0001] - 2020-03-21

### Added

- xWindowsUpdate
  - Added automatic release with a new CI pipeline.
- xWindowsUpdateAgent
  - Added Retry logic to known transient errors ([issue #24](https://github.com/dsccommunity/xWindowsUpdate/issues/24)).

### Changed

- xWindowsUpdate
  - Moved the `Set-StrictMode` so that it is used during testing only and
    not during runtime.
  - Removed the helper function `Trace-Message` and using the `Write-Verbose`
    directly instead.
  - The helper function `New-InvalidArgumentException` was replaced by
    its equivalent in the module DscResource.Common.
- xWindowsUpdateAgent
  - Removed the `$PSCmdlet.ShouldProcess` calls from code since DSC does not
    support interactive actions.
  - No longer defaults to output verbose messages.

### Removed

- xWindowsUpdate
  - BREAKING CHANGE: Removed the deprecated resource `xMicrosoftUpdate`

## [2.8.0.0] - 2019-04-03

- xWindowsUpdateAgent: Fixed verbose statement returning incorrect variable
- Tests no longer fail on `Assert-VerifiableMocks`, these are now renamed
  to `Assert-VerifiableMock` (breaking change in Pester v4).
- README.md has been updated with correct description of the resources
  ([issue #58](https://github.com/dsccommunity/xWindowsUpdate/issues/58)).
- Updated appveyor.yml to use the correct parameters to call the test framework.
- Update appveyor.yml to use the default template.
- Added default template files .gitattributes, and .gitignore, and
  .vscode folder.

## [2.7.0.0] - 2017-07-12

- xWindowsUpdateAgent: Fix Get-TargetResource returning incorrect key

## [2.6.0.0] - 2017-03-08

- Converted appveyor.yml to install Pester from PSGallery instead of from
  Chocolatey.
- Fixed PSScriptAnalyzer issues.
- Fixed common test breaks (markdown style, and example style).
- Added CodeCov.io reporting
- Deprecated xMicrosoftUpdate as it''s functionality is replaced by
  xWindowsUpdateAgent

## [2.5.0.0] - 2016-05-18

- Added xWindowsUpdateAgent

## [2.4.0.0] - 2016-03-30

- Fixed PSScriptAnalyzer error in examples

## [2.3.0.0] - 2016-02-02

- MSFT_xWindowsUpdate: Fixed an issue in the Get-TargetResource function,
  resulting in the Get-DscConfiguration cmdlet now working appropriately
  when the resource is applied.
- MSFT_xWindowsUpdate: Fixed an issue in the Set-TargetResource function
  that was causing the function to fail when the installation of a hotfix
  did not provide an exit code.

## [2.2.0.0] - 2015-09-11

- Minor fixes

## [2.1.0.0] - 2015-07-24

- Added xMicrosoftUpdate DSC resource which can be used to enable/disable
  Microsoft Update in the Windows Update Settings.

#

## [2.0.0.0] - 2015-04-23

- Initial release with the xHotfix resource

'
        } # End of PSData hashtable
    } # End of PrivateData hashtable
}





