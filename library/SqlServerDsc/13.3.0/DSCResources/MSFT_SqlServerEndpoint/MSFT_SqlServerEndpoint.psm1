$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SqlServerDsc.Common'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SqlServerDsc.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_SqlServerEndpoint'

<#
    .SYNOPSIS
        Returns the current state of the endpoint.

    .PARAMETER EndpointName
        The name of the endpoint.

    .PARAMETER ServerName
        The host name of the SQL Server to be configured. Default value is $env:COMPUTERNAME.

    .PARAMETER InstanceName
        The name of the SQL instance to be configured.
#>
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $EndpointName,

        [Parameter()]
        [System.String]
        $ServerName = $env:COMPUTERNAME,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName
    )

    Write-Verbose -Message (
        $script:localizedData.GetEndpoint -f $EndpointName, $InstanceName
    )

    $getTargetResourceReturnValues = @{
        ServerName   = $ServerName
        InstanceName = $InstanceName
        Ensure       = 'Absent'
        EndpointName = ''
        Port         = ''
        IpAddress    = ''
        Owner        = ''
    }

    $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName
    if ($sqlServerObject)
    {
        Write-Verbose -Message (
            $script:localizedData.ConnectedToInstance -f $ServerName, $InstanceName
        )

        $endpointObject = $sqlServerObject.Endpoints[$EndpointName]
        if ($endpointObject.Name -eq $EndpointName)
        {
            if ($sqlServerObject.Endpoints[$EndPointName].EndpointType -ne 'DatabaseMirroring')
            {
                $errorMessage = $script:localizedData.EndpointFoundButWrongType -f $EndpointName
                New-InvalidOperationException -Message $errorMessage
            }

            $getTargetResourceReturnValues.Ensure = 'Present'
            $getTargetResourceReturnValues.EndpointName = $endpointObject.Name
            $getTargetResourceReturnValues.Port = $endpointObject.Protocol.Tcp.ListenerPort
            $getTargetResourceReturnValues.IpAddress = $endpointObject.Protocol.Tcp.ListenerIPAddress
            $getTargetResourceReturnValues.Owner = $endpointObject.Owner
        }
        else
        {
            $getTargetResourceReturnValues.Ensure = 'Absent'
            $getTargetResourceReturnValues.EndpointName = ''
            $getTargetResourceReturnValues.Port = ''
            $getTargetResourceReturnValues.IpAddress = ''
            $getTargetResourceReturnValues.Owner = ''
        }
    }
    else
    {
        $errorMessage = $script:localizedData.NotConnectedToInstance -f $ServerName, $InstanceName
        New-InvalidOperationException -Message $errorMessage
    }

    return $getTargetResourceReturnValues
}

<#
    .SYNOPSIS
        Create, changes or drops an endpoint.

    .PARAMETER EndpointName
        The name of the endpoint.

    .PARAMETER Ensure
        If the endpoint should be present or absent. Default values is 'Present'.

    .PARAMETER Port
        The network port the endpoint is listening on. Default value is 5022.

    .PARAMETER ServerName
        The host name of the SQL Server to be configured. Default value is $env:COMPUTERNAME.

    .PARAMETER InstanceName
        The name of the SQL instance to be configured.

    .PARAMETER IpAddress
        The network IP address the endpoint is listening on. Defaults to '0.0.0.0' which means listen on any valid IP address.

    .PARAMETER Owner
        The owner of the endpoint. Default is the login used for the creation.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $EndpointName,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.UInt16]
        $Port = 5022,

        [Parameter()]
        [System.String]
        $ServerName = $env:COMPUTERNAME,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter()]
        [System.String]
        $IpAddress = '0.0.0.0',

        [Parameter()]
        [System.String]
        $Owner
    )

    $getTargetResourceResult = Get-TargetResource -EndpointName $EndpointName -ServerName $ServerName -InstanceName $InstanceName

    $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName
    if ($sqlServerObject)
    {
        if ($Ensure -eq 'Present' -and $getTargetResourceResult.Ensure -eq 'Absent')
        {
            Write-Verbose -Message (
                $script:localizedData.CreateEndpoint -f $EndpointName, $InstanceName
            )

            $endpointObject = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Endpoint -ArgumentList $sqlServerObject, $EndpointName
            $endpointObject.EndpointType = [Microsoft.SqlServer.Management.Smo.EndpointType]::DatabaseMirroring
            $endpointObject.ProtocolType = [Microsoft.SqlServer.Management.Smo.ProtocolType]::Tcp
            $endpointObject.Protocol.Tcp.ListenerPort = $Port
            $endpointObject.Protocol.Tcp.ListenerIPAddress = $IpAddress

            if ($PSBoundParameters.ContainsKey('Owner'))
            {
                $endpointObject.Owner = $Owner
            }

            $endpointObject.Payload.DatabaseMirroring.ServerMirroringRole = [Microsoft.SqlServer.Management.Smo.ServerMirroringRole]::All
            $endpointObject.Payload.DatabaseMirroring.EndpointEncryption = [Microsoft.SqlServer.Management.Smo.EndpointEncryption]::Required
            $endpointObject.Payload.DatabaseMirroring.EndpointEncryptionAlgorithm = [Microsoft.SqlServer.Management.Smo.EndpointEncryptionAlgorithm]::Aes
            $endpointObject.Create()
            $endpointObject.Start()
        }
        elseif ($Ensure -eq 'Present' -and $getTargetResourceResult.Ensure -eq 'Present')
        {
            Write-Verbose -Message (
                $script:localizedData.SetEndpoint -f $EndpointName, $InstanceName
            )

            # The endpoint already exist, verifying supported endpoint properties so they are in desired state.
            $endpointObject = $sqlServerObject.Endpoints[$EndpointName]
            if ($endpointObject)
            {
                if ($endpointObject.Protocol.Tcp.ListenerIPAddress -ne $IpAddress)
                {
                    Write-Verbose -Message (
                        $script:localizedData.UpdatingEndpointIPAddress -f $IpAddress
                    )

                    $endpointObject.Protocol.Tcp.ListenerIPAddress = $IpAddress
                    $endpointObject.Alter()
                }

                if ($endpointObject.Protocol.Tcp.ListenerPort -ne $Port)
                {
                    Write-Verbose -Message (
                        $script:localizedData.UpdatingEndpointPort -f $Port
                    )

                    $endpointObject.Protocol.Tcp.ListenerPort = $Port
                    $endpointObject.Alter()
                }

                if ($endpointObject.Owner -ne $Owner)
                {
                    Write-Verbose -Message (
                        $script:localizedData.UpdatingEndpointOwner -f $Owner
                    )

                    $endpointObject.Owner = $Owner
                    $endpointObject.Alter()
                }
            }
            else
            {
                $errorMessage = $script:localizedData.EndpointNotFound -f $EndpointName
                New-ObjectNotFoundException -Message $errorMessage
            }
        }
        elseif ($Ensure -eq 'Absent' -and $getTargetResourceResult.Ensure -eq 'Present')
        {
            $endpointObject = $sqlServerObject.Endpoints[$EndpointName]
            if ($endpointObject)
            {
                Write-Verbose -Message (
                    $script:localizedData.DropEndpoint -f $EndpointName, $InstanceName
                )

                $endpointObject.Drop()
            }
            else
            {
                $errorMessage = $script:localizedData.EndpointNotFound -f $EndpointName
                New-ObjectNotFoundException -Message $errorMessage
            }
        }
    }
    else
    {
        $errorMessage = $script:localizedData.NotConnectedToInstance -f $ServerName, $InstanceName
        New-InvalidOperationException -Message $errorMessage
    }
}

<#
    .SYNOPSIS
        Tests if the principal (login) has the desired permissions.

    .PARAMETER EndpointName
        The name of the endpoint.

    .PARAMETER Ensure
        If the endpoint should be present or absent. Default values is 'Present'.

    .PARAMETER Port
        The network port the endpoint is listening on. Default value is 5022.

    .PARAMETER ServerName
        The host name of the SQL Server to be configured. Default value is $env:COMPUTERNAME.

    .PARAMETER InstanceName
        The name of the SQL instance to be configured.

    .PARAMETER IpAddress
        The network IP address the endpoint is listening on. Defaults to '0.0.0.0' which means listen on any valid IP address.

    .PARAMETER Owner
        The owner of the endpoint. Default is the login used for the creation.
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $EndpointName,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.UInt16]
        $Port = 5022,

        [Parameter()]
        [System.String]
        $ServerName = $env:COMPUTERNAME,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter()]
        [System.String]
        $IpAddress = '0.0.0.0',

        [Parameter()]
        [System.String]
        $Owner
    )

    Write-Verbose -Message (
        $script:localizedData.TestingConfiguration -f $EndpointName, $InstanceName
    )

    $getTargetResourceResult = Get-TargetResource -EndpointName $EndpointName -ServerName $ServerName -InstanceName $InstanceName
    if ($getTargetResourceResult.Ensure -eq $Ensure)
    {
        $result = $true

        if ($getTargetResourceResult.Ensure -eq 'Present' `
                -and (
                        $getTargetResourceResult.Port -ne $Port `
                    -or $getTargetResourceResult.IpAddress -ne $IpAddress
                )
        )
        {
            $result = $false
        }
        elseif ($getTargetResourceResult.Ensure -eq 'Present' -and $Owner `
                -and $getTargetResourceResult.Owner -ne $Owner
        )
        {
            $result = $false
        }
    }
    else
    {
        $result = $false
    }

    if ($result)
    {
        Write-Verbose -Message (
            $script:localizedData.InDesiredState -f $EndpointName
        )
    }
    else
    {
        Write-Verbose -Message (
            $script:localizedData.NotInDesiredState -f $EndpointName
        )
    }

    return $result
}

Export-ModuleMember -Function *-TargetResource
