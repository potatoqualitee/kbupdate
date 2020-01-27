$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SqlServerDsc.Common'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SqlServerDsc.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_SqlDatabaseDefaultLocation'

<#
    .SYNOPSIS
        Returns the current path to the the desired default location for the Data, Log, or Backup files.

    .PARAMETER ServerName
        The host name of the SQL Server to be configured.

    .PARAMETER InstanceName
        The name of the SQL instance to be configured.

    .PARAMETER Type
        The type of database default location to be configured. { Data | Log | Backup }

    .PARAMETER Path
        The path to the default directory to be configured.
        Not used in Get-TargetResource
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
        $ServerName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Data', 'Log', 'Backup')]
        [System.String]
        $Type,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path
    )

    Write-Verbose -Message ($script:localizedData.GetCurrentPath -f $Type, $InstanceName)

    # Connect to the instance
    $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

    # Is this node actively hosting the SQL instance?
    $isActiveNode = Test-ActiveNode -ServerObject $sqlServerObject

    # Check which default location is being retrieved
    switch ($Type)
    {
        'Data'
        {
            $currentPath = $sqlServerObject.DefaultFile
        }

        'Log'
        {
            $currentPath = $sqlServerObject.DefaultLog
        }

        'Backup'
        {
            $currentPath = $sqlServerObject.BackupDirectory
        }
    }

    return @{
        InstanceName = $InstanceName
        ServerName   = $ServerName
        Type         = $Type
        Path         = $currentPath
        IsActiveNode = $isActiveNode
    }
}

<#
    .SYNOPSIS
        This function sets the current path for the default SQL Instance location for the Data, Log, or Backups files.

    .PARAMETER ServerName
        The host name of the SQL Server to be configured.

    .PARAMETER InstanceName
        The name of the SQL instance to be configured.

    .PARAMETER Type
        The type of database default location to be configured. { Data | Log | Backup }

    .PARAMETER Path
        The path to the default directory to be configured.

    .PARAMETER RestartService
        If set to $true then SQL Server and dependent services will be restarted if a change to the default location
        is made.  The default value is $false.

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
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Data', 'Log', 'Backup')]
        [System.String]
        $Type,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        [Parameter()]
        [System.Boolean]
        $RestartService = $false,

        [Parameter()]
        [System.Boolean]
        $ProcessOnlyOnActiveNode
    )

    if ($Type -eq 'Backup')
    {
        # Ending backslash is removed because of issue #1307.
        $Path = $Path.TrimEnd('\')
    }

    # Make sure the Path exists, needs to be cluster aware as well for this check
    if (-Not (Test-Path $Path))
    {
        throw ($script:localizedData.InvalidPath -f $Path)
    }
    else
    {
        Write-Verbose -Message ($script:localizedData.SettingDefaultPath -f $Type)
        $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

        # Check which default location is being updated
        switch ($Type)
        {
            'Data'
            {
                $currentValuePath = $sqlServerObject.DefaultFile
                $sqlServerObject.DefaultFile = $Path
            }

            'Log'
            {
                $currentValuePath = $sqlServerObject.DefaultLog
                $sqlServerObject.DefaultLog = $Path
            }

            'Backup'
            {
                $currentValuePath = $sqlServerObject.BackupDirectory
                $sqlServerObject.BackupDirectory = $Path
            }
        }

        # Wrap the Alter command in a try-catch in case the update doesn't work
        try
        {
            $originalErrorActionPreference = $ErrorActionPreference
            $ErrorActionPreference = 'Stop'
            $sqlServerObject.Alter()
            Write-Verbose -Message ($script:localizedData.DefaultPathChanged -f $Type, $currentValuePath, $Path)

            if ($RestartService)
            {
                Write-Verbose -Message ($script:localizedData.RestartSqlServer -f $ServerName, $InstanceName)
                Restart-SqlService -ServerName $ServerName -InstanceName $InstanceName
            }
        }
        catch
        {
            $errorMessage = $script:localizedData.ChangingPathFailed
            New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
        }
        finally
        {
            $ErrorActionPreference = $originalErrorActionPreference
        }
    }
}

<#
    .SYNOPSIS
        This function tests the current path to the default database location for the Data, Log, or Backups files.

    .PARAMETER ServerName
        The host name of the SQL Server to be configured.

    .PARAMETER InstanceName
        The name of the SQL instance to be configured.

    .PARAMETER Type
        The type of database default location to be configured. { Data | Log | Backup }

    .PARAMETER Path
        The path to the default directory to be configured.

    .PARAMETER RestartService
        If set to $true then SQL Server and dependent services will be restarted if a change to the default location
        is made.  The default value is $false.

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
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Data', 'Log', 'Backup')]
        [System.String]
        $Type,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        [Parameter()]
        [System.Boolean]
        $RestartService = $false,

        [Parameter()]
        [System.Boolean]
        $ProcessOnlyOnActiveNode
    )

    Write-Verbose -Message ($script:localizedData.TestingCurrentPath -f $Type)

    if ($Type -eq 'Backup')
    {
        # Ending backslash is removed because of issue #1307.
        $Path = $Path.TrimEnd('\')
    }

    $getTargetResourceParameters = @{
        InstanceName = $InstanceName
        ServerName   = $ServerName
        Type         = $Type
        Path         = $Path
    }

    $isDefaultPathInDesiredState = $true

    $getTargetResourceResult = Get-TargetResource @getTargetResourceParameters
    <#
        If this is supposed to process only the active node, and this is not the
        active node, don't bother evaluating the test.
    #>
    if ( $ProcessOnlyOnActiveNode -and -not $getTargetResourceResult.IsActiveNode )
    {
        Write-Verbose -Message ($script:localizedData.NotActiveClusterNode -f $env:COMPUTERNAME, $InstanceName )
    }
    elseif ($getTargetResourceResult.Path -ne $Path)
    {
        Write-Verbose -Message ($script:localizedData.DefaultPathDifference -f $Type, $getTargetResourceResult.Path, $Path)
        $isDefaultPathInDesiredState = $false
    }

    return $isDefaultPathInDesiredState
}

