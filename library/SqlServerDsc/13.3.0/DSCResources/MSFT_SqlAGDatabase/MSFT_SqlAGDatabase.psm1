$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SqlServerDsc.Common'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SqlServerDsc.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_SqlAGDatabase'

<#
    .SYNOPSIS
        Gets the database membership of the specified availability group.

    .PARAMETER DatabaseName
        The name of the database(s) to add to the availability group. This accepts wildcards.

    .PARAMETER ServerName
        Hostname of the SQL Server where the primary replica of the availability group lives. If the
        availability group is not currently on this server, the resource will attempt to connect to the
        server where the primary replica lives.

    .PARAMETER InstanceName
        Name of the SQL instance where the primary replica of the availability group lives. If the
        availability group is not currently on this instance, the resource will attempt to connect to
        the instance where the primary replica lives.

    .PARAMETER AvailabilityGroupName
        The name of the availability group in which to manage the database membership(s).

    .PARAMETER BackupPath
        The path used to seed the availability group replicas. This should be a path that is accessible
        by all of the replicas.
#>
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String[]]
        $DatabaseName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $AvailabilityGroupName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $BackupPath
    )

    # Create an object that reflects the current configuration
    $currentConfiguration = @{
        DatabaseName          = @()
        ServerName            = $ServerName
        InstanceName          = $InstanceName
        AvailabilityGroupName = ''
        BackupPath            = ''
        Ensure                = ''
        Force                 = $false
        MatchDatabaseOwner    = $false
        ReplaceExisting       = $false
        IsActiveNode          = $false
    }

    # Connect to the instance
    $serverObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

    # Is this node actively hosting the SQL instance?
    $currentConfiguration.IsActiveNode = Test-ActiveNode -ServerObject $serverObject

    # Get the Availability group object
    $availabilityGroup = $serverObject.AvailabilityGroups[$AvailabilityGroupName]

    if ( $availabilityGroup )
    {
        $currentConfiguration.AvailabilityGroupName = $AvailabilityGroupName

        # Get the databases in the availability group
        $currentConfiguration.DatabaseName = [string[]] ($availabilityGroup.AvailabilityDatabases | Select-Object -ExpandProperty Name)
    }
    else
    {
        Write-Verbose -Message ($script:localizedData.AvailabilityGroupDoesNotExist -f $AvailabilityGroupName)
    }

    return $currentConfiguration
}

<#
    .SYNOPSIS
        Adds or removes databases to the specified availability group.

    .PARAMETER DatabaseName
        The name of the database(s) to add to the availability group. This accepts wildcards.

    .PARAMETER ServerName
        Hostname of the SQL Server where the primary replica of the availability group lives. If the
        availability group is not currently on this server, the resource will attempt to connect to the
        server where the primary replica lives.

    .PARAMETER InstanceName
        Name of the SQL instance where the primary replica of the availability group lives. If the
        availability group is not currently on this instance, the resource will attempt to connect to
        the instance where the primary replica lives.

    .PARAMETER AvailabilityGroupName
        The name of the availability group in which to manage the database membership(s).

    .PARAMETER BackupPath
        The path used to seed the availability group replicas. This should be a path that is accessible
        by all of the replicas.

    .PARAMETER Ensure
        Specifies the membership of the database(s) in the availability group. The options are:

            - Present:  The defined database(s) are added to the availability group. All other
                        databases that may be a member of the availability group are ignored.
            - Absent:   The defined database(s) are removed from the availability group. All other
                        databases that may be a member of the availability group are ignored.

        The default is 'Present'.

    .PARAMETER Force
        When used with "Ensure = 'Present'" it ensures the specified database(s) are the only databases
        that are a member of the specified Availability Group.

        This parameter is ignored when 'Ensure' is 'Absent'.

    .PARAMETER MatchDatabaseOwner
        If set to $true, this ensures the database owner of the database on the primary replica is the
        owner of the database on all secondary replicas. This requires the database owner is available
        as a login on all replicas and that the PsDscRunAsCredential has impersonate any login, control
        server, impersonate login, or control login permissions.

        If set to $false, the owner of the database will be the PsDscRunAsCredential.

        The default is '$false'.

    .PARAMETER ReplaceExisting
        If set to $true, this adds the restore option WITH REPLACE.
        If set to $false, Existing databases and files will block the restore and throw error.
        The default is '$false'.

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
        [System.String[]]
        $DatabaseName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $AvailabilityGroupName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $BackupPath,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.Boolean]
        $Force,

        [Parameter()]
        [System.Boolean]
        $MatchDatabaseOwner,

        [Parameter()]
        [System.Boolean]
        $ReplaceExisting,

        [Parameter()]
        [System.Boolean]
        $ProcessOnlyOnActiveNode
    )

    Import-SQLPSModule

    # Connect to the defined instance
    $serverObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

    # Get the Availability Group
    $availabilityGroup = $serverObject.AvailabilityGroups[$AvailabilityGroupName]

    # Make sure we're communicating with the primary replica in order to make changes to the replica
    $primaryServerObject = Get-PrimaryReplicaServerObject -ServerObject $serverObject -AvailabilityGroup $availabilityGroup

    $getDatabasesToAddToAvailabilityGroupParameters = @{
        DatabaseName      = $DatabaseName
        Ensure            = $Ensure
        ServerObject      = $primaryServerObject
        AvailabilityGroup = $availabilityGroup
    }
    $databasesToAddToAvailabilityGroup = Get-DatabasesToAddToAvailabilityGroup @getDatabasesToAddToAvailabilityGroupParameters

    $getDatabasesToRemoveFromAvailabilityGroupParameters = @{
        DatabaseName      = $DatabaseName
        Ensure            = $Ensure
        Force             = $Force
        ServerObject      = $primaryServerObject
        AvailabilityGroup = $availabilityGroup
    }
    $databasesToRemoveFromAvailabilityGroup = Get-DatabasesToRemoveFromAvailabilityGroup @getDatabasesToRemoveFromAvailabilityGroupParameters

    # Create a hash table to store the databases that failed to be added to the Availability Group
    $databasesToAddFailures = @{}

    # Create a hash table to store the databases that failed to be added to the Availability Group
    $databasesToRemoveFailures = @{}

    if ( $databasesToAddToAvailabilityGroup.Count -gt 0 )
    {
        Write-Verbose -Message ($script:localizedData.AddingDatabasesToAvailabilityGroup -f $AvailabilityGroupName, ( $databasesToAddToAvailabilityGroup -join ', ' ))

        # Get only the secondary replicas. Some tests do not need to be performed on the primary replica
        $secondaryReplicas = $availabilityGroup.AvailabilityReplicas | Where-Object -FilterScript { $_.Role -ne 'Primary' }

        foreach ( $databaseToAddToAvailabilityGroup in $databasesToAddToAvailabilityGroup )
        {
            $databaseObject = $primaryServerObject.Databases[$databaseToAddToAvailabilityGroup]

            # Ensure the appropriate permissions are in place on all the replicas
            if ( $MatchDatabaseOwner )
            {
                $impersonatePermissionsStatus = @{}

                foreach ( $availabilityGroupReplica in $secondaryReplicas )
                {
                    $currentAvailabilityGroupReplicaServerObject = Connect-SQL -ServerName $availabilityGroupReplica.Name
                    $impersonatePermissionsStatus.Add(
                        $availabilityGroupReplica.Name,
                        ( Test-ImpersonatePermissions -ServerObject $currentAvailabilityGroupReplicaServerObject -Securable $databaseObject.Owner )
                    )
                }

                if ( $impersonatePermissionsStatus.Values -contains $false )
                {
                    $impersonatePermissionsMissingParameters = @(
                        [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
                        ( ( $impersonatePermissionsStatus.GetEnumerator() | Where-Object -FilterScript { -not $_.Value } | Select-Object -ExpandProperty Key ) -join ', ' )
                    )
                    throw ($script:localizedData.ImpersonatePermissionsMissing -f $impersonatePermissionsMissingParameters )
                }
            }
        }

        foreach ( $databaseToAddToAvailabilityGroup in $databasesToAddToAvailabilityGroup )
        {
            $databaseObject = $primaryServerObject.Databases[$databaseToAddToAvailabilityGroup]

            <#
                Verify the prerequisites prior to joining the database to the availability group
                https://docs.microsoft.com/en-us/sql/database-engine/availability-groups/windows/prereqs-restrictions-recommendations-always-on-availability#a-nameprerequisitesfordbsa-availability-database-prerequisites-and-restrictions
            #>

            # Create a hash table to store prerequisite check failures
            $prerequisiteCheckFailures = @()

            $prerequisiteChecks = @{
                RecoveryModel         = 'Full'
                ReadOnly              = $false
                UserAccess            = 'Multiple'
                AutoClose             = $false
                AvailabilityGroupName = ''
                IsMirroringEnabled    = $false
            }

            foreach ( $prerequisiteCheck in $prerequisiteChecks.GetEnumerator() )
            {
                if ( $databaseObject.($prerequisiteCheck.Key) -ne $prerequisiteCheck.Value )
                {
                    $prerequisiteCheckFailures += "$($prerequisiteCheck.Key) is not $($prerequisiteCheck.Value)."
                }
            }

            # Cannot be a system database
            if ( $databaseObject.ID -le 4 )
            {
                $prerequisiteCheckFailures += 'The database cannot be a system database.'
            }

            # If FILESTREAM is enabled, ensure FILESTREAM is enabled on all replica instances
            if (
                ( -not [System.String]::IsNullOrEmpty($databaseObject.DefaultFileStreamFileGroup) ) `
                    -or ( -not [System.String]::IsNullOrEmpty($databaseObject.FilestreamDirectoryName) ) `
                    -or ( $databaseObject.FilestreamNonTransactedAccess -ne 'Off' )
            )
            {
                $availabilityReplicaFilestreamLevel = @{}
                foreach ( $availabilityGroupReplica in $secondaryReplicas )
                {
                    $connectSqlParameters = Split-FullSqlInstanceName -FullSqlInstanceName $availabilityGroupReplica.Name
                    $currentAvailabilityGroupReplicaServerObject = Connect-SQL @connectSqlParameters
                    $availabilityReplicaFilestreamLevel.Add($availabilityGroupReplica.Name, $currentAvailabilityGroupReplicaServerObject.FilestreamLevel)
                }

                if ( $availabilityReplicaFilestreamLevel.Values -contains 'Disabled' )
                {
                    $availabilityReplicaFilestreamLevelDisabled = $availabilityReplicaFilestreamLevel.GetEnumerator() | Where-Object { $_.Value -eq 'Disabled' } | Select-Object -ExpandProperty Key
                    $prerequisiteCheckFailures += ( 'Filestream is disabled on the following instances: {0}' -f ( $availabilityReplicaFilestreamLevelDisabled -join ', ' ) )
                }
            }

            # If the database is contained, ensure contained database authentication is enabled on all replica instances
            if ( $databaseObject.ContainmentType -ne 'None' )
            {
                $availabilityReplicaContainmentEnabled = @{}
                foreach ( $availabilityGroupReplica in $secondaryReplicas )
                {
                    $connectSqlParameters = Split-FullSqlInstanceName -FullSqlInstanceName $availabilityGroupReplica.Name
                    $currentAvailabilityGroupReplicaServerObject = Connect-SQL @connectSqlParameters
                    $availabilityReplicaContainmentEnabled.Add($availabilityGroupReplica.Name, $currentAvailabilityGroupReplicaServerObject.Configuration.ContainmentEnabled.ConfigValue)
                }

                if ( $availabilityReplicaContainmentEnabled.Values -notcontains 'None' )
                {
                    $availabilityReplicaContainmentNotEnabled = $availabilityReplicaContainmentEnabled.GetEnumerator() | Where-Object { $_.Value -eq 'None' } | Select-Object -ExpandProperty Key
                    $prerequisiteCheckFailures += ( 'Contained Database Authentication is not enabled on the following instances: {0}' -f ( $availabilityReplicaContainmentNotEnabled -join ', ' ) )
                }
            }

            # Ensure the data and log file paths exist on all replicas
            $databaseFileDirectories = @()
            $databaseFileDirectories += $databaseObject.FileGroups.Files.FileName | ForEach-Object { Split-Path -Path $_ -Parent }
            $databaseFileDirectories += $databaseObject.LogFiles.FileName | ForEach-Object { Split-Path -Path $_ -Parent }
            $databaseFileDirectories = $databaseFileDirectories | Select-Object -Unique

            $availabilityReplicaMissingDirectories = @{}
            foreach ( $availabilityGroupReplica in $secondaryReplicas )
            {
                $connectSqlParameters = Split-FullSqlInstanceName -FullSqlInstanceName $availabilityGroupReplica.Name
                $currentAvailabilityGroupReplicaServerObject = Connect-SQL @connectSqlParameters

                $missingDirectories = @()
                foreach ( $databaseFileDirectory in $databaseFileDirectories )
                {
                    $fileExistsQuery = "EXEC master.dbo.xp_fileexist '$databaseFileDirectory'"
                    $fileExistsResult = Invoke-Query -ServerName $currentAvailabilityGroupReplicaServerObject.NetName -InstanceName $currentAvailabilityGroupReplicaServerObject.ServiceName -Database master -Query $fileExistsQuery -WithResults

                    if ( $fileExistsResult.Tables.Rows.'File is a Directory' -ne 1 )
                    {
                        $missingDirectories += $databaseFileDirectory
                    }
                }

                if ( $missingDirectories.Count -gt 0 )
                {
                    $availabilityReplicaMissingDirectories.Add($availabilityGroupReplica, ( $missingDirectories -join ', ' ))
                }
            }

            if ( $availabilityReplicaMissingDirectories.Count -gt 0 )
            {
                foreach ( $availabilityReplicaMissingDirectory in $availabilityReplicaMissingDirectories.GetEnumerator() )
                {
                    $prerequisiteCheckFailures += "The instance '$($availabilityReplicaMissingDirectory.Key.Name)' is missing the following directories: $($availabilityReplicaMissingDirectory.Value)"
                }
            }

            # If the database is TDE'd, ensure the certificate or asymmetric key is installed on all replicas
            if ( $databaseObject.EncryptionEnabled )
            {
                $databaseCertificateThumbprint = [System.BitConverter]::ToString($databaseObject.DatabaseEncryptionKey.Thumbprint)
                $databaseCertificateName = $databaseObject.DatabaseEncryptionKey.EncryptorName

                $availabilityReplicaMissingCertificates = @{}
                foreach ( $availabilityGroupReplica in $secondaryReplicas )
                {
                    $connectSqlParameters = Split-FullSqlInstanceName -FullSqlInstanceName $availabilityGroupReplica.Name
                    $currentAvailabilityGroupReplicaServerObject = Connect-SQL @connectSqlParameters
                    [System.Array]$installedCertificateThumbprints = $currentAvailabilityGroupReplicaServerObject.Databases['master'].Certificates | ForEach-Object { [System.BitConverter]::ToString($_.Thumbprint) }

                    if ( $installedCertificateThumbprints -notcontains $databaseCertificateThumbprint )
                    {
                        $availabilityReplicaMissingCertificates.Add($availabilityGroupReplica, $databaseCertificateName)
                    }
                }

                if ( $availabilityReplicaMissingCertificates.Count -gt 0 )
                {
                    foreach ( $availabilityReplicaMissingCertificate in $availabilityReplicaMissingCertificates.GetEnumerator() )
                    {
                        $prerequisiteCheckFailures += "The instance '$($availabilityReplicaMissingCertificate.Key.Name)' is missing the following certificates: $($availabilityReplicaMissingCertificate.Value)"
                    }
                }
            }

            if ( $prerequisiteCheckFailures.Count -eq 0 )
            {
                $databaseFullBackupFile = Join-Path -Path $BackupPath -ChildPath "$($databaseObject.Name)_Full_$(Get-Date -Format 'yyyyMMddhhmmss').bak"
                $databaseLogBackupFile = Join-Path -Path $BackupPath -ChildPath "$($databaseObject.Name)_Log_$(Get-Date -Format 'yyyyMMddhhmmss').trn"

                # Build the backup parameters. If no backup was previously taken, a standard full will be taken. Otherwise a CopyOnly backup will be taken.
                $backupSqlDatabaseParameters = @{
                    DatabaseObject = $databaseObject
                    BackupAction   = 'Database'
                    BackupFile     = $databaseFullBackupFile
                    ErrorAction    = 'Stop'
                }

                # If database object last backup data not equal to 0 then backup with CopyOnly.
                if ( $databaseObject.LastBackupDate -ne 0 )
                {
                    $backupSqlDatabaseParameters.Add('CopyOnly', $true)
                }

                try
                {
                    Backup-SqlDatabase @backupSqlDatabaseParameters
                }
                catch
                {
                    # Log the failure
                    $databasesToAddFailures.Add($databaseToAddToAvailabilityGroup, $_.Exception)

                    # Move on to the next database
                    continue
                }

                # Create the parameters to perform a transaction log backup
                $backupSqlDatabaseLogParams = @{
                    DatabaseObject = $databaseObject
                    BackupAction   = 'Log'
                    BackupFile     = $databaseLogBackupFile
                    ErrorAction    = 'Stop'
                }

                try
                {
                    Backup-SqlDatabase @backupSqlDatabaseLogParams
                }
                catch
                {
                    # Log the failure
                    $databasesToAddFailures.Add($databaseToAddToAvailabilityGroup, $_.Exception)

                    # Move on to the next database
                    continue
                }

                # Add the database to the availability group on the primary instance
                try
                {
                    Add-SqlAvailabilityDatabase -InputObject $availabilityGroup -Database $databaseToAddToAvailabilityGroup
                }
                catch
                {
                    # Log the failure
                    $databasesToAddFailures.Add($databaseToAddToAvailabilityGroup, $_.Exception)

                    # Move on to the next database
                    continue
                }

                # Need to restore the database with a query in order to impersonate the correct login
                $restoreDatabaseQueryStringBuilder = New-Object -TypeName System.Text.StringBuilder

                if ( $MatchDatabaseOwner )
                {
                    $restoreDatabaseQueryStringBuilder.Append('EXECUTE AS LOGIN = ''') | Out-Null
                    $restoreDatabaseQueryStringBuilder.Append($databaseObject.Owner) | Out-Null
                    $restoreDatabaseQueryStringBuilder.AppendLine('''') | Out-Null
                }

                $restoreDatabaseQueryStringBuilder.Append('RESTORE DATABASE [') | Out-Null
                $restoreDatabaseQueryStringBuilder.Append($databaseToAddToAvailabilityGroup) | Out-Null
                $restoreDatabaseQueryStringBuilder.AppendLine(']') | Out-Null
                $restoreDatabaseQueryStringBuilder.Append('FROM DISK = ''') | Out-Null
                $restoreDatabaseQueryStringBuilder.Append($databaseFullBackupFile) | Out-Null
                $restoreDatabaseQueryStringBuilder.AppendLine('''') | Out-Null
                $restoreDatabaseQueryStringBuilder.Append('WITH NORECOVERY') | Out-Null

                if ( $ReplaceExisting )
                {
                    $restoreDatabaseQueryStringBuilder.Append(',REPLACE') | Out-Null
                }

                if ( $MatchDatabaseOwner )
                {
                    $restoreDatabaseQueryStringBuilder.AppendLine() | Out-Null
                    $restoreDatabaseQueryStringBuilder.Append('REVERT') | Out-Null
                }
                $restoreDatabaseQueryString = $restoreDatabaseQueryStringBuilder.ToString()

                # Need to restore the database with a query in order to impersonate the correct login
                $restoreLogQueryStringBuilder = New-Object -TypeName System.Text.StringBuilder

                if ( $MatchDatabaseOwner )
                {
                    $restoreLogQueryStringBuilder.Append('EXECUTE AS LOGIN = ''') | Out-Null
                    $restoreLogQueryStringBuilder.Append($databaseObject.Owner) | Out-Null
                    $restoreLogQueryStringBuilder.AppendLine('''') | Out-Null
                }

                $restoreLogQueryStringBuilder.Append('RESTORE DATABASE [') | Out-Null
                $restoreLogQueryStringBuilder.Append($databaseToAddToAvailabilityGroup) | Out-Null
                $restoreLogQueryStringBuilder.AppendLine(']') | Out-Null
                $restoreLogQueryStringBuilder.Append('FROM DISK = ''') | Out-Null
                $restoreLogQueryStringBuilder.Append($databaseLogBackupFile) | Out-Null
                $restoreLogQueryStringBuilder.AppendLine('''') | Out-Null
                $restoreLogQueryStringBuilder.Append('WITH NORECOVERY') | Out-Null

                if ( $MatchDatabaseOwner )
                {
                    $restoreLogQueryStringBuilder.AppendLine() | Out-Null
                    $restoreLogQueryStringBuilder.Append('REVERT') | Out-Null
                }

                $restoreLogQueryString = $restoreLogQueryStringBuilder.ToString()

                try
                {
                    foreach ( $availabilityGroupReplica in $secondaryReplicas )
                    {
                        # Connect to the replica
                        $connectSqlParameters = Split-FullSqlInstanceName -FullSqlInstanceName $availabilityGroupReplica.Name
                        $currentAvailabilityGroupReplicaServerObject = Connect-SQL @connectSqlParameters
                        $currentReplicaAvailabilityGroupObject = $currentAvailabilityGroupReplicaServerObject.AvailabilityGroups[$AvailabilityGroupName]

                        # Restore the database
                        Invoke-Query -ServerName $currentAvailabilityGroupReplicaServerObject.NetName -InstanceName $currentAvailabilityGroupReplicaServerObject.ServiceName -Database master -Query $restoreDatabaseQueryString -StatementTimeout 0
                        Invoke-Query -ServerName $currentAvailabilityGroupReplicaServerObject.NetName -InstanceName $currentAvailabilityGroupReplicaServerObject.ServiceName -Database master -Query $restoreLogQueryString -StatementTimeout 0

                        # Add the database to the Availability Group
                        Add-SqlAvailabilityDatabase -InputObject $currentReplicaAvailabilityGroupObject -Database $databaseToAddToAvailabilityGroup
                    }
                }
                catch
                {
                    # Log the failure
                    $databasesToAddFailures.Add($databaseToAddToAvailabilityGroup, $_.Exception)

                    # Move on to the next database
                    continue
                }
                finally
                {
                    # Clean up the backup files
                    Remove-Item -Path $databaseFullBackupFile, $databaseLogBackupFile -Force -ErrorAction Continue
                }
            }
            else
            {
                $databasesToAddFailures.Add($databaseToAddToAvailabilityGroup, "The following prerequisite checks failed: $( $prerequisiteCheckFailures -join "`r`n" )" )
            }
        }
    }

    if ( $databasesToRemoveFromAvailabilityGroup.Count -gt 0 )
    {
        Write-Verbose -Message ($script:localizedData.RemovingDatabasesToAvailabilityGroup -f $AvailabilityGroupName, ( $databasesToRemoveFromAvailabilityGroup -join ', ' ))

        foreach ( $databaseToAddToAvailabilityGroup in $databasesToRemoveFromAvailabilityGroup )
        {
            $availabilityDatabase = $primaryServerObject.AvailabilityGroups[$AvailabilityGroupName].AvailabilityDatabases[$databaseToAddToAvailabilityGroup]

            try
            {
                Remove-SqlAvailabilityDatabase -InputObject $availabilityDatabase -ErrorAction Stop
            }
            catch
            {
                $databasesToRemoveFailures.Add($databaseToAddToAvailabilityGroup, 'Failed to remove the database from the availability group.')
            }
        }
    }

    # Combine the failures into one error message and throw it here. Doing this will allow all the databases that can be processes to be processed and will still show that applying the configuration failed
    if ( ( $databasesToAddFailures.Count -gt 0 ) -or ( $databasesToRemoveFailures.Count -gt 0 ) )
    {
        $formatArgs = @()
        foreach ( $failure in ( $databasesToAddFailures.GetEnumerator() + $databasesToRemoveFailures.GetEnumerator() ) )
        {
            $formatArgs += "The operation on the database '$( $failure.Key )' failed with the following errors: $( $failure.Value -join "`r`n" )"
        }

        throw ($script:localizedData.AlterAvailabilityGroupDatabaseMembershipFailure -f $formatArgs )
    }
}

<#
    .SYNOPSIS
        Tests the database membership of the specified Availability Group.

    .PARAMETER DatabaseName
        The name of the database(s) to add to the availability group. This accepts wildcards.

    .PARAMETER ServerName
        Hostname of the SQL Server where the primary replica of the availability group lives. If the
        availability group is not currently on this server, the resource will attempt to connect to the
        server where the primary replica lives.

    .PARAMETER InstanceName
        Name of the SQL instance where the primary replica of the availability group lives. If the
        availability group is not currently on this instance, the resource will attempt to connect to
        the instance where the primary replica lives.

    .PARAMETER AvailabilityGroupName
        The name of the availability group in which to manage the database membership(s).

    .PARAMETER BackupPath
        The path used to seed the availability group replicas. This should be a path that is accessible
        by all of the replicas.

    .PARAMETER Ensure
        Specifies the membership of the database(s) in the availability group. The options are:

            - Present:  The defined database(s) are added to the availability group. All other
                        databases that may be a member of the availability group are ignored.
            - Absent:   The defined database(s) are removed from the availability group. All other
                        databases that may be a member of the availability group are ignored.

        The default is 'Present'.

    .PARAMETER Force
        When used with "Ensure = 'Present'" it ensures the specified database(s) are the only databases
        that are a member of the specified Availability Group.

        This parameter is ignored when 'Ensure' is 'Absent'.

    .PARAMETER MatchDatabaseOwner
        If set to $true, this ensures the database owner of the database on the primary replica is the
        owner of the database on all secondary replicas. This requires the database owner is available
        as a login on all replicas and that the PsDscRunAsCredential has impersonate any login, control
        server, impersonate login, or control login permissions.

        If set to $false, the owner of the database will be the PsDscRunAsCredential.

        The default is '$false'.

    .PARAMETER ReplaceExisting
        If set to $true, this adds the restore option WITH REPLACE.
        If set to $false, Existing databases and files will block the restore and throw error.
        The default is '$false'.

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
        [System.String[]]
        $DatabaseName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $AvailabilityGroupName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $BackupPath,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.Boolean]
        $Force,

        [Parameter()]
        [System.Boolean]
        $MatchDatabaseOwner,

        [Parameter()]
        [System.Boolean]
        $ReplaceExisting,

        [Parameter()]
        [System.Boolean]
        $ProcessOnlyOnActiveNode
    )

    $configurationInDesiredState = $true

    $getTargetResourceParameters = @{
        DatabaseName          = $DatabaseName
        ServerName            = $ServerName
        InstanceName          = $InstanceName
        AvailabilityGroupName = $AvailabilityGroupName
        BackupPath            = $BackupPath
    }
    $currentConfiguration = Get-TargetResource @getTargetResourceParameters

    <#
        If this is supposed to process only the active node, and this is not the
        active node, don't bother evaluating the test.
    #>
    if ( $ProcessOnlyOnActiveNode -and -not $currentConfiguration.IsActiveNode )
    {
        Write-Verbose -Message ( $script:localizedData.NotActiveNode -f $env:COMPUTERNAME,$InstanceName )
        return $configurationInDesiredState
    }

    # Connect to the defined instance
    $serverObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

    # Get the Availability Group if it exists
    if ( -not [System.String]::IsNullOrEmpty($currentConfiguration.AvailabilityGroupName) )
    {
        $availabilityGroup = $serverObject.AvailabilityGroups[$AvailabilityGroupName]

        # Make sure we're communicating with the primary replica in order to make changes to the replica
        $primaryServerObject = Get-PrimaryReplicaServerObject -ServerObject $serverObject -AvailabilityGroup $availabilityGroup

        $matchingDatabaseNames = Get-MatchingDatabaseNames -DatabaseName $DatabaseName -ServerObject $primaryServerObject
        $databasesNotFoundOnTheInstance = @()

        if ( ( $Ensure -eq 'Present' ) -and $matchingDatabaseNames.Count -eq 0 )
        {
            $configurationInDesiredState = $false
            Write-Verbose -Message ($script:localizedData.DatabasesNotFound -f ($DatabaseName -join ', '))
        }
        else
        {
            $databasesNotFoundOnTheInstance = Get-DatabaseNamesNotFoundOnTheInstance -DatabaseName $DatabaseName -MatchingDatabaseNames $matchingDatabaseNames

            # If the databases specified are not present on the instance and the desired state is not Absent
            if ( ( $databasesNotFoundOnTheInstance.Count -gt 0 ) -and ( $Ensure -ne 'Absent' ) )
            {
                $configurationInDesiredState = $false
                Write-Verbose -Message ($script:localizedData.DatabasesNotFound -f ( $databasesNotFoundOnTheInstance -join ', ' ))
            }

            $getDatabasesToAddToAvailabilityGroupParameters = @{
                DatabaseName      = $DatabaseName
                Ensure            = $Ensure
                ServerObject      = $primaryServerObject
                AvailabilityGroup = $availabilityGroup
            }
            $databasesToAddToAvailabilityGroup = Get-DatabasesToAddToAvailabilityGroup @getDatabasesToAddToAvailabilityGroupParameters

            if ( $databasesToAddToAvailabilityGroup.Count -gt 0 )
            {
                $configurationInDesiredState = $false
                Write-Verbose -Message ($script:localizedData.DatabaseShouldBeMember -f $AvailabilityGroupName, ( $databasesToAddToAvailabilityGroup -join ', ' ))
            }

            $getDatabasesToRemoveFromAvailabilityGroupParameters = @{
                DatabaseName      = $DatabaseName
                Ensure            = $Ensure
                Force             = $Force
                ServerObject      = $primaryServerObject
                AvailabilityGroup = $availabilityGroup
            }
            $databasesToRemoveFromAvailabilityGroup = Get-DatabasesToRemoveFromAvailabilityGroup @getDatabasesToRemoveFromAvailabilityGroupParameters

            if ( $databasesToRemoveFromAvailabilityGroup.Count -gt 0 )
            {
                $configurationInDesiredState = $false
                Write-Verbose -Message ($script:localizedData.DatabaseShouldNotBeMember -f $AvailabilityGroupName, ( $databasesToRemoveFromAvailabilityGroup -join ', ' ))
            }
        }
    }
    else
    {
        $configurationInDesiredState = $false
        Write-Verbose -Message ($script:localizedData.AvailabilityGroupDoesNotExist -f ($DatabaseName -join ', '))
    }

    return $configurationInDesiredState
}

<#
    .SYNOPSIS
        Get the databases that should be members of the Availability Group.

    .PARAMETER DatabaseName
        The name of the database(s) to add to the availability group. This accepts wildcards.

    .PARAMETER Ensure
        Specifies the membership of the database(s) in the availability group. The options are:

            - Present:  The defined database(s) are added to the availability group. All other
                        databases that may be a member of the availability group are ignored.
            - Absent:   The defined database(s) are removed from the availability group. All other
                        databases that may be a member of the availability group are ignored.

    .PARAMETER ServerObject
        The server object the databases should be in.

    .PARAMETER AvailabilityGroup
        The availability group object the databases should be a member of.
#>
function Get-DatabasesToAddToAvailabilityGroup
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.String[]]
        $DatabaseName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Ensure,

        [Parameter(Mandatory = $true)]
        [Microsoft.SqlServer.Management.Smo.Server]
        $ServerObject,

        [Parameter(Mandatory = $true)]
        [Microsoft.SqlServer.Management.Smo.AvailabilityGroup]
        $AvailabilityGroup
    )

    $matchingDatabaseNames = Get-MatchingDatabaseNames -DatabaseName $DatabaseName -ServerObject $ServerObject

    # This is a hack to allow Compare-Object to work on an empty object
    if ( $null -eq $matchingDatabaseNames )
    {
        $MatchingDatabaseNames = @('')
    }

    $databasesInAvailabilityGroup = $AvailabilityGroup.AvailabilityDatabases | Select-Object -ExpandProperty Name

    # This is a hack to allow Compare-Object to work on an empty object
    if ( $null -eq $databasesInAvailabilityGroup )
    {
        $databasesInAvailabilityGroup = @('')
    }

    $comparisonResult = Compare-Object -ReferenceObject $matchingDatabaseNames -DifferenceObject $databasesInAvailabilityGroup
    $databasesToAddToAvailabilityGroup = @()

    if ( $Ensure -eq 'Present' )
    {
        $databasesToAddToAvailabilityGroup = $comparisonResult | Where-Object -FilterScript { $_.SideIndicator -eq '<=' } | Select-Object -ExpandProperty InputObject
    }

    return $databasesToAddToAvailabilityGroup
}

<#
    .SYNOPSIS
        Get the databases that should not be members of the Availability Group.

    .PARAMETER DatabaseName
        The name of the database(s) to add to the availability group. This accepts wildcards.

    .PARAMETER Ensure
        Specifies the membership of the database(s) in the availability group. The options are:

            - Present:  The defined database(s) are added to the availability group. All other
                        databases that may be a member of the availability group are ignored.
            - Absent:   The defined database(s) are removed from the availability group. All other
                        databases that may be a member of the availability group are ignored.

    .PARAMETER Force
        When used with "Ensure = 'Present'" it ensures the specified database(s) are the only databases
        that are a member of the specified Availability Group.

        This parameter is ignored when 'Ensure' is 'Absent'.

    .PARAMETER ServerObject
        The server object the databases should not be in.

    .PARAMETER AvailabilityGroup
        The availability group object the databases should not be a member of.
#>
function Get-DatabasesToRemoveFromAvailabilityGroup
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.String[]]
        $DatabaseName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Ensure,

        [Parameter()]
        [System.Boolean]
        $Force,

        [Parameter(Mandatory = $true)]
        [Microsoft.SqlServer.Management.Smo.Server]
        $ServerObject,

        [Parameter(Mandatory = $true)]
        [Microsoft.SqlServer.Management.Smo.AvailabilityGroup]
        $AvailabilityGroup
    )

    $matchingDatabaseNames = Get-MatchingDatabaseNames -DatabaseName $DatabaseName -ServerObject $ServerObject


    if ( $null -eq $matchingDatabaseNames )
    {
        $MatchingDatabaseNames = @('')
    }

    $databasesInAvailabilityGroup = $AvailabilityGroup.AvailabilityDatabases | Select-Object -ExpandProperty Name

    # This is a hack to allow Compare-Object to work on an empty object
    if ( $null -eq $databasesInAvailabilityGroup )
    {
        $databasesInAvailabilityGroup = @('')
    }

    $comparisonResult = Compare-Object -ReferenceObject $matchingDatabaseNames -DifferenceObject $databasesInAvailabilityGroup -IncludeEqual

    $databasesToRemoveFromAvailabilityGroup = @()

    if ( 'Absent' -eq $Ensure )
    {
        $databasesToRemoveFromAvailabilityGroup = $comparisonResult | Where-Object -FilterScript { '==' -eq $_.SideIndicator } | Select-Object -ExpandProperty InputObject
    }
    elseif ( ( 'Present' -eq $Ensure ) -and ( $Force ) )
    {
        $databasesToRemoveFromAvailabilityGroup = $comparisonResult | Where-Object -FilterScript { '=>' -eq $_.SideIndicator } | Select-Object -ExpandProperty InputObject
    }

    return $databasesToRemoveFromAvailabilityGroup
}

<#
    .SYNOPSIS
        Get the database names that were specified in the configuration that do not exist on the instance.

    .PARAMETER DatabaseName
        The name of the database(s) to add to the availability group. This accepts wildcards.

    .PARAMETER MatchingDatabaseNames
        All of the databases names that match the supplied names and wildcards.
#>
function Get-MatchingDatabaseNames
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.String[]]
        $DatabaseName,

        [Parameter(Mandatory = $true)]
        [Microsoft.SqlServer.Management.Smo.Server]
        $ServerObject
    )

    $matchingDatabaseNames = @()

    foreach ( $dbName in $DatabaseName )
    {
        $matchingDatabaseNames += $ServerObject.Databases |
            Where-Object -FilterScript { $_.Name -ilike $dbName } |
            Select-Object -ExpandProperty Name
    }

    return $matchingDatabaseNames
}

<#
    .SYNOPSIS
        Get the database names that were defined in the DatabaseName property but were not found on the instance.

    .PARAMETER DatabaseName
        The name of the database(s) to add to the availability group. This accepts wildcards.

    .PARAMETER MatchingDatabaseNames
        All of the database names that were found on the instance that match the supplied DatabaseName property.
#>
function Get-DatabaseNamesNotFoundOnTheInstance
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.String[]]
        $DatabaseName,

        [Parameter()]
        [System.String[]]
        $MatchingDatabaseNames
    )

    $databasesNotFoundOnTheInstance = @{}
    foreach ( $dbName in $DatabaseName )
    {
        # Assume the database name was not found
        $databaseToAddToAvailabilityGroupNotFound = $true

        foreach ( $matchingDatabaseName in $matchingDatabaseNames )
        {
            if ( $matchingDatabaseName -like $dbName )
            {
                # If we found the database name, it's not missing
                $databaseToAddToAvailabilityGroupNotFound = $false
            }
        }

        $databasesNotFoundOnTheInstance.Add($dbName, $databaseToAddToAvailabilityGroupNotFound)
    }

    $result = $databasesNotFoundOnTheInstance.GetEnumerator() | Where-Object -FilterScript { $_.Value } | Select-Object -ExpandProperty Key

    return $result
}
