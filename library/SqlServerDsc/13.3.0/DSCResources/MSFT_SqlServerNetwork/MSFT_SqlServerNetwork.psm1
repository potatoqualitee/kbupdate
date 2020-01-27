$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SqlServerDsc.Common'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SqlServerDsc.Common.psm1')

# Load localized string data
$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_SqlServerNetwork'

<#
    .SYNOPSIS
    Returns the current state of the SQL Server network properties.

    .PARAMETER InstanceName
    The name of the SQL instance to be configured.

    .PARAMETER ProtocolName
    The name of network protocol to be configured. Only tcp is currently supported.
#>
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        # For now there is only support for the tcp protocol.
        [Parameter(Mandatory = $true)]
        [ValidateSet('Tcp')]
        [System.String]
        $ProtocolName
    )

    Import-SQLPSModule

    $managedComputerObject = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer

    Write-Verbose -Message ($script:localizedData.GetNetworkProtocol -f $ProtocolName, $InstanceName)
    $tcp = $managedComputerObject.ServerInstances[$InstanceName].ServerProtocols[$ProtocolName]

    Write-Verbose -Message $script:localizedData.ReadingNetworkProperties
    $returnValue = @{
        InstanceName   = $InstanceName
        ProtocolName   = $ProtocolName
        IsEnabled      = $tcp.IsEnabled
        TcpDynamicPort = ($tcp.IPAddresses['IPAll'].IPAddressProperties['TcpDynamicPorts'].Value -ge 0)
        TcpPort        = $tcp.IPAddresses['IPAll'].IPAddressProperties['TcpPort'].Value
    }

    $returnValue.Keys | ForEach-Object {
        Write-Verbose -Message "$_ = $($returnValue[$_])"
    }

    return $returnValue
}

<#
    .SYNOPSIS
    Sets the SQL Server network properties.

    .PARAMETER ServerName
    The host name of the SQL Server to be configured. Default value is $env:COMPUTERNAME.

    .PARAMETER InstanceName
    The name of the SQL instance to be configured.

    .PARAMETER ProtocolName
    The name of network protocol to be configured. Only tcp is currently supported.

    .PARAMETER IsEnabled
    Enables or disables the network protocol.

    .PARAMETER TcpDynamicPort
    Specifies whether the SQL Server instance should use a dynamic port.
    Value cannot be set to $true if TcpPort is set to a non-empty string.

    .PARAMETER TcpPort
    The TCP port(s) that SQL Server should be listening on.
    If the IP address should listen on more than one port, list all ports
    separated with a comma ('1433,1500,1501'). To use this parameter set
    TcpDynamicPort to 'False'.

    .PARAMETER RestartService
    If set to $true then SQL Server and dependent services will be restarted
    if a change to the configuration is made. The default value is $false.

    .PARAMETER RestartTimeout
    Timeout value for restarting the SQL Server services. The default value
    is 120 seconds.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName = $env:COMPUTERNAME,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Tcp')]
        [System.String]
        $ProtocolName,

        [Parameter()]
        [System.Boolean]
        $IsEnabled,

        [Parameter()]
        [System.Boolean]
        $TcpDynamicPort,

        [Parameter()]
        [System.String]
        $TcpPort,

        [Parameter()]
        [System.Boolean]
        $RestartService = $false,

        [Parameter()]
        [System.UInt16]
        $RestartTimeout = 120
    )

    if ($TcpDynamicPort -and $TcpPort)
    {
        $errorMessage = $script:localizedData.ErrorDynamicAndStaticPortSpecified
        New-InvalidOperationException -Message $errorMessage
    }

    $getTargetResourceResult = Get-TargetResource -InstanceName $InstanceName -ProtocolName $ProtocolName

    $desiredState = @{
        InstanceName   = $InstanceName
        ProtocolName   = $ProtocolName
        IsEnabled      = $IsEnabled
        TcpDynamicPort = $TcpDynamicPort
        TcpPort        = $TcpPort
    }

    $isRestartNeeded = $false

    # Get-TargetResource makes the necessary calls so the type ManagedComputer is available.
    $managedComputerObject = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer

    Write-Verbose -Message ($script:localizedData.GetNetworkProtocol -f $ProtocolName, $InstanceName)
    $tcp = $managedComputerObject.ServerInstances[$InstanceName].ServerProtocols[$ProtocolName]

    Write-Verbose -Message ($script:localizedData.CheckingProperty -f 'IsEnabled')
    if ($desiredState.IsEnabled -ine $getTargetResourceResult.IsEnabled)
    {
        Write-Verbose -Message ($script:localizedData.UpdatingProperty -f 'IsEnabled', $getTargetResourceResult.IsEnabled, $desiredState.IsEnabled)
        $tcp.IsEnabled = $desiredState.IsEnabled
        $tcp.Alter()

        $isRestartNeeded = $true
    }

    Write-Verbose -Message ($script:localizedData.CheckingProperty -f 'TcpDynamicPort')
    if ($desiredState.TcpDynamicPort -ne $getTargetResourceResult.TcpDynamicPort)
    {
        # Translates the current and desired state to a string for display
        $dynamicPortDisplayValueTable = @{
            $true  = 'enabled'
            $false = 'disabled'
        }

        # Translates the desired state to a valid value
        $desiredDynamicPortValue = @{
            $true  = '0'
            $false = ''
        }

        $fromTcpDynamicPortDisplayValue = $dynamicPortDisplayValueTable[$getTargetResourceResult.TcpDynamicPort]
        $toTcpDynamicPortDisplayValue = $dynamicPortDisplayValueTable[$desiredState.TcpDynamicPort]

        Write-Verbose -Message ($script:localizedData.UpdatingProperty -f 'TcpDynamicPorts', $fromTcpDynamicPortDisplayValue, $toTcpDynamicPortDisplayValue)
        $tcp.IPAddresses['IPAll'].IPAddressProperties['TcpDynamicPorts'].Value = $desiredDynamicPortValue[$desiredState.TcpDynamicPort]
        $tcp.Alter()

        $isRestartNeeded = $true
    }

    Write-Verbose -Message ($script:localizedData.CheckingProperty -f 'TcpPort')
    if ($desiredState.TcpPort -ine $getTargetResourceResult.TcpPort)
    {
        $fromTcpPort = $getTargetResourceResult.TcpPort
        if ($fromTcpPort -eq '')
        {
            $fromTcpPort = 'none'
        }

        $toTcpPort = $desiredState.TcpPort
        if ($toTcpPort -eq '')
        {
            $toTcpPort = 'none'
        }

        Write-Verbose -Message ($script:localizedData.UpdatingProperty -f 'TcpPort', $fromTcpPort, $toTcpPort)
        $tcp.IPAddresses['IPAll'].IPAddressProperties['TcpPort'].Value = $desiredState.TcpPort
        $tcp.Alter()

        $isRestartNeeded = $true
    }

    if ($RestartService -and $isRestartNeeded)
    {
        $restartSqlServiceParameters = @{
            ServerName   = $ServerName
            InstanceName = $InstanceName
            Timeout      = $RestartTimeout
        }

        if ($getTargetResourceResult.IsEnabled -eq $false -and $IsEnabled -eq $true)
        {
            <#
                If the protocol was disabled and now being enabled, is not possible
                to connect to the instance to evaluate if it is a clustered instance.
                This is being tracked in issue #1174.
            #>
            $restartSqlServiceParameters['SkipClusterCheck'] = $true
        }

        if ($PSBoundParameters.ContainsKey('IsEnabled') -and $IsEnabled -eq $false)
        {
            # If the protocol is disabled it is not possible to connect to the instance.
            $restartSqlServiceParameters['SkipWaitForOnline'] = $true
        }

        Restart-SqlService @restartSqlServiceParameters
    }
}

<#
    .SYNOPSIS
    Sets the SQL Server network properties.

    .PARAMETER ServerName
    The host name of the SQL Server to be configured. Default value is $env:COMPUTERNAME.

    Not used in Test-TargetResource.

    .PARAMETER InstanceName
    The name of the SQL instance to be configured.

    .PARAMETER ProtocolName
    The name of network protocol to be configured. Only tcp is currently supported.

    .PARAMETER IsEnabled
    Enables or disables the network protocol.

    .PARAMETER TcpDynamicPort
    Specifies whether the SQL Server instance should use a dynamic port.
    Value cannot be set to $true if TcpPort is set to a non-empty string.

    .PARAMETER TcpPort
    The TCP port(s) that SQL Server should be listening on.
    If the IP address should listen on more than one port, list all ports
    separated with a comma ('1433,1500,1501'). To use this parameter set
    TcpDynamicPort to 'False'.

    .PARAMETER RestartService
    If set to $true then SQL Server and dependent services will be restarted
    if a change to the configuration is made. The default value is $false.

    Not used in Test-TargetResource.

    .PARAMETER RestartTimeout
    Timeout value for restarting the SQL Server services. The default value
    is 120 seconds.

    Not used in Test-TargetResource.
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName = $env:COMPUTERNAME,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Tcp')]
        [System.String]
        $ProtocolName,

        [Parameter()]
        [System.Boolean]
        $IsEnabled,

        [Parameter()]
        [System.Boolean]
        $TcpDynamicPort,

        [Parameter()]
        [System.String]
        $TcpPort,

        [Parameter()]
        [System.Boolean]
        $RestartService = $false,

        [Parameter()]
        [System.UInt16]
        $RestartTimeout = 120
    )

    if ($TcpDynamicPort -and $TcpPort)
    {
        $errorMessage = $script:localizedData.ErrorDynamicAndStaticPortSpecified
        New-InvalidOperationException -Message $errorMessage
    }

    $getTargetResourceResult = Get-TargetResource -InstanceName $InstanceName -ProtocolName $ProtocolName

    Write-Verbose -Message $script:localizedData.CompareStates

    $isInDesiredState = $true

    if ($ProtocolName -ne $getTargetResourceResult.ProtocolName)
    {
        Write-Verbose -Message ($script:localizedData.ExpectedPropertyValue -f 'ProtocolName', $ProtocolName, $getTargetResourceResult.ProtocolName)

        $isInDesiredState = $false
    }

    if ($PSBoundParameters.ContainsKey('IsEnabled'))
    {
        if ($IsEnabled -ne $getTargetResourceResult.IsEnabled)
        {
            $evaluateEnableOrDisable = @{
                $true  = 'enabled'
                $false = 'disabled'
            }

            Write-Verbose -Message ($script:localizedData.ExpectedPropertyValue -f 'IsEnabled', $evaluateEnableOrDisable[$IsEnabled], $evaluateEnableOrDisable[$getTargetResourceResult.IsEnabled])

            $isInDesiredState = $false
        }
    }

    if ($PSBoundParameters.ContainsKey('TcpDynamicPort'))
    {
        if ($TcpDynamicPort -and $getTargetResourceResult.TcpDynamicPort -eq $false)
        {
            Write-Verbose -Message ($script:localizedData.ExpectedPropertyValue -f 'TcpDynamicPort', $TcpDynamicPort, $getTargetResourceResult.TcpDynamicPort)

            $isInDesiredState = $false
        }
    }

    if ($PSBoundParameters.ContainsKey('TcpPort'))
    {
        if ($getTargetResourceResult.TcpPort -eq '')
        {
            Write-Verbose -Message ($script:localizedData.ExpectedPropertyValue -f 'TcpPort', $TcpPort, $getTargetResourceResult.TcpPort)

            $isInDesiredState = $false
        }
        elseif ($TcpPort -ne $getTargetResourceResult.TcpPort)
        {
            Write-Verbose -Message ($script:localizedData.ExpectedPropertyValue -f 'TcpPort', $TcpPort, $getTargetResourceResult.TcpPort)

            $isInDesiredState = $false
        }
    }

    if ($isInDesiredState)
    {
        Write-Verbose -Message ($script:localizedData.InDesiredState)
    }

    return $isInDesiredState
}

Export-ModuleMember -Function *-TargetResource
