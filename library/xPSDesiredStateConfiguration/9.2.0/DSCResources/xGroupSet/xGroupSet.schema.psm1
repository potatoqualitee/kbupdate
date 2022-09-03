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
        A composite DSC resource to configure a set of similar xGroup resources.

    .PARAMETER GroupName
        An array of the names of the groups to configure.

    .PARAMETER Ensure
        Specifies whether or not the set of groups should exist.

        Set this property to Present to create or modify a set of groups.
        Set this property to Absent to remove a set of groups.

    .PARAMETER MembersToInclude
        The members that should be included in each group in the set.

    .PARAMETER MembersToExclude
        The members that should be excluded from each group in the set.

    .PARAMETER Credential
        The credential to resolve all groups and user accounts.
#>
configuration xGroupSet
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $GroupName,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure,

        [Parameter()]
        [System.String[]]
        $MembersToInclude,

        [Parameter()]
        [System.String[]]
        $MembersToExclude,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential
    )

    $newResourceSetConfigurationParams = @{
        ResourceName = 'xGroup'
        ModuleName = 'xPSDesiredStateConfiguration'
        KeyParameterName = 'GroupName'
        Parameters = $PSBoundParameters
    }

    $configurationScriptBlock = New-ResourceSetConfigurationScriptBlock @newResourceSetConfigurationParams

    # This script block must be run directly in this configuration in order to resolve variables
    . $configurationScriptBlock
}
