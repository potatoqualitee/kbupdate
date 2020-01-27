$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SqlServerDsc.Common'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SqlServerDsc.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_SqlAGListener'

<#
    .SYNOPSIS
        Returns the current state of the Availability Group listener.

    .PARAMETER InstanceName
        The SQL Server instance name of the primary replica. Default value is 'MSSQLSERVER'.

    .PARAMETER ServerName
        The host name or FQDN of the primary replica.

    .PARAMETER Name
        The name of the availability group listener, max 15 characters. This name will be used as the Virtual Computer Object (VCO).

    .PARAMETER AvailabilityGroup
        The name of the availability group to which the availability group listener is or will be connected.
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

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [ValidateLength(1, 15)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [System.String]
        $AvailabilityGroup
    )

    Write-Verbose -Message (
        $script:localizedData.GetAvailabilityGroupListener -f $Name, $AvailabilityGroup, $InstanceName
    )

    try
    {
        $availabilityGroupListener = Get-SQLAlwaysOnAvailabilityGroupListener -Name $Name -AvailabilityGroup $AvailabilityGroup -ServerName $ServerName -InstanceName $InstanceName

        if ($null -ne $availabilityGroupListener)
        {
            Write-Verbose -Message (
                $script:localizedData.AvailabilityGroupListenerIsPresent -f $Name
            )

            $ensure = 'Present'
            $port = [uint16]( $availabilityGroupListener | Select-Object -ExpandProperty PortNumber )

            $presentIpAddress = $availabilityGroupListener.AvailabilityGroupListenerIPAddresses
            $dhcp = [bool]( $presentIpAddress | Select-Object -First 1 -ExpandProperty IsDHCP )

            $ipAddress = @()
            foreach ($currentIpAddress in $presentIpAddress)
            {
                if ($currentIpAddress.SubnetMask)
                {
                    $ipAddress += "$($currentIpAddress.IPAddress)/$($currentIpAddress.SubnetMask)"
                }
                else
                {
                    $ipAddress += "$($currentIpAddress.IPAddress)"
                }
            }
        }
        else
        {
            Write-Verbose -Message (
                $script:localizedData.AvailabilityGroupListenerIsNotPresent -f $Name
            )

            $ensure = 'Absent'
            $port = 0
            $dhcp = $false
            $ipAddress = $null
        }
    }
    catch
    {
        $errorMessage = $script:localizedData.AvailabilityGroupListenerNotFound -f $AvailabilityGroup, $InstanceName
        New-ObjectNotFoundException -Message $errorMessage -ErrorRecord $_
    }

    return @{
        InstanceName      = [System.String] $InstanceName
        ServerName        = [System.String] $ServerName
        Name              = [System.String] $Name
        Ensure            = [System.String] $ensure
        AvailabilityGroup = [System.String] $AvailabilityGroup
        IpAddress         = [System.String[]] $ipAddress
        Port              = [System.UInt16] $port
        DHCP              = [System.Boolean] $dhcp
    }
}

<#
    .SYNOPSIS
        Creates the Availability Group listener.

    .PARAMETER InstanceName
        The SQL Server instance name of the primary replica. Default value is 'MSSQLSERVER'.

    .PARAMETER ServerName
        The host name or FQDN of the primary replica.

    .PARAMETER Name
        The name of the availability group listener, max 15 characters. This name will be used as the Virtual Computer Object (VCO).

    .PARAMETER Ensure
        If the availability group listener should be present or absent.

    .PARAMETER AvailabilityGroup
        The name of the availability group to which the availability group listener is or will be connected.

    .PARAMETER IpAddress
        The IP address used for the availability group listener, in the format 192.168.10.45/255.255.252.0. If using DHCP, set to the first IP-address of the DHCP subnet, in the format 192.168.8.1/255.255.252.0. Must be valid in the cluster-allowed IP range.

    .PARAMETER Port
        The port used for the availability group listener.

    .PARAMETER DHCP
        If DHCP should be used for the availability group listener instead of static IP address.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [ValidateLength(1, 15)]
        [System.String]
        $Name,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [System.String]
        $AvailabilityGroup,

        [Parameter()]
        [System.String[]]
        $IpAddress,

        [Parameter()]
        [System.UInt16]
        $Port,

        [Parameter()]
        [System.Boolean]
        $DHCP
    )

    $parameters = @{
        InstanceName      = [System.String] $InstanceName
        ServerName        = [System.String] $ServerName
        Name              = [System.String] $Name
        AvailabilityGroup = [System.String] $AvailabilityGroup
    }

    $availabilityGroupListenerState = Get-TargetResource @parameters
    if ($null -ne $availabilityGroupListenerState)
    {
        if ($Ensure -ne '' -and $availabilityGroupListenerState.Ensure -ne $Ensure)
        {
            if ($Ensure -eq 'Present')
            {
                Write-Verbose -Message (
                    $script:localizedData.CreateAvailabilityGroupListener -f $Name, $AvailabilityGroup, $InstanceName
                )

                $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

                $availabilityGroupObject = $sqlServerObject.AvailabilityGroups[$AvailabilityGroup]
                if ($availabilityGroupObject)
                {
                    $newListenerParams = @{
                        Name        = $Name
                        InputObject = $availabilityGroupObject
                    }

                    if ($Port)
                    {
                        Write-Verbose -Message (
                            $script:localizedData.SetAvailabilityGroupListenerPort -f $Port
                        )

                        $newListenerParams += @{
                            Port = $Port
                        }
                    }

                    if ($DHCP -and $IpAddress.Count -gt 0)
                    {
                        Write-Verbose -Message (
                            $script:localizedData.SetAvailabilityGroupListenerDhcp -f $IpAddress
                        )

                        $newListenerParams += @{
                            DhcpSubnet = [System.String] $IpAddress
                        }
                    }
                    elseif (-not $DHCP -and $IpAddress.Count -gt 0)
                    {
                        Write-Verbose -Message (
                            $script:localizedData.SetAvailabilityGroupListenerStaticIpAddress -f ($IpAddress -join ', ')
                        )

                        $newListenerParams += @{
                            StaticIp = $IpAddress
                        }
                    }
                    else
                    {
                        Write-Verbose -Message $script:localizedData.SetAvailabilityGroupListenerDhcpDefaultSubnet
                    }

                    New-SqlAvailabilityGroupListener @newListenerParams -ErrorAction Stop | Out-Null
                }
                else
                {
                    $errorMessage = $script:localizedData.AvailabilityGroupNotFound -f $AvailabilityGroup, $InstanceName
                    New-ObjectNotFoundException -Message $errorMessage
                }
            }
            else
            {
                Write-Verbose -Message (
                    $script:localizedData.DropAvailabilityGroupListener -f $Name, $AvailabilityGroup, $InstanceName
                )

                $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

                $availabilityGroupObject = $sqlServerObject.AvailabilityGroups[$AvailabilityGroup]
                if ($availabilityGroupObject)
                {
                    $availabilityGroupListenerObject = $availabilityGroupObject.AvailabilityGroupListeners[$Name]
                    if ($availabilityGroupListenerObject)
                    {
                        $availabilityGroupListenerObject.Drop()
                    }
                    else
                    {
                        $errorMessage = $script:localizedData.AvailabilityGroupListenerNotFound -f $AvailabilityGroup, $InstanceName
                        New-ObjectNotFoundException -Message $errorMessage
                    }
                }
                else
                {
                    $errorMessage = $script:localizedData.AvailabilityGroupNotFound -f $AvailabilityGroup, $InstanceName
                    New-ObjectNotFoundException -Message $errorMessage
                }
            }
        }
        else
        {
            if ($availabilityGroupListenerState.Ensure -eq 'Present')
            {
                Write-Verbose -Message (
                    $script:localizedData.AvailabilityGroupListenerIsPresent -f $Name
                )

                if (-not $DHCP -and $availabilityGroupListenerState.IpAddress.Count -lt $IpAddress.Count) # Only able to add a new IP-address, not change existing ones.
                {
                    Write-Verbose -Message $script:localizedData.FoundNewIpAddress

                    $ipAddressEqual = $false
                }
                else
                {
                    # No new IP-address
                    if ($null -eq $IpAddress -or -not ( Compare-Object -ReferenceObject $IpAddress -DifferenceObject $availabilityGroupListenerState.IpAddress))
                    {
                        $ipAddressEqual = $true
                    }
                    else
                    {
                        $errorMessage = $script:localizedData.AvailabilityGroupListenerIPChangeError -f ($IpAddress -join ', '), ($availabilityGroupListenerState.IpAddress -join ', ')
                        New-InvalidOperationException -Message $errorMessage
                    }
                }

                if ($($PSBoundParameters.ContainsKey('DHCP')) -and $availabilityGroupListenerState.DHCP -ne $DHCP)
                {
                    $errorMessage = $script:localizedData.AvailabilityGroupListenerDHCPChangeError -f $DHCP, $availabilityGroupListenerState.DHCP
                    New-InvalidOperationException -Message $errorMessage
                }

                $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

                $availabilityGroupObject = $sqlServerObject.AvailabilityGroups[$AvailabilityGroup]
                if ($availabilityGroupObject)
                {
                    $availabilityGroupListenerObject = $availabilityGroupObject.AvailabilityGroupListeners[$Name]
                    if ($availabilityGroupListenerObject)
                    {
                        if ($availabilityGroupListenerState.Port -ne $Port -or -not $ipAddressEqual)
                        {
                            Write-Verbose -Message (
                                $script:localizedData.AvailabilityGroupListenerNotInDesiredState -f $Name, $AvailabilityGroup, $InstanceName
                            )

                            if ($availabilityGroupListenerState.Port -ne $Port)
                            {
                                Write-Verbose -Message (
                                    $script:localizedData.ChangingAvailabilityGroupListenerPort -f $Port
                                )

                                $setListenerParams = @{
                                    InputObject = $availabilityGroupListenerObject
                                    Port        = $Port
                                }

                                Set-SqlAvailabilityGroupListener @setListenerParams -ErrorAction Stop | Out-Null
                            }

                            if (-not $ipAddressEqual)
                            {
                                $newIpAddress = @()

                                foreach ($currentIpAddress in $IpAddress)
                                {
                                    if (-not ( $availabilityGroupListenerState.IpAddress -contains $currentIpAddress))
                                    {
                                        Write-Verbose -Message (
                                            $script:localizedData.AddingAvailabilityGroupListenerIpAddress -f $currentIpAddress
                                        )

                                        $newIpAddress += $currentIpAddress
                                    }
                                }

                                $setListenerParams = @{
                                    InputObject = $availabilityGroupListenerObject
                                    StaticIp    = $newIpAddress
                                }

                                Add-SqlAvailabilityGroupListenerStaticIp @setListenerParams -ErrorAction Stop | Out-Null
                            }
                        }
                        else
                        {
                            Write-Verbose -Message (
                                $script:localizedData.AvailabilityGroupListenerInDesiredState -f $Name, $AvailabilityGroup, $InstanceName
                            )
                        }
                    }
                    else
                    {
                        $errorMessage = $script:localizedData.AvailabilityGroupListenerNotFound -f $AvailabilityGroup, $InstanceName
                        New-ObjectNotFoundException -Message $errorMessage
                    }
                }
                else
                {
                    $errorMessage = $script:localizedData.AvailabilityGroupNotFound -f $AvailabilityGroup, $InstanceName
                    New-ObjectNotFoundException -Message $errorMessage
                }
            }
        }
    }
    else
    {
        $errorMessage = $script:localizedData.UnexpectedErrorFromGet
        New-InvalidResultException -Message $errorMessage
    }
}

<#
    .SYNOPSIS
        Tests if the the Availability Group listener is in desired state.

    .PARAMETER InstanceName
        The SQL Server instance name of the primary replica. Default value is 'MSSQLSERVER'.

    .PARAMETER ServerName
        The host name or FQDN of the primary replica.

    .PARAMETER Name
        The name of the availability group listener, max 15 characters. This name will be used as the Virtual Computer Object (VCO).

    .PARAMETER Ensure
        If the availability group listener should be present or absent.

    .PARAMETER AvailabilityGroup
        The name of the availability group to which the availability group listener is or will be connected.

    .PARAMETER IpAddress
        The IP address used for the availability group listener, in the format 192.168.10.45/255.255.252.0. If using DHCP, set to the first IP-address of the DHCP subnet, in the format 192.168.8.1/255.255.252.0. Must be valid in the cluster-allowed IP range.

    .PARAMETER Port
        The port used for the availability group listener.

    .PARAMETER DHCP
        If DHCP should be used for the availability group listener instead of static IP address.
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [ValidateLength(1, 15)]
        [System.String]
        $Name,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [System.String]
        $AvailabilityGroup,

        [Parameter()]
        [System.String[]]
        $IpAddress,

        [Parameter()]
        [System.UInt16]
        $Port,

        [Parameter()]
        [System.Boolean]
        $DHCP
    )

    $parameters = @{
        InstanceName      = [System.String] $InstanceName
        ServerName        = [System.String] $ServerName
        Name              = [System.String] $Name
        AvailabilityGroup = [System.String] $AvailabilityGroup
    }

    Write-Verbose -Message (
        $script:localizedData.TestingConfiguration -f $Name, $AvailabilityGroup, $InstanceName
    )

    $availabilityGroupListenerState = Get-TargetResource @parameters
    if ($null -ne $availabilityGroupListenerState)
    {
        if ($null -eq $IpAddress -or ($null -ne $availabilityGroupListenerState.IpAddress -and -not ( Compare-Object -ReferenceObject $IpAddress -DifferenceObject $availabilityGroupListenerState.IpAddress)))
        {
            $ipAddressEqual = $true
        }
        else
        {
            $ipAddressEqual = $false
        }

        [System.Boolean] $result = $false
        if ($availabilityGroupListenerState.Ensure -eq $Ensure)
        {
            if ($Ensure -eq 'Absent')
            {
                $result = $true
            }
        }

        if (-not $($PSBoundParameters.ContainsKey('Ensure')) -or $Ensure -eq 'Present')
        {
            if (($Port -eq "" -or $availabilityGroupListenerState.Port -eq $Port) -and
                $ipAddressEqual -and
                (-not $($PSBoundParameters.ContainsKey('DHCP')) -or $availabilityGroupListenerState.DHCP -eq $DHCP))
            {
                $result = $true
            }
        }
    }
    else
    {
        $errorMessage = $script:localizedData.UnexpectedErrorFromGet
        New-InvalidResultException -Message $errorMessage
    }

    if ($result)
    {
        Write-Verbose -Message (
            $script:localizedData.AvailabilityGroupListenerInDesiredState -f $Name, $AvailabilityGroup, $InstanceName
        )
    }
    else
    {
        Write-Verbose -Message (
            $script:localizedData.AvailabilityGroupListenerNotInDesiredState -f $Name, $AvailabilityGroup, $InstanceName
        )
    }

    return $result
}

function Get-SQLAlwaysOnAvailabilityGroupListener
{
    [CmdletBinding()]
    [OutputType()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [System.String]
        $AvailabilityGroup,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName
    )

    Write-Debug -Message (
        $script:localizedData.DebugConnectingAvailabilityGroup -f $Name, [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    )

    $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

    $availabilityGroupObject = $sqlServerObject.AvailabilityGroups[$AvailabilityGroup]
    if ($availabilityGroupObject)
    {
        $availabilityGroupListener = $availabilityGroupObject.AvailabilityGroupListeners[$Name]
    }
    else
    {
        $errorMessage = $script:localizedData.AvailabilityGroupNotFound -f $AvailabilityGroup, $InstanceName
        New-ObjectNotFoundException -Message $errorMessage
    }

    return $availabilityGroupListener
}

Export-ModuleMember -Function *-TargetResource
