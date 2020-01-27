$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SqlServerDsc.Common'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SqlServerDsc.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_SqlAlwaysOnService'

<#
    .SYNOPSIS
    Gets the current value of the SQL Server Always On high availability and
    disaster recovery (HADR) property.

    .PARAMETER Ensure
    An enumerated value that describes if the SQL Server should have Always On high
    availability and disaster recovery (HADR) property enabled ('Present') or
    disabled ('Absent').

    *** Not used in this function ***

    .PARAMETER ServerName
    The hostname of the SQL Server to be configured.

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
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName
    )

    $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

    $isAlwaysOnEnabled = [System.Boolean] $sqlServerObject.IsHadrEnabled
    if ($isAlwaysOnEnabled -eq $true)
    {
        $statusString = 'enabled'
    }
    elseif ($isAlwaysOnEnabled -eq $false)
    {
        $statusString = 'disabled'
    }

    Write-Verbose -Message (
        $script:localizedData.GetAlwaysOnServiceState -f $statusString, $ServerName, $InstanceName
    )

    return @{
        IsHadrEnabled = $isAlwaysOnEnabled
    }
}

<#
    .SYNOPSIS
    Sets the current value of the SQL Server Always On high availability and disaster recovery (HADR) property.

    .PARAMETER Ensure
    An enumerated value that describes if the SQL Server should have Always On high
    availability and disaster recovery (HADR) property enabled ('Present') or
    disabled ('Absent').

    .PARAMETER ServerName
    The hostname of the SQL Server to be configured.

    .PARAMETER InstanceName
    The name of the SQL instance to be configured.

    .PARAMETER RestartTimeout
    The length of time, in seconds, to wait for the service to restart. Default is 120 seconds.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter()]
        [System.UInt32]
        $RestartTimeout = 120
    )

    # Build the instance name to allow the Enable/Disable-Always On to connect to the instance
    if ($InstanceName -eq "MSSQLSERVER")
    {
        $serverInstance = $ServerName
    }
    else
    {
        $serverInstance = "$ServerName\$InstanceName"
    }

    Import-SQLPSModule

    switch ($Ensure)
    {
        'Absent'
        {
            $statusString = 'disabled'

            # Disable Always On without restarting the services.
            Write-Verbose -Message (
                $script:localizedData.DisableAlwaysOnAvailabilityGroup -f $ServerName, $InstanceName
            )

            Disable-SqlAlwaysOn -ServerInstance $serverInstance -NoServiceRestart -ErrorAction 'Stop'
        }

        'Present'
        {
            $statusString = 'enabled'

            # Enable Always On without restarting the services.
            Write-Verbose -Message (
                $script:localizedData.EnableAlwaysOnAvailabilityGroup -f $ServerName, $InstanceName
            )

            Enable-SqlAlwaysOn -ServerInstance $serverInstance -NoServiceRestart -ErrorAction 'Stop'
        }
    }

    Write-Verbose -Message (
        $script:localizedData.RestartingService -f $statusString, $ServerName, $InstanceName
    )

    # Now restart the SQL service so that all dependent services are also returned to their previous state
    Restart-SqlService -ServerName $ServerName -InstanceName $InstanceName -Timeout $RestartTimeout

    # Verify always on was set
    if ( -not ( Test-TargetResource @PSBoundParameters ) )
    {
        $errorMessage = $script:localizedData.AlterAlwaysOnServiceFailed -f $statusString, $ServerName, $InstanceName
        New-InvalidResultException -Message $errorMessage
    }
}

<#
    .SYNOPSIS
    Determines whether the current value of the SQL Server Always On high
    availability and disaster recovery (HADR) property is properly set.

    .PARAMETER Ensure
    An enumerated value that describes if the SQL Server should have Always On high
    availability and disaster recovery (HADR) property enabled ('Present') or
    disabled ('Absent').

    .PARAMETER ServerName
    The hostname of the SQL Server to be configured.

    .PARAMETER InstanceName
    The name of the SQL instance to be configured.

    .PARAMETER RestartTimeout
    The length of time, in seconds, to wait for the service to restart. Default is 120 seconds.

    *** Not used in this function ***
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter()]
        [System.UInt32]
        $RestartTimeout = 120
    )

    Write-Verbose -Message (
        $script:localizedData.TestingConfiguration -f $ServerName, $InstanceName
    )

    # Determine the current state of Always On
    $getTargetResourceParameters = @{
        Ensure       = $Ensure
        ServerName   = $ServerName
        InstanceName = $InstanceName
    }

    $state = Get-TargetResource @getTargetResourceParameters

    $isInDesiredState = $true

    if ($state.IsHadrEnabled)
    {
        if ($Ensure -eq 'Present')
        {
            Write-Verbose -Message $script:localizedData.AlwaysOnAvailabilityGroupEnabled
        }
        else
        {
            Write-Verbose -Message $script:localizedData.AlwaysOnAvailabilityGroupNotInDesiredStateDisabled
            $isInDesiredState = $false
        }
    }
    else
    {
        if ($Ensure -eq 'Absent')
        {
            Write-Verbose -Message $script:localizedData.AlwaysOnAvailabilityGroupDisabled
        }
        else
        {
            Write-Verbose -Message $script:localizedData.AlwaysOnAvailabilityGroupNotInDesiredStateEnabled
            $isInDesiredState = $false
        }
    }

    return $isInDesiredState
}

Export-ModuleMember -Function *-TargetResource
