$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SqlServerDsc.Common'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SqlServerDsc.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_SqlServerConfiguration'

<#
    .SYNOPSIS
        Gets the current value of a SQL configuration option

    .PARAMETER ServerName
        Hostname of the SQL Server to be configured

    .PARAMETER InstanceName
        Name of the SQL instance to be configured. Default is 'MSSQLSERVER'

    .PARAMETER OptionName
        The name of the SQL configuration option to be checked

    .PARAMETER OptionValue
        The desired value of the SQL configuration option

    .PARAMETER RestartService
        *** Not used in this function ***
        Determines whether the instance should be restarted after updating the
        configuration option.

    .PARAMETER RestartTimeout
        *** Not used in this function ***
        The length of time, in seconds, to wait for the service to restart. Default
        is 120 seconds.
#>
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $OptionName,

        [Parameter(Mandatory = $true)]
        [System.Int32]
        $OptionValue,

        [Parameter()]
        [System.Boolean]
        $RestartService = $false,

        [Parameter()]
        [System.UInt32]
        $RestartTimeout = 120
    )

    $sql = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

    # Get the current value of the configuration option.
    $option = $sql.Configuration.Properties | Where-Object { $_.DisplayName -eq $OptionName }

    if (-not $option)
    {
        $errorMessage = $script:localizedData.ConfigurationOptionNotFound -f $OptionName
        New-InvalidArgumentException -ArgumentName 'OptionName' -Message $errorMessage
    }

    Write-Verbose -Message (
        $script:localizedData.CurrentOptionValue `
            -f $OptionName, $option.ConfigValue
    )

    return @{
        ServerName     = $ServerName
        InstanceName   = $InstanceName
        OptionName     = $option.DisplayName
        OptionValue    = $option.ConfigValue
        RestartService = $RestartService
        RestartTimeout = $RestartTimeout
    }
}

<#
    .SYNOPSIS
        Sets the value of a SQL configuration option

    .PARAMETER ServerName
        Hostname of the SQL Server to be configured

    .PARAMETER InstanceName
        Name of the SQL instance to be configured. Default is 'MSSQLSERVER'

    .PARAMETER OptionName
        The name of the SQL configuration option to be set

    .PARAMETER OptionValue
        The desired value of the SQL configuration option

    .PARAMETER RestartService
        Determines whether the instance should be restarted after updating the
        configuration option

    .PARAMETER RestartTimeout
        The length of time, in seconds, to wait for the service to restart. Default
        is 120 seconds.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $OptionName,

        [Parameter(Mandatory = $true)]
        [System.Int32]
        $OptionValue,

        [Parameter()]
        [System.Boolean]
        $RestartService = $false,

        [Parameter()]
        [System.UInt32]
        $RestartTimeout = 120
    )

    $sql = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

    # Get the current value of the configuration option.
    $option = $sql.Configuration.Properties | Where-Object { $_.DisplayName -eq $OptionName }

    if (-not $option)
    {
        $errorMessage = $script:localizedData.ConfigurationOptionNotFound -f $OptionName
        New-InvalidArgumentException -ArgumentName 'OptionName' -Message $errorMessage
    }

    $option.ConfigValue = $OptionValue
    $sql.Configuration.Alter()

    Write-Verbose -Message (
        $script:localizedData.ConfigurationValueUpdated `
            -f $OptionName, $OptionValue
    )

    if ($option.IsDynamic -eq $true)
    {
        Write-Verbose -Message $script:localizedData.NoRestartNeeded
    }
    elseif (($option.IsDynamic -eq $false) -and ($RestartService -eq $true))
    {
        Write-Verbose -Message (
            $script:localizedData.AutomaticRestart `
                -f $ServerName, $InstanceName
        )

        Restart-SqlService -ServerName $ServerName -InstanceName $InstanceName -Timeout $RestartTimeout
    }
    else
    {
        Write-Warning -Message (
            $script:localizedData.ConfigurationRestartRequired `
                -f $OptionName, $OptionValue, $ServerName, $InstanceName
        )
    }
}

<#
    .SYNOPSIS
        Determines whether a SQL configuration option value is properly set

    .PARAMETER ServerName
        Hostname of the SQL Server to be configured

    .PARAMETER InstanceName
        Name of the SQL instance to be configured. Default is 'MSSQLSERVER'

    .PARAMETER OptionName
        The name of the SQL configuration option to be tested

    .PARAMETER OptionValue
        The desired value of the SQL configuration option

    .PARAMETER RestartService
        *** Not used in this function ***
        Determines whether the instance should be restarted after updating the
        configuration option

    .PARAMETER RestartTimeout
        *** Not used in this function ***
        The length of time, in seconds, to wait for the service to restart. Default
        is 120 seconds.
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $OptionName,

        [Parameter(Mandatory = $true)]
        [System.Int32]
        $OptionValue,

        [Parameter()]
        [System.Boolean]
        $RestartService = $false,

        [Parameter()]
        [System.UInt32]
        $RestartTimeout = 120
    )

    # Get the current value of the configuration option.
    $getTargetResourceResult = Get-TargetResource @PSBoundParameters

    if ($getTargetResourceResult.OptionValue -eq $OptionValue)
    {
        Write-Verbose -Message (
            $script:localizedData.InDesiredState `
                -f $OptionName
        )

        $result = $true
    }
    else
    {
        Write-Verbose -Message (
            $script:localizedData.NotInDesiredState `
                -f $OptionName, $OptionValue, $getTargetResourceResult.OptionValue
        )

        $result = $false
    }

    return $result
}

Export-ModuleMember -Function *-TargetResource
