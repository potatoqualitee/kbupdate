@{
# Version number of this module.
moduleVersion = '2.8.0.0'

# ID used to uniquely identify this module
GUID = 'a9cba250-ea73-4d82-b31b-7e58cc50ffd1'

# Author of this module
Author = 'Microsoft Corporation'

# Company or vendor of this module
CompanyName = 'Microsoft Corporation'

# Copyright statement for this module
Copyright = '(c) 2014 Microsoft Corporation. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Module with DSC Resources for Windows Update'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '4.0'

# Minimum version of the common language runtime (CLR) required by this module
CLRVersion = '4.0'

# Functions to export from this module
FunctionsToExport = '*'

# Cmdlets to export from this module
CmdletsToExport = '*'

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('DesiredStateConfiguration', 'DSC', 'DSCResourceKit', 'DSCResource')

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/PowerShell/xWindowsUpdate/blob/master/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/PowerShell/xWindowsUpdate'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        ReleaseNotes = '* xWindowsUpdateAgent: Fixed verbose statement returning incorrect variable
* Tests no longer fail on `Assert-VerifiableMocks`, these are now renamed
  to `Assert-VerifiableMock` (breaking change in Pester v4).
* README.md has been updated with correct description of the resources
  ([issue 58](https://github.com/PowerShell/xWindowsUpdate/issues/58)).
* Updated appveyor.yml to use the correct parameters to call the test framework.
* Update appveyor.yml to use the default template.
* Added default template files .gitattributes, and .gitignore, and
  .vscode folder.

'

    } # End of PSData hashtable

} # End of PrivateData hashtable
}




