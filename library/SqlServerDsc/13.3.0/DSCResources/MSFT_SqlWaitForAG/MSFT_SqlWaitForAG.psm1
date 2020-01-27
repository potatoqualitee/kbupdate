$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SqlServerDsc.Common'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SqlServerDsc.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_SqlWaitForAG'

<#
    .SYNOPSIS
        Returns the cluster role/group that is waiting to be created,
        along with the time and number of times to wait.

    .PARAMETER Name
        Name of the cluster role/group to look for (normally the same as the Availability Group name).

    .PARAMETER RetryIntervalSec
        The interval, in seconds, to check for the presence of the cluster role/group.
        Default value is 20 seconds.
        When the cluster role/group has been found the resource will wait for this amount of time once
        more before returning.

    .PARAMETER RetryCount
        Maximum number of retries until the resource will timeout and throw an error. Default values is 30 times.
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

        [Parameter()]
        [System.UInt64]
        $RetryIntervalSec = 20,

        [Parameter()]
        [System.UInt32]
        $RetryCount = 30
    )

    Write-Verbose -Message (
        $script:localizedData.GetCurrentState -f $Name
    )

    $clusterGroupFound = $false

    $clusterGroup = Get-ClusterGroup -Name $Name -ErrorAction SilentlyContinue
    if ($null -ne $clusterGroup)
    {
        Write-Verbose -Message (
            $script:localizedData.FoundClusterGroup -f $Name
        )

        $clusterGroupFound = $true
    }
    else
    {
        Write-Verbose -Message (
            $script:localizedData.MissingClusterGroup -f $Name
        )
    }

    return @{
        Name             = $Name
        RetryIntervalSec = $RetryIntervalSec
        RetryCount       = $RetryCount
        GroupExist       = $clusterGroupFound
    }
}

<#
    .SYNOPSIS
        Waits for a cluster role/group to be created

    .PARAMETER Name
        Name of the cluster role/group to look for (normally the same as the Availability Group name).

    .PARAMETER RetryIntervalSec
        The interval, in seconds, to check for the presence of the cluster role/group.
        Default value is 20 seconds.
        When the cluster role/group has been found the resource will wait for this amount of time once
        more before returning.

    .PARAMETER RetryCount
        Maximum number of retries until the resource will timeout and throw an error. Default values is 30 times.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter()]
        [System.UInt64]
        $RetryIntervalSec = 20,

        [Parameter()]
        [System.UInt32]
        $RetryCount = 30
    )

    Write-Verbose -Message (
        $script:localizedData.WaitingClusterGroup -f $Name, $RetryCount, ($RetryIntervalSec * $RetryCount)
    )

    $getTargetResourceParameters = @{
        Name             = $Name
        RetryIntervalSec = $RetryIntervalSec
        RetryCount       = $RetryCount
    }

    for ($forLoopCount = 0; $forLoopCount -lt $RetryCount; $forLoopCount++)
    {
        $clusterGroupFound = (Get-TargetResource @getTargetResourceParameters).GroupExist
        if ($clusterGroupFound)
        {
            Write-Verbose -Message (
                '{0} {1}' -f `
                    ($script:localizedData.FoundClusterGroup -f $Name, $RetryCount, ($RetryIntervalSec * $RetryCount)),
                    ($script:localizedData.SleepMessage -f $RetryIntervalSec)
            )

            Start-Sleep -Seconds $RetryIntervalSec
            break
        }

        Write-Verbose -Message (
            '{0} {1}' -f `
                ($script:localizedData.MissingClusterGroup -f $Name, $RetryCount, ($RetryIntervalSec * $RetryCount)),
                ($script:localizedData.RetryMessage -f $RetryIntervalSec)
        )

        Start-Sleep -Seconds $RetryIntervalSec
    }

    if (-not $clusterGroupFound)
    {
        $errorMessage = $script:localizedData.FailedMessage -f $Name
        New-InvalidOperationException -Message $errorMessage
    }
}

<#
    .SYNOPSIS
        Tests if the cluster role/group has been created.

    .PARAMETER Name
        Name of the cluster role/group to look for (normally the same as the Availability Group name).

    .PARAMETER RetryIntervalSec
        The interval, in seconds, to check for the presence of the cluster role/group.
        Default value is 20 seconds.
        When the cluster role/group has been found the resource will wait for this amount of time once
        more before returning.

    .PARAMETER RetryCount
        Maximum number of retries until the resource will timeout and throw an error. Default values is 30 times.
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

        [Parameter()]
        [System.UInt64]
        $RetryIntervalSec = 20,

        [Parameter()]
        [System.UInt32]
        $RetryCount = 30
    )

    Write-Verbose -Message (
        $script:localizedData.TestingConfiguration -f $Name
    )

    $getTargetResourceParameters = @{
        Name             = $Name
        RetryIntervalSec = $RetryIntervalSec
        RetryCount       = $RetryCount
    }

    $clusterGroupFound = (Get-TargetResource @getTargetResourceParameters).GroupExist
    if ($clusterGroupFound)
    {
        Write-Verbose -Message (
            $script:localizedData.FoundClusterGroup -f $Name
        )
    }
    else
    {
        Write-Verbose -Message (
            $script:localizedData.MissingClusterGroup -f $Name
        )
    }

    return $clusterGroupFound
}

Export-ModuleMember -Function *-TargetResource
