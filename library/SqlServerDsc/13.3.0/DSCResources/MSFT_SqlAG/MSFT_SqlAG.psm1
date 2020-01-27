$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SqlServerDsc.Common'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SqlServerDsc.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_SqlAG'

<#
    .SYNOPSIS
        Gets the specified Availability Group.

    .PARAMETER Name
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
        $ServerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName
    )

    Write-Verbose -Message (
        $script:localizedData.GetAvailabilityGroup -f $Name, $InstanceName
    )

    # Connect to the instance
    $serverObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

    # Define current version for check compatibility
    $sqlMajorVersion = $serverObject.Version.Major

    # Get the endpoint properties
    $endpoint = $serverObject.Endpoints | Where-Object { $_.EndpointType -eq 'DatabaseMirroring' }
    if ( $endpoint )
    {
        $endpointPort = $endpoint.Protocol.Tcp.ListenerPort
    }

    # Get the Availability Group
    $availabilityGroup = $serverObject.AvailabilityGroups[$Name]

    # Is this node actively hosting the SQL instance?
    $isActiveNode = Test-ActiveNode -ServerObject $serverObject

    # Create the return object. Default ensure to Absent.
    $alwaysOnAvailabilityGroupResource = @{
        Name            = $Name
        ServerName      = $ServerName
        InstanceName = $InstanceName
        Ensure          = 'Absent'
        IsActiveNode    = $isActiveNode
    }

    if ( $availabilityGroup )
    {
        # Get all of the properties that can be set using this resource
        $alwaysOnAvailabilityGroupResource.Ensure = 'Present'
        $alwaysOnAvailabilityGroupResource.AutomatedBackupPreference = $availabilityGroup.AutomatedBackupPreference
        $alwaysOnAvailabilityGroupResource.AvailabilityMode = $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName].AvailabilityMode
        $alwaysOnAvailabilityGroupResource.BackupPriority = $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName].BackupPriority
        $alwaysOnAvailabilityGroupResource.ConnectionModeInPrimaryRole = $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName].ConnectionModeInPrimaryRole
        $alwaysOnAvailabilityGroupResource.ConnectionModeInSecondaryRole = $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName].ConnectionModeInSecondaryRole
        $alwaysOnAvailabilityGroupResource.FailureConditionLevel = $availabilityGroup.FailureConditionLevel
        $alwaysOnAvailabilityGroupResource.FailoverMode = $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName].FailoverMode
        $alwaysOnAvailabilityGroupResource.HealthCheckTimeout = $availabilityGroup.HealthCheckTimeout
        $alwaysOnAvailabilityGroupResource.EndpointURL = $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName].EndpointUrl
        $alwaysOnAvailabilityGroupResource.EndpointPort = $endpointPort
        $alwaysOnAvailabilityGroupResource.EndpointHostName = $serverObject.NetName
        $alwaysOnAvailabilityGroupResource.Version = $sqlMajorVersion

        # Add properties that are only present in SQL 2016 or newer
        if ( $sqlMajorVersion -ge 13 )
        {
            $alwaysOnAvailabilityGroupResource.Add('BasicAvailabilityGroup', $availabilityGroup.BasicAvailabilityGroup)
            $alwaysOnAvailabilityGroupResource.Add('DatabaseHealthTrigger', $availabilityGroup.DatabaseHealthTrigger)
            $alwaysOnAvailabilityGroupResource.Add('DtcSupportEnabled', $availabilityGroup.DtcSupportEnabled)
        }
    }

    return $alwaysOnAvailabilityGroupResource
}

<#
    .SYNOPSIS
        Creates or removes the availability group to in accordance with the desired state.

    .PARAMETER Name
        The name of the availability group.

    .PARAMETER ServerName
        Hostname of the SQL Server to be configured.

    .PARAMETER InstanceName
        Name of the SQL instance to be configured.

    .PARAMETER Ensure
        Specifies if the availability group should be present or absent. Default is Present.

    .PARAMETER AutomatedBackupPreference
        Specifies the automated backup preference for the availability group. When creating a group the default is 'None'.

    .PARAMETER AvailabilityMode
        Specifies the replica availability mode. When creating a group the default is 'AsynchronousCommit'.

    .PARAMETER BackupPriority
        Specifies the desired priority of the replicas in performing backups. The acceptable values for this parameter are integers from 0 through 100. Of the set of replicas which are online and available, the replica that has the highest priority performs the backup. When creating a group the efault is 50.

    .PARAMETER BasicAvailabilityGroup
        Specifies the type of availability group is Basic. This is only available is SQL Server 2016 and later and is ignored when applied to previous versions.

    .PARAMETER DatabaseHealthTrigger
        Specifies if the option Database Level Health Detection is enabled. This is only available is SQL Server 2016 and later and is ignored when applied to previous versions.

    .PARAMETER DtcSupportEnabled
        Specifies if the option Database DTC Support is enabled. This is only available is SQL Server 2016 and later and is ignored when applied to previous versions. This can't be altered once the Availability Group is created and is ignored if it is the case.

    .PARAMETER ConnectionModeInPrimaryRole
        Specifies how the availability replica handles connections when in the primary role.

    .PARAMETER ConnectionModeInSecondaryRole
        Specifies how the availability replica handles connections when in the secondary role.

    .PARAMETER EndpointHostName
        Specifies the hostname or IP address of the availability group replica endpoint. When creating a group the default is the instance network name.

    .PARAMETER FailureConditionLevel
        Specifies the automatic failover behavior of the availability group.

    .PARAMETER FailoverMode
        Specifies the failover mode. When creating a group the default is 'Manual'.

    .PARAMETER HealthCheckTimeout
        Specifies the length of time, in milliseconds, after which AlwaysOn availability groups declare an unresponsive server to be unhealthy. When creating a group the default is 30,000.

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
        $ServerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [ValidateSet('Primary', 'SecondaryOnly', 'Secondary', 'None')]
        [System.String]
        $AutomatedBackupPreference = 'None',

        [Parameter()]
        [ValidateSet('AsynchronousCommit', 'SynchronousCommit')]
        [System.String]
        $AvailabilityMode = 'AsynchronousCommit',

        [Parameter()]
        [ValidateRange(0, 100)]
        [System.UInt32]
        $BackupPriority = 50,

        [Parameter()]
        [System.Boolean]
        $BasicAvailabilityGroup,

        [Parameter()]
        [System.Boolean]
        $DatabaseHealthTrigger,

        [Parameter()]
        [System.Boolean]
        $DtcSupportEnabled,

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
        [ValidateSet(
            'OnServerDown',
            'OnServerUnresponsive',
            'OnCriticalServerErrors',
            'OnModerateServerErrors',
            'OnAnyQualifiedFailureCondition'
        )]
        [System.String]
        $FailureConditionLevel,

        [Parameter()]
        [ValidateSet('Automatic', 'Manual')]
        [System.String]
        $FailoverMode = 'Manual',

        [Parameter()]
        [System.UInt32]
        $HealthCheckTimeout = 30000,

        [Parameter()]
        [System.Boolean]
        $ProcessOnlyOnActiveNode
    )

    # Connect to the instance
    $serverObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

    # Determine if HADR is enabled on the instance. If not, throw an error
    if ( -not $serverObject.IsHadrEnabled )
    {
        $errorMessage = $script:localizedData.HadrNotEnabled
        New-InvalidOperationException -Message $errorMessage
    }

    # Define current version for check compatibility
    $sqlMajorVersion = $serverObject.Version.Major

    # Get the Availability Group if it exists
    $availabilityGroup = $serverObject.AvailabilityGroups[$Name]

    switch ($Ensure)
    {
        'Absent'
        {
            # If the AG exists
            if ( $availabilityGroup )
            {
                # If the primary replica is currently on this instance
                if ( $availabilityGroup.PrimaryReplicaServerName -eq $serverObject.DomainInstanceName )
                {
                    try
                    {
                        Write-Verbose -Message (
                            $script:localizedData.RemoveAvailabilityGroup -f $Name, $InstanceName
                        )

                        Remove-SqlAvailabilityGroup -InputObject $availabilityGroup -ErrorAction Stop
                    }
                    catch
                    {
                        $errorMessage = $script:localizedData.FailedRemoveAvailabilityGroup -f $availabilityGroup.Name, $InstanceName
                        New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
                    }
                }
                else
                {
                    $errorMessage = $script:localizedData.NotPrimaryReplica -f $serverObject.DomainInstanceName, $availabilityGroup.Name, $availabilityGroup.PrimaryReplicaServerName
                    New-InvalidOperationException -Message $errorMessage
                }
            }
        }

        'Present'
        {
            # Ensure the appropriate cluster permissions are present
            Test-ClusterPermissions -ServerObject $serverObject

            # Make sure a database mirroring endpoint exists.
            $endpoint = $serverObject.Endpoints | Where-Object { $_.EndpointType -eq 'DatabaseMirroring' }
            if ( -not $endpoint )
            {
                $errorMessage = $script:localizedData.DatabaseMirroringEndpointNotFound -f ('{0}\{1}' -f $ServerName, $InstanceName)
                New-ObjectNotFoundException -Message $errorMessage
            }

            # If the availability group does not exist, create it
            if ( -not $availabilityGroup )
            {
                if ( -not $EndpointHostName )
                {
                    $EndpointHostName = $serverObject.NetName
                }

                # Set up the parameters to create the AG Replica
                $newReplicaParams = @{
                    Name             = $serverObject.DomainInstanceName
                    Version          = $sqlMajorVersion
                    AsTemplate       = $true
                    AvailabilityMode = $AvailabilityMode
                    EndpointUrl      = "TCP://$($EndpointHostName):$($endpoint.Protocol.Tcp.ListenerPort)"
                    FailoverMode     = $FailoverMode
                }

                if ( $BackupPriority )
                {
                    $newReplicaParams.Add('BackupPriority', $BackupPriority)
                }

                if ( $ConnectionModeInPrimaryRole )
                {
                    $newReplicaParams.Add('ConnectionModeInPrimaryRole', $ConnectionModeInPrimaryRole)
                }

                if ( $ConnectionModeInSecondaryRole )
                {
                    $newReplicaParams.Add('ConnectionModeInSecondaryRole', $ConnectionModeInSecondaryRole)
                }

                # Create the new replica object
                try
                {
                    Write-Verbose -Message (
                        $script:localizedData.CreateAvailabilityGroupReplica -f $newReplicaParams.Name, $Name, $InstanceName
                    )

                    $primaryReplica = New-SqlAvailabilityReplica @newReplicaParams -ErrorAction Stop
                }
                catch
                {
                    $errorMessage = $script:localizedData.FailedCreateAvailabilityGroupReplica -f $newReplicaParams.Name, $InstanceName
                    New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
                }

                # Set up the parameters for the new availability group
                $newAvailabilityGroupParams = @{
                    InputObject         = $serverObject
                    Name                = $Name
                    AvailabilityReplica = $primaryReplica
                }

                if ( $AutomatedBackupPreference )
                {
                    $newAvailabilityGroupParams.Add('AutomatedBackupPreference', $AutomatedBackupPreference)
                }

                if ( $sqlMajorVersion -ge 13 )
                {
                    $newAvailabilityGroupParams.Add('BasicAvailabilityGroup', $BasicAvailabilityGroup)
                    $newAvailabilityGroupParams.Add('DatabaseHealthTrigger', $DatabaseHealthTrigger)
                    $newAvailabilityGroupParams.Add('DtcSupportEnabled', $DtcSupportEnabled)
                }

                if ( $FailureConditionLevel )
                {
                    $newAvailabilityGroupParams.Add('FailureConditionLevel', $FailureConditionLevel)
                }

                if ( $HealthCheckTimeout )
                {
                    $newAvailabilityGroupParams.Add('HealthCheckTimeout', $HealthCheckTimeout)
                }

                # Create the Availability Group
                try
                {
                    Write-Verbose -Message (
                        $script:localizedData.CreateAvailabilityGroup -f $Name, $InstanceName
                    )

                    New-SqlAvailabilityGroup @newAvailabilityGroupParams -ErrorAction Stop
                }
                catch
                {
                    $errorMessage = $script:localizedData.FailedCreateAvailabilityGroup -f $Name, $InstanceName
                    New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
                }
            }
            # Otherwise let's check each of the parameters passed and update the Availability Group accordingly
            else
            {
                Write-Verbose -Message (
                    $script:localizedData.UpdateAvailabilityGroup -f $Name, $InstanceName
                )

                # Get the parameters that were submitted to the function
                [System.Array] $submittedParameters = $PSBoundParameters.Keys

                # Make sure we're communicating with the primary replica
                $primaryServerObject = Get-PrimaryReplicaServerObject -ServerObject $serverObject -AvailabilityGroup $availabilityGroup
                $availabilityGroup = $primaryServerObject.AvailabilityGroups[$Name]

                if ( ( $submittedParameters -contains 'AutomatedBackupPreference' ) -and ( $AutomatedBackupPreference -ne $availabilityGroup.AutomatedBackupPreference ) )
                {
                    $availabilityGroup.AutomatedBackupPreference = $AutomatedBackupPreference
                    Update-AvailabilityGroup -AvailabilityGroup $availabilityGroup
                }

                if ( ( $submittedParameters -contains 'AvailabilityMode' ) -and ( $AvailabilityMode -ne $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName].AvailabilityMode ) )
                {
                    $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName].AvailabilityMode = $AvailabilityMode
                    Update-AvailabilityGroupReplica -AvailabilityGroupReplica $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName]
                }

                if ( ( $submittedParameters -contains 'BackupPriority' ) -and ( $BackupPriority -ne $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName].BackupPriority ) )
                {
                    $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName].BackupPriority = $BackupPriority
                    Update-AvailabilityGroupReplica -AvailabilityGroupReplica $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName]
                }

                if ( ( $submittedParameters -contains 'BasicAvailabilityGroup' ) -and ( $sqlMajorVersion -ge 13 ) -and ( $BasicAvailabilityGroup -ne $availabilityGroup.BasicAvailabilityGroup ) )
                {
                    $availabilityGroup.BasicAvailabilityGroup = $BasicAvailabilityGroup
                    Update-AvailabilityGroup -AvailabilityGroup $availabilityGroup
                }

                if ( ( $submittedParameters -contains 'DatabaseHealthTrigger' ) -and ( $sqlMajorVersion -ge 13 ) -and ( $DatabaseHealthTrigger -ne $availabilityGroup.DatabaseHealthTrigger ) )
                {
                    $availabilityGroup.DatabaseHealthTrigger = $DatabaseHealthTrigger
                    Update-AvailabilityGroup -AvailabilityGroup $availabilityGroup
                }

                # Make sure ConnectionModeInPrimaryRole has a value in order to avoid false positive matches when the parameter is not defined
                if ( ( $submittedParameters -contains 'ConnectionModeInPrimaryRole' ) -and ( -not [System.String]::IsNullOrEmpty($ConnectionModeInPrimaryRole) ) -and ( $ConnectionModeInPrimaryRole -ne $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName].ConnectionModeInPrimaryRole ) )
                {
                    $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName].ConnectionModeInPrimaryRole = $ConnectionModeInPrimaryRole
                    Update-AvailabilityGroupReplica -AvailabilityGroupReplica $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName]
                }

                # Make sure ConnectionModeInSecondaryRole has a value in order to avoid false positive matches when the parameter is not defined
                if ( ( $submittedParameters -contains 'ConnectionModeInSecondaryRole' ) -and ( -not [System.String]::IsNullOrEmpty($ConnectionModeInSecondaryRole) ) -and ( $ConnectionModeInSecondaryRole -ne $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName].ConnectionModeInSecondaryRole ) )
                {
                    $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName].ConnectionModeInSecondaryRole = $ConnectionModeInSecondaryRole
                    Update-AvailabilityGroupReplica -AvailabilityGroupReplica $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName]
                }

                # Break out the EndpointUrl properties
                $currentEndpointProtocol, $currentEndpointHostName, $currentEndpointPort = $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName].EndpointUrl.Replace('//', '').Split(':')

                if ( $endpoint.Protocol.Tcp.ListenerPort -ne $currentEndpointPort )
                {
                    $newEndpointUrl = $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName].EndpointUrl.Replace($currentEndpointPort, $endpoint.Protocol.Tcp.ListenerPort)
                    $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName].EndpointUrl = $newEndpointUrl
                    Update-AvailabilityGroupReplica -AvailabilityGroupReplica $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName]
                }

                if ( ( $submittedParameters -contains 'EndpointHostName' ) -and ( $EndpointHostName -ne $currentEndpointHostName ) )
                {
                    $newEndpointUrl = $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName].EndpointUrl.Replace($currentEndpointHostName, $EndpointHostName)
                    $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName].EndpointUrl = $newEndpointUrl
                    Update-AvailabilityGroupReplica -AvailabilityGroupReplica $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName]
                }

                if ( $currentEndpointProtocol -ne 'TCP' )
                {
                    $newEndpointUrl = $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName].EndpointUrl.Replace($currentEndpointProtocol, 'TCP')
                    $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName].EndpointUrl = $newEndpointUrl
                    Update-AvailabilityGroupReplica -AvailabilityGroupReplica $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName]
                }

                # Make sure FailureConditionLevel has a value in order to avoid false positive matches when the parameter is not defined
                if ( ( $submittedParameters -contains 'FailureConditionLevel' ) -and ( -not [System.String]::IsNullOrEmpty($FailureConditionLevel) ) -and ( $FailureConditionLevel -ne $availabilityGroup.FailureConditionLevel ) )
                {
                    $availabilityGroup.FailureConditionLevel = $FailureConditionLevel
                    Update-AvailabilityGroup -AvailabilityGroup $availabilityGroup
                }

                if ( ( $submittedParameters -contains 'FailoverMode' ) -and ( $FailoverMode -ne $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName].FailoverMode ) )
                {
                    $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName].FailoverMode = $FailoverMode
                    Update-AvailabilityGroupReplica -AvailabilityGroupReplica $availabilityGroup.AvailabilityReplicas[$serverObject.DomainInstanceName]
                }

                if ( ( $submittedParameters -contains 'HealthCheckTimeout' ) -and ( $HealthCheckTimeout -ne $availabilityGroup.HealthCheckTimeout ) )
                {
                    $availabilityGroup.HealthCheckTimeout = $HealthCheckTimeout
                    Update-AvailabilityGroup -AvailabilityGroup $availabilityGroup
                }
            }
        }
    }
}

<#
    .SYNOPSIS
        Determines if the availability group is in the desired state.

    .PARAMETER Name
        The name of the availability group.

    .PARAMETER ServerName
        Hostname of the SQL Server to be configured.

    .PARAMETER InstanceName
        Name of the SQL instance to be configured.

    .PARAMETER Ensure
        Specifies if the availability group should be present or absent. Default is Present.

    .PARAMETER AutomatedBackupPreference
        Specifies the automated backup preference for the availability group. When creating a group the default is 'None'.

    .PARAMETER AvailabilityMode
        Specifies the replica availability mode. When creating a group the default is 'AsynchronousCommit'.

    .PARAMETER BackupPriority
        Specifies the desired priority of the replicas in performing backups. The acceptable values for this parameter are integers from 0 through 100. Of the set of replicas which are online and available, the replica that has the highest priority performs the backup. When creating a group the default is 50.

    .PARAMETER BasicAvailabilityGroup
        Specifies the type of availability group is Basic. This is only available is SQL Server 2016 and later and is ignored when applied to previous versions.

    .PARAMETER DatabaseHealthTrigger
        Specifies if the option Database Level Health Detection is enabled. This is only available is SQL Server 2016 and later and is ignored when applied to previous versions.

    .PARAMETER DtcSupportEnabled
        Specifies if the option Database DTC Support is enabled. This is only available is SQL Server 2016 and later and is ignored when applied to previous versions.

    .PARAMETER ConnectionModeInPrimaryRole
        Specifies how the availability replica handles connections when in the primary role.

    .PARAMETER ConnectionModeInSecondaryRole
        Specifies how the availability replica handles connections when in the secondary role.

    .PARAMETER EndpointHostName
        Specifies the hostname or IP address of the availability group replica endpoint. When creating a group the default is the instance network name.

    .PARAMETER FailureConditionLevel
        Specifies the automatic failover behavior of the availability group.

    .PARAMETER FailoverMode
        Specifies the failover mode. When creating a group the default is 'Manual'.

    .PARAMETER HealthCheckTimeout
        Specifies the length of time, in milliseconds, after which AlwaysOn availability groups declare an unresponsive server to be unhealthy. When creating a group the default is 30,000.

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
        $ServerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [ValidateSet('Primary', 'SecondaryOnly', 'Secondary', 'None')]
        [System.String]
        $AutomatedBackupPreference = 'None',

        [Parameter()]
        [ValidateSet('AsynchronousCommit', 'SynchronousCommit')]
        [System.String]
        $AvailabilityMode = 'AsynchronousCommit',

        [Parameter()]
        [ValidateRange(0, 100)]
        [System.UInt32]
        $BackupPriority = 50,

        [Parameter()]
        [System.Boolean]
        $BasicAvailabilityGroup,

        [Parameter()]
        [System.Boolean]
        $DatabaseHealthTrigger,

        [Parameter()]
        [System.Boolean]
        $DtcSupportEnabled,

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
        [ValidateSet('OnServerDown', 'OnServerUnresponsive', 'OnCriticalServerErrors', 'OnModerateServerErrors', 'OnAnyQualifiedFailureCondition')]
        [System.String]
        $FailureConditionLevel,

        [Parameter()]
        [ValidateSet('Automatic', 'Manual')]
        [System.String]
        $FailoverMode = 'Manual',

        [Parameter()]
        [System.UInt32]
        $HealthCheckTimeout = 30000,

        [Parameter()]
        [System.Boolean]
        $ProcessOnlyOnActiveNode
    )

    $getTargetResourceParameters = @{
        InstanceName = $InstanceName
        ServerName      = $ServerName
        Name            = $Name
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

    # Define current version for check compatibility
    $sqlMajorVersion = $getTargetResourceResult.Version

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
                'ServerName',
                'InstanceName',
                'Ensure',
                'AutomatedBackupPreference',
                'AvailabilityMode',
                'BackupPriority',
                'ConnectionModeInPrimaryRole',
                'ConnectionModeInSecondaryRole',
                'FailureConditionLevel',
                'FailoverMode',
                'HealthCheckTimeout'
            )

            <#
                Add properties compatible with SQL Server 2016 or later versions
                DtcSupportEnabled is enabled at the creation of the Availability Group only, hence it will not be checked in this block
            #>
            if ( $sqlMajorVersion -ge 13 )
            {
                $parametersToCheck += 'BasicAvailabilityGroup'
                $parametersToCheck += 'DatabaseHealthTrigger'
            }

            if ( $getTargetResourceResult.Ensure -eq 'Present' )
            {
                # Use $PSBoundParameters rather than $MyInvocation.MyCommand.Parameters.GetEnumerator()
                # This allows us to only validate the supplied parameters
                # If the parameter is not defined by the configuration, we don't care what
                # it gets set to.
                foreach ( $parameter in $PSBoundParameters.GetEnumerator() )
                {
                    $parameterName = $parameter.Key
                    $parameterValue = Get-Variable -Name $parameterName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Value

                    # Make sure we don't try to validate a common parameter
                    if ( $parametersToCheck -notcontains $parameterName )
                    {
                        continue
                    }

                    if ( $getTargetResourceResult.($parameterName) -ne $parameterValue )
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

<#
    .SYNOPSIS
        Executes the alter method on an Availability Group object.

    .PARAMETER AvailabilityGroup
        The Availability Group object that must be altered.
#>
function Update-AvailabilityGroup
{
    param
    (
        [Parameter(Mandatory = $true)]
        [Microsoft.SqlServer.Management.Smo.AvailabilityGroup]
        $AvailabilityGroup
    )

    try
    {
        $originalErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'
        $AvailabilityGroup.Alter()
    }
    catch
    {
        $errorMessage = $script:localizedData.FailedAlterAvailabilityGroup -f $AvailabilityGroup.Name
        New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
    }
    finally
    {
        $ErrorActionPreference = $originalErrorActionPreference
    }
}

Export-ModuleMember -Function *-TargetResource
