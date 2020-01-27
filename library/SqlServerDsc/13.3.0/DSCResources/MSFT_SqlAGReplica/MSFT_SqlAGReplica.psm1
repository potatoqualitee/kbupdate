$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SqlServerDsc.Common'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SqlServerDsc.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_SqlAGReplica'
<#
    .SYNOPSIS
        Gets the specified Availability Group Replica from the specified Availability Group.

    .PARAMETER Name
        The name of the availability group replica. For named instances this
        must be in the following format ServerName\InstanceName.

    .PARAMETER AvailabilityGroupName
        The name of the availability group.

    .PARAMETER ServerName
        Hostname of the SQL Server to be configured.

    .PARAMETER InstanceName
        Name of the SQL instance to be configured.
#>
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [System.String]
        $AvailabilityGroupName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName
    )

    Write-Verbose -Message (
        $script:localizedData.GetAvailabilityGroup -f $Name, $AvailabilityGroupName, $InstanceName
    )

    # Connect to the instance
    $serverObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

    # Is this node actively hosting the SQL instance?
    $isActiveNode = Test-ActiveNode -ServerObject $serverObject

    # Get the endpoint properties
    $endpoint = $serverObject.Endpoints | Where-Object -FilterScript { $_.EndpointType -eq 'DatabaseMirroring' }
    if ( $endpoint )
    {
        $endpointPort = $endpoint.Protocol.Tcp.ListenerPort
    }

    # Create the return object
    $alwaysOnAvailabilityGroupReplicaResource = @{
        Ensure                        = 'Absent'
        Name                          = ''
        AvailabilityGroupName         = ''
        AvailabilityMode              = ''
        BackupPriority                = ''
        ConnectionModeInPrimaryRole   = ''
        ConnectionModeInSecondaryRole = ''
        FailoverMode                  = ''
        EndpointUrl                   = ''
        IsActiveNode                  = $isActiveNode
        ReadOnlyRoutingConnectionUrl  = ''
        ReadOnlyRoutingList           = @()
        ServerName                    = $ServerName
        InstanceName                  = $InstanceName
        EndpointPort                  = $endpointPort
        EndpointHostName              = $serverObject.NetName
    }

    # Get the availability group
    $availabilityGroup = $serverObject.AvailabilityGroups[$AvailabilityGroupName]

    if ( $availabilityGroup )
    {
        # Add the Availability Group name to the results
        $alwaysOnAvailabilityGroupReplicaResource.AvailabilityGroupName = $availabilityGroup.Name

        # Try to find the replica
        $availabilityGroupReplica = $availabilityGroup.AvailabilityReplicas[$Name]

        if ( $availabilityGroupReplica )
        {
            # Add the Availability Group Replica properties to the results
            $alwaysOnAvailabilityGroupReplicaResource.Ensure = 'Present'
            $alwaysOnAvailabilityGroupReplicaResource.Name = $availabilityGroupReplica.Name
            $alwaysOnAvailabilityGroupReplicaResource.AvailabilityMode = $availabilityGroupReplica.AvailabilityMode
            $alwaysOnAvailabilityGroupReplicaResource.BackupPriority = $availabilityGroupReplica.BackupPriority
            $alwaysOnAvailabilityGroupReplicaResource.ConnectionModeInPrimaryRole = $availabilityGroupReplica.ConnectionModeInPrimaryRole
            $alwaysOnAvailabilityGroupReplicaResource.ConnectionModeInSecondaryRole = $availabilityGroupReplica.ConnectionModeInSecondaryRole
            $alwaysOnAvailabilityGroupReplicaResource.FailoverMode = $availabilityGroupReplica.FailoverMode
            $alwaysOnAvailabilityGroupReplicaResource.EndpointUrl = $availabilityGroupReplica.EndpointUrl
            $alwaysOnAvailabilityGroupReplicaResource.ReadOnlyRoutingConnectionUrl = $availabilityGroupReplica.ReadOnlyRoutingConnectionUrl
            $alwaysOnAvailabilityGroupReplicaResource.ReadOnlyRoutingList = $availabilityGroupReplica.ReadOnlyRoutingList
        }
    }

    return $alwaysOnAvailabilityGroupReplicaResource
}

<#
    .SYNOPSIS
        Creates or removes the availability group replica in accordance with the desired state.

    .PARAMETER Name
        The name of the availability group replica. For named instances this
        must be in the following format ServerName\InstanceName.

    .PARAMETER AvailabilityGroupName
        The name of the availability group.

    .PARAMETER ServerName
        Hostname of the SQL Server to be configured.

    .PARAMETER InstanceName
        Name of the SQL instance to be configured.

    .PARAMETER PrimaryReplicaServerName
        Hostname of the SQL Server where the primary replica is expected to be active. If the primary replica is not found here, the resource will attempt to find the host that holds the primary replica and connect to it.

    .PARAMETER PrimaryReplicaInstanceName
        Name of the SQL instance where the primary replica lives.

    .PARAMETER Ensure
        Specifies if the availability group should be present or absent. Default is Present.

    .PARAMETER AvailabilityMode
        Specifies the replica availability mode. Default when creating a replica is 'AsynchronousCommit'.

    .PARAMETER BackupPriority
        Specifies the desired priority of the replicas in performing backups. The acceptable values for this parameter are integers from 0 through 100. Of the set of replicas which are online and available, the replica that has the highest priority performs the backup. When creating a replica the default is 50.

    .PARAMETER ConnectionModeInPrimaryRole
        Specifies how the availability replica handles connections when in the primary role.

    .PARAMETER ConnectionModeInSecondaryRole
        Specifies how the availability replica handles connections when in the secondary role.

    .PARAMETER EndpointHostName
        Specifies the hostname or IP address of the availability group replica endpoint. When creating a group the default is the instance network name which is set in the code because the value can only be determined when connected to the SQL Instance.

    .PARAMETER FailoverMode
        Specifies the failover mode. When creating a replica the default is 'Manual'.

    .PARAMETER ReadOnlyRoutingConnectionUrl
        Specifies the fully-qualified domain name (FQDN) and port to use when routing to the replica for read only connections.

    .PARAMETER ReadOnlyRoutingList
        Specifies an ordered list of replica server names that represent the probe sequence for connection director to use when redirecting read-only connections through this availability replica. This parameter applies if the availability replica is the current primary replica of the availability group.

    .PARAMETER ProcessOnlyOnActiveNode
        Specifies that the resource will only determine if a change is needed if the target node is the active host of the SQL Server Instance.
        Not used in Set-TargetResource.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [System.String]
        $AvailabilityGroupName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter()]
        [System.String]
        $PrimaryReplicaServerName,

        [Parameter()]
        [System.String]
        $PrimaryReplicaInstanceName,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [ValidateSet('AsynchronousCommit', 'SynchronousCommit')]
        [System.String]
        $AvailabilityMode,

        [Parameter()]
        [ValidateRange(0, 100)]
        [System.UInt32]
        $BackupPriority,

        [Parameter()]
        [ValidateSet('AllowAllConnections', 'AllowReadWriteConnections')]
        [System.String]
        $ConnectionModeInPrimaryRole,

        [Parameter()]
        [ValidateSet('AllowNoConnections', 'AllowReadIntentConnectionsOnly', 'AllowAllConnections')]
        [System.String]
        $ConnectionModeInSecondaryRole,

        [Parameter()]
        [System.String]
        $EndpointHostName,

        [Parameter()]
        [ValidateSet('Automatic', 'Manual')]
        [System.String]
        $FailoverMode,

        [Parameter()]
        [System.String]
        $ReadOnlyRoutingConnectionUrl,

        [Parameter()]
        [System.String[]]
        $ReadOnlyRoutingList,

        [Parameter()]
        [System.Boolean]
        $ProcessOnlyOnActiveNode
    )

    Import-SQLPSModule

    # Connect to the instance
    $serverObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

    # Determine if HADR is enabled on the instance. If not, throw an error
    if ( -not $serverObject.IsHadrEnabled )
    {
        $errorMessage = $script:localizedData.HadrNotEnabled
        New-InvalidOperationException -Message $errorMessage
    }

    # Get the Availability Group if it exists
    $availabilityGroup = $serverObject.AvailabilityGroups[$AvailabilityGroupName]

    # Make sure we're communicating with the primary replica in order to make changes to the replica
    if ( $availabilityGroup )
    {
        while ( $availabilityGroup.LocalReplicaRole -ne 'Primary' )
        {
            $primaryServerObject = Get-PrimaryReplicaServerObject -ServerObject $serverObject -AvailabilityGroup $availabilityGroup
            $availabilityGroup = $primaryServerObject.AvailabilityGroups[$AvailabilityGroupName]
        }
    }

    switch ( $Ensure )
    {
        'Absent'
        {
            if ( $availabilityGroup )
            {
                $availabilityGroupReplica = $availabilityGroup.AvailabilityReplicas[$Name]

                if ( $availabilityGroupReplica )
                {
                    try
                    {
                        Write-Verbose -Message (
                            $script:localizedData.RemoveAvailabilityReplica -f $Name, $AvailabilityGroupName, $InstanceName
                        )

                        Remove-SqlAvailabilityReplica -InputObject $availabilityGroupReplica -Confirm:$false -ErrorAction Stop
                    }
                    catch
                    {
                        $errorMessage = $script:localizedData.FailedRemoveAvailabilityGroupReplica -f $Name, $AvailabilityGroupName, $InstanceName
                        New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
                    }
                }
            }
        }

        'Present'
        {
            # Ensure the appropriate cluster permissions are present
            Test-ClusterPermissions -ServerObject $serverObject

            # Make sure a database mirroring endpoint exists.
            $endpoint = $serverObject.Endpoints | Where-Object -FilterScript { $_.EndpointType -eq 'DatabaseMirroring' }
            if ( -not $endpoint )
            {
                $errorMessage = $script:localizedData.DatabaseMirroringEndpointNotFound -f ('{0}\{1}' -f $ServerName, $InstanceName)
                New-ObjectNotFoundException -Message $errorMessage
            }

            # If a hostname for the endpoint was not specified, define it now.
            if ( -not $EndpointHostName )
            {
                $EndpointHostName = $serverObject.NetName
            }

            # Get the endpoint port
            $endpointPort = $endpoint.Protocol.Tcp.ListenerPort

            # Determine if the Availability Group exists on the instance
            if ( $availabilityGroup )
            {
                # Make sure the replica exists on the instance. If the availability group exists, the replica should exist.
                $availabilityGroupReplica = $availabilityGroup.AvailabilityReplicas[$Name]
                if ( $availabilityGroupReplica )
                {
                    # Get the parameters that were submitted to the function
                    [System.Array] $submittedParameters = $PSBoundParameters.Keys

                    if ( ( $submittedParameters -contains 'AvailabilityMode' ) -and (  $AvailabilityMode -ne $availabilityGroupReplica.AvailabilityMode ) )
                    {
                        $availabilityGroupReplica.AvailabilityMode = $AvailabilityMode
                        Update-AvailabilityGroupReplica -AvailabilityGroupReplica $availabilityGroupReplica
                    }

                    if ( ( $submittedParameters -contains 'BackupPriority' ) -and ( $BackupPriority -ne $availabilityGroupReplica.BackupPriority ) )
                    {
                        $availabilityGroupReplica.BackupPriority = $BackupPriority
                        Update-AvailabilityGroupReplica -AvailabilityGroupReplica $availabilityGroupReplica
                    }

                    # Make sure ConnectionModeInPrimaryRole has a value in order to avoid false positive matches when the parameter is not defined
                    if ( ( -not [System.String]::IsNullOrEmpty($ConnectionModeInPrimaryRole) ) -and ( $ConnectionModeInPrimaryRole -ne $availabilityGroupReplica.ConnectionModeInPrimaryRole ) )
                    {
                        $availabilityGroupReplica.ConnectionModeInPrimaryRole = $ConnectionModeInPrimaryRole
                        Update-AvailabilityGroupReplica -AvailabilityGroupReplica $availabilityGroupReplica
                    }

                    # Make sure ConnectionModeInSecondaryRole has a value in order to avoid false positive matches when the parameter is not defined
                    if ( ( -not [System.String]::IsNullOrEmpty($ConnectionModeInSecondaryRole) ) -and ( $ConnectionModeInSecondaryRole -ne $availabilityGroupReplica.ConnectionModeInSecondaryRole ) )
                    {
                        $availabilityGroupReplica.ConnectionModeInSecondaryRole = $ConnectionModeInSecondaryRole
                        Update-AvailabilityGroupReplica -AvailabilityGroupReplica $availabilityGroupReplica
                    }

                    # Break out the EndpointUrl properties
                    $currentEndpointProtocol, $currentEndpointHostName, $currentEndpointPort = $availabilityGroupReplica.EndpointUrl.Replace('//', '').Split(':')

                    if ( $endpoint.Protocol.Tcp.ListenerPort -ne $currentEndpointPort )
                    {
                        $newEndpointUrl = $availabilityGroupReplica.EndpointUrl.Replace($currentEndpointPort, $endpoint.Protocol.Tcp.ListenerPort)
                        $availabilityGroupReplica.EndpointUrl = $newEndpointUrl
                        Update-AvailabilityGroupReplica -AvailabilityGroupReplica $availabilityGroupReplica
                    }

                    if ( ( $submittedParameters -contains 'EndpointHostName' ) -and ( $EndpointHostName -ne $currentEndpointHostName ) )
                    {
                        $newEndpointUrl = $availabilityGroupReplica.EndpointUrl.Replace($currentEndpointHostName, $EndpointHostName)
                        $availabilityGroupReplica.EndpointUrl = $newEndpointUrl
                        Update-AvailabilityGroupReplica -AvailabilityGroupReplica $availabilityGroupReplica
                    }

                    if ( $currentEndpointProtocol -ne 'TCP' )
                    {
                        $newEndpointUrl = $availabilityGroupReplica.EndpointUrl.Replace($currentEndpointProtocol, 'TCP')
                        $availabilityGroupReplica.EndpointUrl = $newEndpointUrl
                        Update-AvailabilityGroupReplica -AvailabilityGroupReplica $availabilityGroupReplica
                    }

                    if ( ( $submittedParameters -contains 'FailoverMode' ) -and ( $FailoverMode -ne $availabilityGroupReplica.FailoverMode ) )
                    {
                        $availabilityGroupReplica.FailoverMode = $FailoverMode
                        Update-AvailabilityGroupReplica -AvailabilityGroupReplica $availabilityGroupReplica
                    }

                    if ( ( $submittedParameters -contains 'ReadOnlyRoutingConnectionUrl' ) -and ( $ReadOnlyRoutingConnectionUrl -ne $availabilityGroupReplica.ReadOnlyRoutingConnectionUrl ) )
                    {
                        $availabilityGroupReplica.ReadOnlyRoutingConnectionUrl = $ReadOnlyRoutingConnectionUrl
                        Update-AvailabilityGroupReplica -AvailabilityGroupReplica $availabilityGroupReplica
                    }

                    if ( ( $submittedParameters -contains 'ReadOnlyRoutingList' ) -and ( ( $ReadOnlyRoutingList -join ',' ) -ne ( $availabilityGroupReplica.ReadOnlyRoutingList -join ',' ) ) )
                    {
                        $availabilityGroupReplica.ReadOnlyRoutingList.Clear()
                        foreach ( $readOnlyRoutingListEntry in $ReadOnlyRoutingList )
                        {
                            $availabilityGroupReplica.ReadOnlyRoutingList.Add($readOnlyRoutingListEntry) | Out-Null
                        }
                        Update-AvailabilityGroupReplica -AvailabilityGroupReplica $availabilityGroupReplica
                    }
                }
                else
                {
                    $errorMessage = $script:localizedData.ReplicaNotFound -f $Name, $AvailabilityGroupName, $InstanceName
                    New-ObjectNotFoundException -Message $errorMessage
                }
            }
            else
            {
                # Connect to the instance that is supposed to house the primary replica
                $primaryReplicaServerObject = Connect-SQL -ServerName $PrimaryReplicaServerName -InstanceName $PrimaryReplicaInstanceName

                # Verify the Availability Group exists on the supplied primary replica
                $primaryReplicaAvailabilityGroup = $primaryReplicaServerObject.AvailabilityGroups[$AvailabilityGroupName]
                if ( $primaryReplicaAvailabilityGroup )
                {
                    # Make sure the instance defined as the primary replica in the parameters is actually the primary replica
                    $primaryReplicaServerObject = Get-PrimaryReplicaServerObject -ServerObject $primaryReplicaServerObject -AvailabilityGroup $primaryReplicaAvailabilityGroup
                    $availabilityGroup = $primaryReplicaServerObject.AvailabilityGroups[$AvailabilityGroupName]

                    # Build the endpoint URL
                    $endpointUrl = "TCP://$($EndpointHostName):$($endpointPort)"

                    $newAvailabilityGroupReplicaParams = @{
                        Name             = $Name
                        InputObject      = $primaryReplicaAvailabilityGroup
                        AvailabilityMode = $AvailabilityMode
                        EndpointUrl      = $endpointUrl
                        FailoverMode     = $FailoverMode
                        Verbose          = $false
                    }

                    if ( $BackupPriority )
                    {
                        $newAvailabilityGroupReplicaParams.Add('BackupPriority', $BackupPriority)
                    }

                    if ( $ConnectionModeInPrimaryRole )
                    {
                        $newAvailabilityGroupReplicaParams.Add('ConnectionModeInPrimaryRole', $ConnectionModeInPrimaryRole)
                    }

                    if ( $ConnectionModeInSecondaryRole )
                    {
                        $newAvailabilityGroupReplicaParams.Add('ConnectionModeInSecondaryRole', $ConnectionModeInSecondaryRole)
                    }

                    if ( $ReadOnlyRoutingConnectionUrl )
                    {
                        $newAvailabilityGroupReplicaParams.Add('ReadOnlyRoutingConnectionUrl', $ReadOnlyRoutingConnectionUrl)
                    }

                    if ( $ReadOnlyRoutingList )
                    {
                        $newAvailabilityGroupReplicaParams.Add('ReadOnlyRoutingList', $ReadOnlyRoutingList)
                    }

                    # Create the Availability Group Replica
                    try
                    {
                        Write-Verbose -Message (
                            $script:localizedData.PrepareAvailabilityReplica -f $Name, $AvailabilityGroupName, $InstanceName
                        )

                        $availabilityGroupReplica = New-SqlAvailabilityReplica @newAvailabilityGroupReplicaParams
                    }
                    catch
                    {
                        $errorMessage = $script:localizedData.FailedCreateAvailabilityGroupReplica -f $Name, $AvailabilityGroupName, $InstanceName
                        New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
                    }

                    # Join the Availability Group Replica to the Availability Group
                    try
                    {
                        Write-Verbose -Message (
                            $script:localizedData.JoinAvailabilityGroup -f $Name, $AvailabilityGroupName, $InstanceName
                        )

                        Join-SqlAvailabilityGroup -Name $AvailabilityGroupName -InputObject $serverObject | Out-Null
                    }
                    catch
                    {
                        $errorMessage = $script:localizedData.FailedJoinAvailabilityGroup -f $Name, $AvailabilityGroupName, $InstanceName
                        New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
                    }
                }
                # The Availability Group doesn't exist on the primary replica
                else
                {
                    $errorMessage = $script:localizedData.AvailabilityGroupNotFound -f $AvailabilityGroupName, $InstanceName
                    New-ObjectNotFoundException -Message $errorMessage
                }
            }
        }
    }
}

<#
    .SYNOPSIS
        Determines if the availability group replica is in the desired state.

    .PARAMETER Name
        The name of the availability group replica. For named instances this
        must be in the following format ServerName\InstanceName.

    .PARAMETER AvailabilityGroupName
        The name of the availability group.

    .PARAMETER ServerName
        Hostname of the SQL Server to be configured.

    .PARAMETER InstanceName
        Name of the SQL instance to be configured.

    .PARAMETER PrimaryReplicaServerName
        Hostname of the SQL Server where the primary replica is expected to be active. If the primary replica is not found here, the resource will attempt to find the host that holds the primary replica and connect to it.

    .PARAMETER PrimaryReplicaInstanceName
        Name of the SQL instance where the primary replica lives.

    .PARAMETER Ensure
        Specifies if the availability group should be present or absent. Default is Present.

    .PARAMETER AvailabilityMode
        Specifies the replica availability mode. Default when creating a replica is 'AsynchronousCommit'.

    .PARAMETER BackupPriority
        Specifies the desired priority of the replicas in performing backups. The acceptable values for this parameter are integers from 0 through 100. Of the set of replicas which are online and available, the replica that has the highest priority performs the backup. When creating a replica the default is 50.

    .PARAMETER ConnectionModeInPrimaryRole
        Specifies how the availability replica handles connections when in the primary role.

    .PARAMETER ConnectionModeInSecondaryRole
        Specifies how the availability replica handles connections when in the secondary role.

    .PARAMETER EndpointHostName
        Specifies the hostname or IP address of the availability group replica endpoint. wWhen creating a group the default is the instance network name which is set in the code because the value can only be determined when connected to the SQL Instance.

    .PARAMETER FailoverMode
        Specifies the failover mode. When creating a replica the default is 'Manual'.

    .PARAMETER ReadOnlyRoutingConnectionUrl
        Specifies the fully-qualified domain name (FQDN) and port to use when routing to the replica for read only connections.

    .PARAMETER ReadOnlyRoutingList
        Specifies an ordered list of replica server names that represent the probe sequence for connection director to use when redirecting read-only connections through this availability replica. This parameter applies if the availability replica is the current primary replica of the availability group.

    .PARAMETER ProcessOnlyOnActiveNode
        Specifies that the resource will only determine if a change is needed if the target node is the active host of the SQL Server Instance.
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [System.String]
        $AvailabilityGroupName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter()]
        [System.String]
        $PrimaryReplicaServerName,

        [Parameter()]
        [System.String]
        $PrimaryReplicaInstanceName,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [ValidateSet('AsynchronousCommit', 'SynchronousCommit')]
        [System.String]
        $AvailabilityMode,

        [Parameter()]
        [ValidateRange(0, 100)]
        [System.UInt32]
        $BackupPriority,

        [Parameter()]
        [ValidateSet('AllowAllConnections', 'AllowReadWriteConnections')]
        [System.String]
        $ConnectionModeInPrimaryRole,

        [Parameter()]
        [ValidateSet('AllowNoConnections', 'AllowReadIntentConnectionsOnly', 'AllowAllConnections')]
        [System.String]
        $ConnectionModeInSecondaryRole,

        [Parameter()]
        [System.String]
        $EndpointHostName,

        [Parameter()]
        [ValidateSet('Automatic', 'Manual')]
        [System.String]
        $FailoverMode,

        [Parameter()]
        [System.String]
        $ReadOnlyRoutingConnectionUrl,

        [Parameter()]
        [System.String[]]
        $ReadOnlyRoutingList,

        [Parameter()]
        [System.Boolean]
        $ProcessOnlyOnActiveNode
    )

    $getTargetResourceParameters = @{
        InstanceName          = $InstanceName
        ServerName            = $ServerName
        Name                  = $Name
        AvailabilityGroupName = $AvailabilityGroupName
    }

    # Assume this will pass. We will determine otherwise later
    $result = $true

    $getTargetResourceResult = Get-TargetResource @getTargetResourceParameters

    <#
        If this is supposed to process only the active node, and this is not the
        active node, don't bother evaluating the test.
    #>
    if ( $ProcessOnlyOnActiveNode -and -not $getTargetResourceResult.IsActiveNode )
    {
        Write-Verbose -Message (
            $script:localizedData.NotActiveNode -f $env:COMPUTERNAME, $InstanceName
        )

        return $result
    }

    Write-Verbose -Message (
        $script:localizedData.TestingConfiguration -f $Name, $InstanceName
    )

    switch ($Ensure)
    {
        'Absent'
        {
            if ( $getTargetResourceResult.Ensure -eq 'Absent' )
            {
                $result = $true
            }
            else
            {
                $result = $false
            }
        }

        'Present'
        {
            $parametersToCheck = @(
                'Name',
                'AvailabilityGroupName',
                'ServerName',
                'InstanceName',
                'Ensure',
                'AvailabilityMode',
                'BackupPriority',
                'ConnectionModeInPrimaryRole',
                'ConnectionModeInSecondaryRole',
                'FailoverMode',
                'ReadOnlyRoutingConnectionUrl',
                'ReadOnlyRoutingList'
            )

            if ( $getTargetResourceResult.Ensure -eq 'Present' )
            {
                foreach ( $parameter in $PSBoundParameters.GetEnumerator() )
                {
                    $parameterName = $parameter.Key
                    $parameterValue = Get-Variable -Name $parameterName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Value

                    # Make sure we don't try to validate a common parameter
                    if ( $parametersToCheck -notcontains $parameterName )
                    {
                        continue
                    }

                    if ( $parameterName -eq 'ReadOnlyRoutingList' )
                    {
                        $different = ( $getTargetResourceResult.($parameterName) -join ',' ) -ne ( $parameterValue -join ',' )
                    }
                    else
                    {
                        $different = $getTargetResourceResult.($parameterName) -ne $parameterValue
                    }

                    if ( $different )
                    {
                        Write-Verbose -Message (
                            $script:localizedData.ParameterNotInDesiredState -f $parameterName, $parameterValue, $getTargetResourceResult.$parameterName
                        )

                        $result = $false
                    }
                }

                # Get the Endpoint URL properties
                $currentEndpointProtocol, $currentEndpointHostName, $currentEndpointPort = $getTargetResourceResult.EndpointUrl.Replace('//', '').Split(':')

                if ( -not $EndpointHostName )
                {
                    $EndpointHostName = $getTargetResourceResult.EndpointHostName
                }

                # Verify the hostname in the endpoint URL is correct
                if ( $EndpointHostName -ne $currentEndpointHostName )
                {
                    Write-Verbose -Message (
                        $script:localizedData.ParameterNotInDesiredState -f 'EndpointHostName', $EndpointHostName, $currentEndpointHostName
                    )

                    $result = $false
                }

                # Verify the protocol in the endpoint URL is correct
                if ( 'TCP' -ne $currentEndpointProtocol )
                {
                    Write-Verbose -Message (
                        $script:localizedData.ParameterNotInDesiredState -f 'EndpointProtocol', 'TCP', $currentEndpointProtocol
                    )

                    $result = $false
                }

                # Verify the port in the endpoint URL is correct
                if ( $getTargetResourceResult.EndpointPort -ne $currentEndpointPort )
                {
                    Write-Verbose -Message (
                        $script:localizedData.ParameterNotInDesiredState -f 'EndpointPort', $getTargetResourceResult.EndpointPort, $currentEndpointPort
                    )

                    $result = $false
                }
            }
            else
            {
                $result = $false
            }
        }
    }

    return $result
}

Export-ModuleMember -Function *-TargetResource
