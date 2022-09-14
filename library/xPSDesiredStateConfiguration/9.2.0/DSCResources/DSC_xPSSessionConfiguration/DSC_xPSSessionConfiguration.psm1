$errorActionPreference = 'Stop'
Set-StrictMode -Version 'Latest'

$modulePath = Join-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -ChildPath 'Modules'

# Import the shared modules
Import-Module -Name (Join-Path -Path $modulePath `
    -ChildPath (Join-Path -Path 'xPSDesiredStateConfiguration.Common' `
        -ChildPath 'xPSDesiredStateConfiguration.Common.psm1'))

Import-Module -Name (Join-Path -Path $modulePath -ChildPath 'DscResource.Common')

# Import Localization Strings
$script:localizedData = Get-LocalizedData -DefaultUICulture 'en-US'

<#
    .SYNOPSIS
        Returns the current state of the specified PSSessionConfiguration

    .PARAMETER Name
        Specifies the name of the session configuration.
#>
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name
    )

    Write-Verbose -Message ($script:localizedData.GetTargetResourceStartMessage -f $Name)

    # Try getting the specified endpoint
    $endpoint = Get-PSSessionConfiguration -Name $Name -ErrorAction SilentlyContinue -Verbose:$false

    # If endpoint is null, it is absent
    if ($null -eq $endpoint)
    {
        $ensure = 'Absent'
    }
    # If endpoint is present, check other properties
    else
    {
        $ensure = 'Present'

        # If runAsUser is specified, return only the username in the credential property
        if ($endpoint.RunAsUser)
        {
            $newCimInstanceParams = @{
                ClassName  = 'MSFT_Credential'

                Property   = @{
                    Username = [System.String] $endpoint.RunAsUser
                    Password = [System.String] $null
                }

                Namespace  = 'root/microsoft/windows/desiredstateconfiguration'
                ClientOnly = $true
            }

            $convertToCimCredential = New-CimInstance @newCimInstanceParams
        }

        $accessMode = Get-EndpointAccessMode -Endpoint $endpoint
    }

    @{
        Name                   = $Name
        RunAsCredential        = [Microsoft.Management.Infrastructure.CimInstance] $convertToCimCredential
        SecurityDescriptorSDDL = $endpoint.Permission
        StartupScript          = $endpoint.StartupScript
        AccessMode             = $accessMode
        Ensure                 = $ensure
    }

    Write-Verbose -Message ($script:localizedData.GetTargetResourceEndMessage -f $Name)
}

<#
    .SYNOPSIS
        Ensures the specified PSSessionConfiguration is in its desired state

    .PARAMETER Name
        Specifies the name of the session configuration.

    .PARAMETER StartupScript
        Specifies the startup script for the configuration.
        Enter the fully qualified path of a Windows PowerShell script.

    .PARAMETER RunAsCredential
        Specifies the credential for commands of this session configuration. By default, commands
        run with the permissions of the current user.

    .PARAMETER SecurityDescriptorSDDL
        Specifies the Security Descriptor Definition Language (SDDL) string for the configuration.
        This string determines the permissions that are required to use the new session configuration.
        To use a session configuration in a session, users must have at least Execute(Invoke)
        permission for the configuration.

    .PARAMETER AccessMode
        Enables and disables the session configuration and determines whether it can be used for
        remote or local sessions on the computer. The default value is 'Remote'.

    .PARAMETER Ensure
        Indicates if the session configuration should exist. The default value is 'Present'.
#>
function Set-TargetResource
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [Parameter()]
        [AllowEmptyString()]
        [System.String]
        $StartupScript,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $RunAsCredential,

        [Parameter()]
        [System.String]
        $SecurityDescriptorSDDL,

        [Parameter()]
        [ValidateSet('Local', 'Remote', 'Disabled')]
        [System.String]
        $AccessMode = 'Remote',

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present'
    )

    Write-Verbose -Message ($script:localizedData.SetTargetResourceStartMessage -f $Name)

    # Check if the session configuration exists
    Write-Verbose -Message ($script:localizedData.CheckEndpointMessage -f $Name)

    # Try to get a named session configuration
    $endpoint = Get-PSSessionConfiguration -Name $Name -ErrorAction SilentlyContinue -Verbose:$false

    if ($PSCmdlet.ShouldProcess(($script:localizedData.EnsureSessionConfigurationMessage -f $Ensure)))
    {
        # If endpoint is present, set ensure correctly
        if ($endpoint)
        {
            Write-Verbose -Message ($script:localizedData.EndpointNameMessage -f $Name, 'present')

            # If the endpoint should be absent, delete the endpoint
            if ($Ensure -eq 'Absent')
            {
                try
                {
                    <#
                        Set the following preference so the functions inside Unregister-PSSessionConfig
                        doesn't get these settings
                    #>
                    $oldDebugPrefernce = $DebugPreference
                    $oldVerbosePreference = $VerbosePreference
                    $DebugPreference = $VerbosePreference = "SilentlyContinue"

                    $unregisterPSSessionConfigParams = @{
                        Name             = $Name
                        Force            = $true
                        NoServiceRestart = $true
                        ErrorAction      = 'Stop'
                    }

                    $null = Unregister-PSSessionConfiguration @unregisterPSSessionConfigParams

                    # Reset the following preference to older values
                    $DebugPreference = $oldDebugPrefernce
                    $VerbosePreference = $oldVerbosePreference

                    Write-Verbose -Message ($script:localizedData.EndpointNameMessage -f $Name, 'absent')

                    $restartNeeded = $true
                }
                catch
                {
                    $invokeThrowErrorHelperParams = @{
                        ErrorId       = 'UnregisterPSSessionConfigurationFailed'
                        ErrorMessage  = $_.Exception
                        ErrorCategory = 'InvalidOperation'
                    }

                    Invoke-ThrowErrorHelper @invokeThrowErrorHelperParams
                }

            }

            # else validate endpoint properties and return the result
            else
            {
                # Remove Name and Ensure from the bound Parameters for splatting
                if ($PSBoundParameters.ContainsKey('Name'))
                {
                    $null = $PSBoundParameters.Remove('Name')
                }

                if ($PSBoundParameters.ContainsKey('Ensure'))
                {
                    $null = $PSBoundParameters.Remove('Ensure')
                }

                [System.Collections.Hashtable] $validatedProperties = (
                    Get-ValidatedResourcePropertyTable -Endpoint $endpoint @PSBoundParameters -Apply
                )
                $null = $validatedProperties.Add('Name', $Name)

                # If the $validatedProperties contain more than 1 key, something needs to be changed
                if ($validatedProperties.count -gt 1)
                {
                    try
                    {
                        $setPSSessionConfigurationParams = $validatedProperties.psobject.Copy()
                        $setPSSessionConfigurationParams['Force'] = $true
                        $setPSSessionConfigurationParams['NoServiceRestart'] = $true
                        $setPSSessionConfigurationParams['Verbose'] = $false
                        $null = Set-PSSessionConfiguration @setPSSessionConfigurationParams
                        $restartNeeded = $true

                        # Write verbose message for all the properties, except Name, that are changing
                        Write-EndpointMessage -Parameters $validatedProperties -keysToSkip 'Name'
                    }
                    catch
                    {
                        $invokeThrowErrorHelperParams = @{
                            ErrorId       = 'SetPSSessionConfigurationFailed'
                            ErrorMessage  = $_.Exception
                            ErrorCategory = 'InvalidOperation'
                        }

                        Invoke-ThrowErrorHelper @invokeThrowErrorHelperParams
                    }
                }
            }
        }
        else
        {
            # Named session configuration is absent
            Write-Verbose -Message ($script:localizedData.EndpointNameMessage -f $Name, 'absent')

            # If the endpoint should have been present, create it
            if ($Ensure -eq 'Present')
            {
                # Remove Ensure,Verbose,Debug from the bound Parameters for splatting
                foreach ($key in @('Ensure', 'Verbose', 'Debug'))
                {
                    if ($PSBoundParameters.ContainsKey($key))
                    {
                        $null = $PSBoundParameters.Remove($key)
                    }
                }

                # Register the endpoint with specified properties
                try
                {
                    <#
                        Set the following preference so the functions inside
                        Unregister-PSSessionConfig doesn't get these settings
                    #>
                    $oldDebugPrefernce = $DebugPreference
                    $oldVerbosePreference = $VerbosePreference
                    $DebugPreference = $VerbosePreference = "SilentlyContinue"

                    $null = Register-PSSessionConfiguration @PSBoundParameters -Force -NoServiceRestart

                    # Reset the following preference to older values
                    $DebugPreference = $oldDebugPrefernce
                    $VerbosePreference = $oldVerbosePreference

                    # If access mode is specified, set it on the endpoint
                    if ($PSBoundParameters.ContainsKey('AccessMode') -and $AccessMode -ne 'Remote')
                    {
                        $setPSSessionConfigurationParams = @{
                            Name             = $Name
                            AccessMode       = $AccessMode
                            Force            = $true
                            NoServiceRestart = $true
                            Verbose          = $false
                        }

                        $null = Set-PSSessionConfiguration @setPSSessionConfigurationParams
                    }

                    $restartNeeded = $true

                    Write-Verbose -Message ($script:localizedData.EndpointNameMessage -f $Name, 'present')
                }
                catch
                {
                    $invokeThrowErrorHelperParams = @{
                        ErrorId       = 'RegisterOrSetPSSessionConfigurationFailed'
                        ErrorMessage  = $_.Exception
                        ErrorCategory = 'InvalidOperation'
                    }

                    Invoke-ThrowErrorHelper @invokeThrowErrorHelperParams
                }
            }
        }

        <#
            Any change to existing endpoint or creating new endpoint requires WinRM restart.
            Since DSC(CIM) uses WSMan as well it will stop responding.
            Hence telling the DSC Engine to restart the machine
        #>
        if ($restartNeeded)
        {
            Set-DscMachineRebootRequired
        }
    }

    Write-Verbose -Message ($script:localizedData.SetTargetResourceEndMessage -f $Name)
}

<#
    .SYNOPSIS
        Tests if the specified PSSessionConfiguration is in its desired state

    .PARAMETER Name
        Specifies the name of the session configuration.

    .PARAMETER StartupScript
        Specifies the startup script for the configuration.
        Enter the fully qualified path of a Windows PowerShell script.

    .PARAMETER RunAsCredential
        Specifies the credential for commands of this session configuration. By default, commands
        run with the permissions of the current user.

    .PARAMETER SecurityDescriptorSDDL
        Specifies the Security Descriptor Definition Language (SDDL) string for the configuration.
        This string determines the permissions that are required to use the new session configuration.
        To use a session configuration in a session, users must have at least Execute(Invoke)
        permission for the configuration.

    .PARAMETER AccessMode
        Enables and disables the session configuration and determines whether it can be used for
        remote or local sessions on the computer. The default value is 'Remote'.

    .PARAMETER Ensure
        Indicates if the session configuration should exist. The default value is 'Present'.
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [Parameter()]
        [AllowEmptyString()]
        [System.String]
        $StartupScript,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $RunAsCredential,

        [Parameter()]
        [System.String]
        $SecurityDescriptorSDDL,

        [Parameter()]
        [ValidateSet('Local', 'Remote', 'Disabled')]
        [System.String]
        $AccessMode = 'Remote',

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present'
    )

    Write-Verbose -Message ($script:localizedData.TestTargetResourceStartMessage -f $Name)

    #region Input Validation
    # Check if the endpoint name is blank/whitespaced string
    if ([System.String]::IsNullOrWhiteSpace($Name))
    {
        $invokeThrowErrorHelperParams = @{
            ErrorId       = 'BlankString'
            ErrorMessage  = $script:localizedData.WhitespacedStringMessage -f 'name'
            ErrorCategory = 'SyntaxError'
        }

        Invoke-ThrowErrorHelper @invokeThrowErrorHelperParams
    }

    # Check for Startup script path and extension
    if ($PSBoundParameters.ContainsKey('StartupScript'))
    {
        # Check if startup script path is valid
        if (!(Test-Path -Path $StartupScript))
        {
            $invokeThrowErrorHelperParams = @{
                ErrorId       = 'PathNotFound'
                ErrorMessage  = $script:localizedData.StartupPathNotFoundMessage -f $StartupScript
                ErrorCategory = 'ObjectNotFound'
            }

            Invoke-ThrowErrorHelper @invokeThrowErrorHelperParams
        }

        # Check the startup script extension
        $startupScriptFileExtension = $StartupScript.Split('.')[-1]

        if ($startupScriptFileExtension -ne 'ps1')
        {
            $invokeThrowErrorHelperParams = @{
                ErrorId       = 'WrongFileExtension'
                ErrorMessage  =
                $script:localizedData.WrongStartupScriptExtensionMessage -f $startupScriptFileExtension
                ErrorCategory = 'InvalidData'
            }

            Invoke-ThrowErrorHelper @invokeThrowErrorHelperParams
        }
    }

    # Check if SecurityDescriptorSDDL is whitespaced
    if ($PSBoundParameters.ContainsKey('SecurityDescriptorSDDL') -and
        [System.String]::IsNullOrWhiteSpace($SecurityDescriptorSDDL))
    {
        $invokeThrowErrorHelperParams = @{
            ErrorId       = 'BlankString'
            ErrorMessage  = $script:localizedData.WhitespacedStringMessage -f 'securityDescriptorSddl'
            ErrorCategory = 'SyntaxError'
        }

        Invoke-ThrowErrorHelper @invokeThrowErrorHelperParams
    }

    # Check if the RunAsCredential is not empty
    if ($PSBoundParameters.ContainsKey('RunAsCredential') -and
        ($RunAsCredential -eq [System.Management.Automation.PSCredential]::Empty))
    {
        $invokeThrowErrorHelperParams = @{
            ErrorId       = 'EmptyCredential'
            ErrorMessage  = $script:localizedData.EmptyCredentialMessage
            ErrorCategory = 'InvalidArgument'
        }

        Invoke-ThrowErrorHelper @invokeThrowErrorHelperParams
    }
    #endregion

    # Check if the session configuration exists
    Write-Verbose -Message ($script:localizedData.CheckEndpointMessage -f $Name)

    try
    {
        # Try to get a named session configuration
        $endpoint = Get-PSSessionConfiguration -Name $Name -ErrorAction Stop -Verbose:$false

        Write-Verbose -Message ($script:localizedData.EndpointNameMessage -f $Name, 'present')

        # If the endpoint shouldn't be present, return false
        if ($Ensure -eq 'Absent')
        {
            return $false
        }
        # else validate endpoint properties and return the result
        else
        {
            # Remove Name and Ensure from the bound Parameters for splatting
            if ($PSBoundParameters.ContainsKey('Name'))
            {
                $null = $PSBoundParameters.Remove('Name')
            }

            if ($PSBoundParameters.ContainsKey('Ensure'))
            {
                $null = $PSBoundParameters.Remove('Ensure')
            }

            return (Get-ValidatedResourcePropertyTable -Endpoint $endpoint @PSBoundParameters)
        }
    }
    catch [Microsoft.PowerShell.Commands.WriteErrorException]
    {
        Write-Verbose -Message ($script:localizedData.EndpointNameMessage -f $Name, 'absent')

        return ($Ensure -eq 'Absent')
    }

    Write-Verbose -Message ($script:localizedData.TestTargetResourceEndMessage -f $Name)
}

<#
    .SYNOPSIS
        Helper function to translate the endpoint's accessmode
        to the 'Disabled', 'Local', 'Remote' values

    .PARAMETER Endpoint
        Specifies a valid session configuration endpoint object
#>
function Get-EndpointAccessMode
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        $Endpoint
    )

    if (-not $endpoint.Enabled)
    {
        return 'Disabled'
    }
    elseif ($endpoint.Permission -and
        ($endpoint.Permission).contains('NT AUTHORITY\NETWORK AccessDenied'))
    {
        return 'Local'
    }
    else
    {
        return 'Remote'
    }
}

<#
    .SYNOPSIS
        Helper function to write verbose messages for collection of properties

    .PARAMETER Parameters
        Specifies a properties Hashtable.

    .PARAMETER KeysToSkip
        Specifies an array of Hashtable keys to ignore.
#>
function Write-EndpointMessage
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $Parameters,

        [Parameter(Mandatory = $true)]
        [System.String[]]
        $KeysToSkip
    )

    foreach ($key in $Parameters.keys)
    {
        if ($KeysToSkip -notcontains $key)
        {
            Write-Verbose -Message ($script:localizedData.SetPropertyMessage -f $key, $Parameters[$key])
        }
    }
}

<#
    .SYNOPSIS
        Helper function to get a Hashtable of validated endpoint properties

    .PARAMETER Endpoint
        Specifies a valid session configuration endpoint.

    .PARAMETER StartupScript
        Specifies the startup script for the configuration.
        Enter the fully qualified path of a Windows PowerShell script.

    .PARAMETER RunAsCredential
        Specifies the credential for commands of this session configuration.

    .PARAMETER SecurityDescriptorSDDL
        Specifies the Security Descriptor Definition Language (SDDL) string for the configuration.

    .PARAMETER AccessMode
        Enables and disables the session configuration and determines whether it can be used for
        remote or local sessions on the computer.

        The acceptable values for this parameter are:
        - Disabled
        - Local
        - Remote

    .PARAMETER Apply
        Indicates that this function should return a hashtable of validated endpoint properties.
        By default, this function returns the value $false.
#>
function Get-ValidatedResourcePropertyTable
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        $Endpoint,

        [Parameter()]
        [System.String]
        $StartupScript,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $RunAsCredential,

        [Parameter()]
        [System.String]
        $SecurityDescriptorSDDL,

        [Parameter()]
        [ValidateSet('Local', 'Remote', 'Disabled')]
        [System.String]
        $AccessMode,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $Apply
    )

    if ($Apply)
    {
        $validatedProperties = @{}
    }

    # Check if the SDDL is same as specified
    if ($PSBoundParameters.ContainsKey('SecurityDescriptorSDDL'))
    {
        Write-Verbose -Message ($script:localizedData.CheckPropertyMessage -f 'SDDL',
            $SecurityDescriptorSDDL)

        # If endpoint SDDL is not same as specified
        if ($endpoint.SecurityDescriptorSddl -and
            ($endpoint.SecurityDescriptorSddl -ne $SecurityDescriptorSDDL))
        {
            $notDesiredSDDLMessage = $script:localizedData.NotDesiredPropertyMessage -f 'SDDL',
            $SecurityDescriptorSDDL, $endpoint.SecurityDescriptorSddl
            Write-Verbose -Message $notDesiredSDDLMessage

            if ($Apply)
            {
                $validatedProperties['SecurityDescriptorSddl'] = $SecurityDescriptorSDDL
            }
            else
            {
                return $false
            }
        }
        # If endpoint SDDL is same as specified
        else
        {
            Write-Verbose -Message ($script:localizedData.DesiredPropertyMessage -f 'SDDL',
                $SecurityDescriptorSDDL)
        }
    }

    # Check the RunAs user is same as specified
    if ($PSBoundParameters.ContainsKey('RunAsCredential'))
    {
        Write-Verbose -Message ($script:localizedData.CheckPropertyMessage -f 'RunAs user',
            $RunAsCredential.UserName)

        # If endpoint RunAsUser is not same as specified
        if ($endpoint.RunAsUser -ne $RunAsCredential.UserName)
        {
            Write-Verbose -Message ($script:localizedData.NotDesiredPropertyMessage -f 'RunAs user',
                $RunAsCredential.UserName, $endpoint.RunAsUser)

            if ($Apply)
            {
                $validatedProperties['RunAsCredential'] = $RunAsCredential
            }
            else
            {
                return $false
            }
        }
        # If endpoint RunAsUser is same as specified
        else
        {
            Write-Verbose -Message ($script:localizedData.DesiredPropertyMessage -f 'RunAs user',
                $RunAsCredential.UserName)
        }
    }

    # Check if the StartupScript is same as specified
    if ($PSBoundParameters.ContainsKey('StartupScript'))
    {
        Write-Verbose -Message ($script:localizedData.CheckPropertyMessage -f 'startup script',
            $StartupScript)

        # If endpoint StartupScript is not same as specified
        if ($endpoint.StartupScript -ne $StartupScript)
        {
            Write-Verbose -Message ($script:localizedData.NotDesiredPropertyMessage -f 'startup script',
                $StartupScript, $endpoint.StartupScript)

            if ($Apply)
            {
                $validatedProperties['StartupScript'] = $StartupScript
            }
            else
            {
                return $false
            }
        }
        # If endpoint StartupScript is same as specified
        else
        {
            Write-Verbose -Message ($script:localizedData.DesiredPropertyMessage -f 'startup script',
                $StartupScript)
        }
    }

    # Check if AccessMode is same as specified
    if ($PSBoundParameters.ContainsKey('AccessMode'))
    {
        Write-Verbose -Message ($script:localizedData.CheckPropertyMessage -f 'acess mode', $AccessMode)

        $curAccessMode = Get-EndpointAccessMode -Endpoint $Endpoint

        # If endpoint access mode is not same as specified
        if ($curAccessMode -ne $AccessMode)
        {
            Write-Verbose -Message ($script:localizedData.NotDesiredPropertyMessage -f 'access mode',
                $AccessMode, $curAccessMode)

            if ($Apply)
            {
                $validatedProperties['AccessMode'] = $AccessMode
            }
            else
            {
                return $false
            }
        }
        # If endpoint access mode is same as specified
        else
        {
            Write-Verbose -Message ($script:localizedData.DesiredPropertyMessage -f 'access mode',
                $AccessMode)
        }
    }

    if ($Apply)
    {
        return $validatedProperties
    }
    else
    {
        return ($Ensure -eq 'Present')
    }
}

<#
    .SYNOPSIS
        Invoke this helper function to throw a terminating error.

    .PARAMETER ErrorId
        Specifies a developer-defined identifier of the error.
        This identifier must be a non-localized string for a specific error type.

    .PARAMETER ExceptionMessage
        Specifies the message that describes the error.

    .PARAMETER ErrorCategory
        Specifies the category of the error.
#>
function Invoke-ThrowErrorHelper
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ErrorId,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ErrorMessage,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorCategory]
        $ErrorCategory
    )

    $exception = New-Object System.InvalidOperationException $ErrorMessage
    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $ErrorId,
    $ErrorCategory, $null

    throw $errorRecord
}

Export-ModuleMember -Function Get-TargetResource, Set-TargetResource, Test-TargetResource
