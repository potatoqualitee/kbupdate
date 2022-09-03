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
        A composite DSC resource to configure a set of similar xService resources.

    .PARAMETER Name
        An array of the names of the services to configure.

    .PARAMETER Ensure
        Specifies whether or not the set of services should exist.

        Set this property to Present to modify a set of services.
        Set this property to Absent to remove a set of services.

    .PARAMETER StartupType
        The startup type each service in the set should have.

    .PARAMETER BuiltInAccount
        The built-in account each service in the set should start under.

        Cannot be specified at the same time as Credential.

        The user account specified by this property must have access to the service
        executable paths in order to start the services.

    .PARAMETER State
        The state each service in the set should be in.
        From the default value defined in xService, the default will be Running.

    .PARAMETER Credential
        The credential of the user account each service in the set should start under.

        Cannot be specified at the same time as BuiltInAccount.

        The user specified by this credential will automatically be granted the Log on as a Service
        right. The user account specified by this property must have access to the service
        executable paths in order to start the services.
#>
configuration xServiceSet
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
        [ValidateSet('Automatic', 'Manual', 'Disabled')]
        [System.String]
        $StartupType,

        [Parameter()]
        [ValidateSet('LocalSystem', 'LocalService', 'NetworkService')]
        [System.String]
        $BuiltInAccount,

        [Parameter()]
        [ValidateSet('Running', 'Stopped', 'Ignore')]
        [System.String]
        $State,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential
    )

    $newResourceSetConfigurationParams = @{
        ResourceName = 'xService'
        ModuleName = 'xPSDesiredStateConfiguration'
        KeyParameterName = 'Name'
        Parameters = $PSBoundParameters
    }

    $configurationScriptBlock = New-ResourceSetConfigurationScriptBlock @newResourceSetConfigurationParams

    # This script block must be run directly in this configuration in order to resolve variables
    . $configurationScriptBlock
}
