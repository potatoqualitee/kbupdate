@{
    # Version number of this module.
    moduleVersion      = '13.3.0'

    # ID used to uniquely identify this module
    GUID               = '693ee082-ed36-45a7-b490-88b07c86b42f'

    # Author of this module
    Author             = 'DSC Community'

    # Company or vendor of this module
    CompanyName        = 'DSC Community'

    # Copyright statement for this module
    Copyright          = 'Copyright the DSC Community contributors. All rights reserved.'

    # Description of the functionality provided by this module
    Description        = 'Module with DSC resources for deployment and configuration of Microsoft SQL Server.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion  = '5.0'

    # Minimum version of the common language runtime (CLR) required by this module
    CLRVersion         = '4.0'

    # Functions to export from this module
    FunctionsToExport  = @()

    # Cmdlets to export from this module
    CmdletsToExport    = @()

    # Variables to export from this module
    VariablesToExport  = @()

    # Aliases to export from this module
    AliasesToExport    = @()

    DscResourcesToExport = @(
        'SqlAG'
        'SqlAGDatabase'
        'SqlAgentAlert'
        'SqlAgentFailsafe'
        'SqlAgentOperator'
        'SqlAGListener'
        'SqlAGReplica'
        'SqlAlias'
        'SqlAlwaysOnService'
        'SqlDatabase'
        'SqlDatabaseDefaultLocation'
        'SqlDatabaseOwner'
        'SqlDatabasePermission'
        'SqlDatabaseRecoveryModel'
        'SqlDatabaseRole'
        'SqlDatabaseUser'
        'SqlRS'
        'SqlRSSetup'
        'SqlScript'
        'SqlScriptQuery'
        'SqlServerConfiguration'
        'SqlServerDatabaseMail'
        'SqlServerEndpoint'
        'SqlServerEndpointPermission'
        'SqlServerEndpointState'
        'SqlServerLogin'
        'SqlServerMaxDop'
        'SqlServerMemory'
        'SqlServerNetwork'
        'SqlServerPermission'
        'MSFT_SqlServerReplication'
        'SqlServerRole'
        'SqlServerSecureConnection'
        'SqlServiceAccount'
        'SqlSetup'
        'SqlWaitForAG'
        'SqlWindowsFirewall'
    )

    RequiredAssemblies = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData        = @{

        PSData = @{
            # Set to a prerelease string value if the release should be a prerelease.
            Prerelease   = ''

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('DesiredStateConfiguration', 'DSC', 'DSCResourceKit', 'DSCResource')

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/dsccommunity/SqlServerDsc/blob/master/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/dsccommunity/SqlServerDsc'

            # A URL to an icon representing this module.
            IconUri      = 'https://dsccommunity.org/images/DSC_Logo_300p.png'

            # ReleaseNotes of this module
            ReleaseNotes = '# Change log for SqlServerDsc

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

For older change log history see the [historic changelog](HISTORIC_CHANGELOG.md).

## [Unreleased]

### Added

- SqlServerDsc
  - Added continuous delivery with a new CI pipeline.
    - Update build.ps1 from latest template.

### Changed

- SqlServerDsc
  - Add .gitattributes file to checkout file correctly with CRLF.
  - Updated .vscode/analyzersettings.psd1 file to correct use PSSA rules
    and custom rules in VS Code.
  - Fix hashtables to align with style guideline ([issue #1437](https://github.com/PowerShell/SqlServerDsc/issues/1437)).
  - Updated most examples to remove the need for the variable `$ConfigurationData`,
    and fixed style issues.
  - Ignore commit in `GitVersion.yml` to force the correct initial release.
  - Set a display name on all the jobs and tasks in the CI pipeline.
  - Removing file ''Tests.depend.ps1'' as it is no longer required.
- SqlServerMaxDop
  - Fix line endings in code which did not use the correct format.
- SqlAlwaysOnService
  - The integration test has been temporarily disabled because when
    the cluster feature is installed it requires a reboot on the
    Windows Server 2019 build worker.
- SqlDatabaseRole
  - Update unit test to have the correct description on the `Describe`-block
    for the test of `Set-TargetResource`.
- SqlServerRole
  - Add support for nested role membership ([issue #1452](https://github.com/dsccommunity/SqlServerDsc/issues/1452))
  - Removed use of case-sensitive Contains() function when evalutating role membership.
    ([issue #1153](https://github.com/dsccommunity/SqlServerDsc/issues/1153))
  - Refactored mocks and unit tests to increase performance. ([issue #979](https://github.com/dsccommunity/SqlServerDsc/issues/979))

### Fixed

- SqlServerDsc
  - Fixed unit tests to call the function `Invoke-TestSetup` outside the
    try-block.
  - Update GitVersion.yml with the correct regular expression.
  - Fix import statement in all tests, making sure it throws if module
    DscResource.Test cannot be imported.
- SqlAlwaysOnService
  - When failing to enable AlwaysOn the resource should now fail with an
    error ([issue #1190](https://github.com/dsccommunity/SqlServerDsc/issues/1190)).
- SqlAgListener
  - Fix IPv6 addresses failing Test-TargetResource after listener creation.
'

        } # End of PSData hashtable

    } # End of PrivateData hashtable
}





