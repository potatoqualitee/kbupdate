#################################
#
# PoshWSUS
# Version 2.3.1.6
#
# Boe Prox (c) 2011
# http://learn-powershell.net
#
#################################

@{

# Script module or binary module file associated with this manifest
ModuleToProcess = 'PoshWSUS.psm1'

# Version number of this module.
ModuleVersion = '2.3.1.6'

# ID used to uniquely identify this module
GUID = '4a327d07-b494-40ad-b154-a6116b1b1eb2'

# Author of this module
Author = 'Boe Prox'

# Company or vendor of this module
CompanyName = 'Unknown'

# Copyright statement for this module
Copyright = '(c) 2011 Boe Prox. All rights reserved.'

# Description of the functionality provided by this module
Description = 'PowerShell module to manage a WSUS Server. Support site: https://github.com/proxb/PoshWSUS/'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '2.0'

# Name of the Windows PowerShell host required by this module
PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
PowerShellHostVersion = ''

# Minimum version of the .NET Framework required by this module
DotNetFrameworkVersion = '2.0.50727'

# Minimum version of the common language runtime (CLR) required by this module
CLRVersion = ''

# Processor architecture (None, X86, Amd64, IA64) required by this module
ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @()

# Assemblies that must be loaded prior to importing this module

# Script files (.ps1) that are run in the caller's environment prior to importing this module
ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
TypesToProcess = @('TypeData\PoshWSUS.Types.ps1xml')

# Format files (.ps1xml) to be loaded when importing this module
FormatsToProcess = @('TypeData\PoshWSUS.Format.ps1xml')

# Modules to import as nested modules of the module specified in ModuleToProcess
NestedModules = @()

# Functions to export from this module
FunctionsToExport = '*'

# Cmdlets to export from this module
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module
AliasesToExport = '*'

# List of all modules packaged with this module
ModuleList = @()

# List of all files packaged with this module
FileList = @('TypeData\PoshWSUS.Types.ps1xml','TypeData\PoshWSUS.Format.ps1xml', 'PoshWSUS.psm1','PoshWSUS.psd1')

# Private data to pass to the module specified in ModuleToProcess
PrivateData = @{
    PSData = @{
        LicenseUri = 'https://github.com/proxb/PoshWSUS/blob/master/LICENSE'
        ProjectUri = 'https://github.com/proxb/PoshWSUS/'
    }
}
}

