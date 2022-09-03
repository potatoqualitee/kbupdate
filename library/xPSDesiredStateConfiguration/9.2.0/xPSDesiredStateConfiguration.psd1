@{
    # Root module
    RootModule        = 'Modules\DscPullServerSetup\DscPullServerSetup.psm1'

    # Version number of this module.
    moduleVersion     = '9.2.0'

    # ID used to uniquely identify this module
    GUID              = 'cc8dc021-fa5f-4f96-8ecf-dfd68a6d9d48'

    # Author of this module
    Author            = 'DSC Community'

    # Company or vendor of this module
    CompanyName       = 'DSC Community'

    # Copyright statement for this module
    Copyright         = 'Copyright the DSC Community contributors. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'DSC resources for configuring common operating systems features, files and settings.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '4.0'

    # Minimum version of the common language runtime (CLR) required by this module
    CLRVersion        = '4.0'

    # Functions to export from this module
    FunctionsToExport = @(
        'Publish-DscModuleAndMof',
        'Publish-ModulesAndChecksum',
        'Publish-MofsInSource',
        'Publish-ModuleToPullServer',
        'Publish-MofToPullServer'
    )

    # Cmdlets to export from this module
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport   = @()

    # DSC resources to export from this module
    DscResourcesToExport  = @('xArchive','xDSCWebService','xEnvironment','xGroup','xMsiPackage','xPackage','xPSEndpoint','xRegistry','xRemoteFile','xScript','xService','xUser','xWindowsFeature','xWindowsOptionalFeature','xWindowsPackageCab','xWindowsProcess')

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{

        PSData = @{
            # Set to a prerelease string value if the release should be a prerelease.
            Prerelease   = 'preview0007'

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('DesiredStateConfiguration', 'DSC', 'DSCResourceKit', 'DSCResource')

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/dsccommunity/xPSDesiredStateConfiguration/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/dsccommunity/xPSDesiredStateConfiguration'

            # A URL to an icon representing this module.
            IconUri      = 'https://dsccommunity.org/images/DSC_Logo_300p.png'

            # ReleaseNotes of this module
            ReleaseNotes = '## [9.2.0-preview0007] - 2021-09-26

- xPackage
  - Fixed a bug not allowing using the file hash of an installer [Issue #702](https://github.com/dsccommunity/xPSDesiredStateConfiguration/issues/702).

### Fixed

- xRemoteFile
  - Fixed message inconsistencies in `DSC_xRemoteFile.strings.psd1` - Fixes [Issue #716](https://github.com/dsccommunity/xPSDesiredStateConfiguration/issues/716).
- xPSDesiredStateConfiguration
  - Fixed build failures caused by changes in `ModuleBuilder` module v1.7.0
    by changing `CopyDirectories` to `CopyPaths` - Fixes [Issue #687](https://github.com/dsccommunity/xPSDesiredStateConfiguration/issues/687).
  - Pin `Pester` module to 4.10.1 because Pester 5.0 is missing code
    coverage - Fixes [Issue #688](https://github.com/dsccommunity/xPSDesiredStateConfiguration/issues/688).
- xArchive
  - Removed `Invoke-NewPSDrive` function because it is no longer needed as
    Pester issue has been resolved - Fixes [Issue #698](https://github.com/dsccommunity/xPSDesiredStateConfiguration/issues/698).
- xGroup
  - Ensure group membership is always returned as an array - Fixes [Issue #353](https://github.com/dsccommunity/xPSDesiredStateConfiguration/issues/353).

### Changed

- xPSDesiredStateConfiguration
  - Updated to use the common module _DscResource.Common_ - Fixes [Issue #685](https://github.com/dsccommunity/xPSDesiredStateConfiguration/issues/685).
    - Improved integration test reliability by resetting the DSC LCM
      before executing each test using the `Reset-DscLcm`
      function - Fixes [Issue #686](https://github.com/dsccommunity/xPSDesiredStateConfiguration/issues/686).
  - Added build task `Generate_Conceptual_Help` to generate conceptual help
    for the DSC resource - Fixes [Issue #677](https://github.com/dsccommunity/xPSDesiredStateConfiguration/issues/677).
  - Added build task `Generate_Wiki_Content` to generate the wiki content
    that can be used to update the GitHub Wiki - Fixes [Issue #677](https://github.com/dsccommunity/xPSDesiredStateConfiguration/issues/677).
- xDSCWebService:
  - Moved strings into localization file - Fixes [Issue #622](https://github.com/dsccommunity/xPSDesiredStateConfiguration/issues/622).
  - Corrected case of `CertificateThumbPrint` to `CertificateThumbprint`.
- Renamed `master` branch to `main` - Fixes [Issue #696](https://github.com/dsccommunity/xPSDesiredStateConfiguration/issues/696).
- Updated `GitVersion.yml` to latest pattern - Fixes [Issue #707](https://github.com/dsccommunity/xPSDesiredStateConfiguration/issues/707).
- Updated build to use `Sampler.GitHubTasks` - Fixes [Issue #711](https://github.com/dsccommunity/xPSDesiredStateConfiguration/issues/711).
- Added support for publishing code coverage to `CodeCov.io` and
  Azure Pipelines - Fixes [Issue #711](https://github.com/dsccommunity/xPSDesiredStateConfiguration/issues/711).
- Updated vmImage used for build stage of CI to use `Windows-2019` to resolve
  issues with Wiki Generation of `xUploadFile` composite resource on Linux agents.
- Added `Publish_GitHub_Wiki_Content` task to `publish` stage of build
  pipeline - Fixes [Issue #729](https://github.com/dsccommunity/xPSDesiredStateConfiguration/issues/729).

'
        } # End of PSData hashtable
    } # End of PrivateData hashtable
}
