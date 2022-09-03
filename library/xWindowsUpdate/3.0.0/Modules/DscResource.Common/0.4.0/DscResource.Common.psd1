@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'DscResource.Common.psm1'

    # Version number of this module.
    ModuleVersion     = '0.4.0'

    # ID used to uniquely identify this module
    GUID              = '9c9daa5b-5c00-472d-a588-c96e8e498450'

    # Author of this module
    Author            = 'DSC Community'

    # Company or vendor of this module
    CompanyName       = 'DSC Community'

    # Copyright statement for this module
    Copyright         = 'Copyright the DSC Community contributors. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'Common functions used in DSC Resources'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '4.0'

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @('Assert-Module','Get-LocalizedData','New-InvalidArgumentException','New-InvalidOperationException','New-InvalidResultException','New-NotImplementedException','New-ObjectNotFoundException','Test-DscParameterState','Test-IsNanoServer')

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport   = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{

        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('DSC', 'Localization')

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/dsccommunity/DscResource.Common/blob/master/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/dsccommunity/DscResource.Common'

            # A URL to an icon representing this module.
            IconUri      = 'https://dsccommunity.org/images/DSC_Logo_300p.png'

            # ReleaseNotes of this module
            ReleaseNotes = '## [0.4.0] - 2020-03-09

### Added

- Added the function `Assert-Module`.

### Changed

- Updated the localized strings to have the unique id according to style
  guideline.

## [0.3.0] - 2020-02-15

### Added

- Added more function documentation to the README.md.
- Fix minor style issue in functions.
- Changed the VS Code project settings to trim trailing whitespace for
  markdown files too.
- Changed the VS Code project setting `pipelineIndentationStyle` to use
  the correct style.
- The deploy step is no longer run on forks.
- Azure Pipelines will no longer trigger on changes to just the CHANGELOG.md.
- Add section "How to implement" in the README.md.
- Added `Test-IsNanoServer` function - fixes [Issue #9](https://github.com/dsccommunity/DscResource.Common/issues/9).

## [0.2.0] - 2020-01-09

### Changed

- Updating pipeline files to the latest in the template.
- Updating and added section Code of conduct.
- Updating and added section contribution.
- Update README.md.
- The cmdlet `Get-LocalizedData` can now detect localized filenames
  that are using both the basename and the basename plus the suffix `strings`. E.g.
  - `MSFT_Cluster.psd1`
  - `MSFT_Cluster.strings.psd1`

## [0.1.1] - 2019-11-27

### Added

- New module based on the functions available in DscResource.Template
- Change the minimum requirement to PowerShell 4.0.

### Changed

- skip tests (it ...) using New-CimInstance when OS is not Windows (see issue #1)
- updating secrets and account used

'

            Prerelease   = ''
        } # End of PSData hashtable

    } # End of PrivateData hashtable
}






