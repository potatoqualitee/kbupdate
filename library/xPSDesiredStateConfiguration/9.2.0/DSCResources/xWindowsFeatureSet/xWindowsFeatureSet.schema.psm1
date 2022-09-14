$errorActionPreference = 'Stop'
Set-StrictMode -Version 'Latest'

$modulePath = Join-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -ChildPath 'Modules'

# Import the shared modules
Import-Module -Name (Join-Path -Path $modulePath `
    -ChildPath (Join-Path -Path 'xPSDesiredStateConfiguration.Common' `
        -ChildPath 'xPSDesiredStateConfiguration.Common.psm1'))

Import-Module -Name (Join-Path -Path $modulePath -ChildPath 'DscResource.Common')
<#
    .SYNOPSIS
        A composite DSC resource to configure a set of similar xWindowsFeature resources.

    .PARAMETER Name
        The name of the roles or features to install or uninstall.

    .PARAMETER Ensure
        Specifies whether the roles or features should be installed or uninstalled.

        To install the features, set this property to Present.
        To uninstall the features, set this property to Absent.

    .PARAMETER IncludeAllSubFeature
        Specifies whether or not all subfeatures should be installed or uninstalled alongside the specified roles or features.

        If this property is true and Ensure is set to Present, all subfeatures will be installed.
        If this property is false and Ensure is set to Present, subfeatures will not be installed or uninstalled.
        If Ensure is set to Absent, all subfeatures will be uninstalled.

    .PARAMETER Credential
        The credential of the user account under which to install or uninstall the roles or features.

    .PARAMETER LogPath
        The custom file path to which to log this operation.
        If not passed in, the default log path will be used (%WINDIR%\logs\ServerManager.log).
#>
configuration xWindowsFeatureSet
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Name,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Source,

        [Parameter()]
        [System.Boolean]
        $IncludeAllSubFeature,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $LogPath
    )

    $newResourceSetConfigurationParams = @{
        ResourceName = 'xWindowsFeature'
        ModuleName = 'xPSDesiredStateConfiguration'
        KeyParameterName = 'Name'
        Parameters = $PSBoundParameters
    }

    $configurationScriptBlock = New-ResourceSetConfigurationScriptBlock @newResourceSetConfigurationParams

    # This script block must be run directly in this configuration in order to resolve variables
    . $configurationScriptBlock
}
