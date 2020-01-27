$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SqlServerDsc.Common'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SqlServerDsc.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_SqlServerMemory'

<#
    .SYNOPSIS
        This function gets the value of the min and max memory server configuration option.

    .PARAMETER ServerName
        The host name of the SQL Server to be configured.

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
        [ValidateNotNullOrEmpty()]
        [System.String]
        $InstanceName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName = $env:COMPUTERNAME
    )

    Write-Verbose -Message (
        $script:localizedData.GetMemoryValues -f $InstanceName
    )

    $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName
    if ($sqlServerObject)
    {
        $minMemory = $sqlServerObject.Configuration.MinServerMemory.ConfigValue
        $maxMemory = $sqlServerObject.Configuration.MaxServerMemory.ConfigValue

        # Is this node actively hosting the SQL instance?
        $isActiveNode = Test-ActiveNode -ServerObject $sqlServerObject
    }

    $returnValue = @{
        InstanceName = $InstanceName
        ServerName   = $ServerName
        MinMemory    = $minMemory
        MaxMemory    = $maxMemory
        IsActiveNode = $isActiveNode
    }

    $returnValue
}

<#
    .SYNOPSIS
        This function sets the value for the min and max memory server configuration option.

    .PARAMETER ServerName
        The host name of the SQL Server to be configured.

    .PARAMETER InstanceName
        The name of the SQL instance to be configured.

    .PARAMETER Ensure
        When set to 'Present' then min and max memory will be set to either the value in parameter MinMemory and MaxMemory or dynamically configured when parameter DynamicAlloc is set to $true.
        When set to 'Absent' min and max memory will be set to default values.

    .PARAMETER DynamicAlloc
        If set to $true then max memory will be dynamically configured.
        When this is set parameter is set to $true, the parameter MaxMemory must be set to $null or not be configured.

    .PARAMETER MinMemory
        This is the minimum amount of memory, in MB, in the buffer pool used by the instance of SQL Server.

    .PARAMETER MaxMemory
        This is the maximum amount of memory, in MB, in the buffer pool used by the instance of SQL Server.

    .PARAMETER ProcessOnlyOnActiveNode
        Specifies that the resource will only determine if a change is needed if the target node is the active host of the SQL Server instance.
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
        $InstanceName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName = $env:COMPUTERNAME,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.Boolean]
        $DynamicAlloc = $false,

        [Parameter()]
        [System.Int32]
        $MinMemory,

        [Parameter()]
        [System.Int32]
        $MaxMemory,

        [Parameter()]
        [System.Boolean]
        $ProcessOnlyOnActiveNode
    )

    Write-Verbose -Message (
        $script:localizedData.SetNewValues -f $InstanceName
    )

    $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName
    if ($sqlServerObject)
    {
        switch ($Ensure)
        {
            'Present'
            {
                if ($DynamicAlloc)
                {
                    if ($MaxMemory)
                    {
                        $errorMessage = $script:localizedData.MaxMemoryParamMustBeNull
                        New-InvalidArgumentException -ArgumentName 'MaxMemory' -Message $errorMessage
                    }

                    $MaxMemory = Get-SqlDscDynamicMaxMemory

                    Write-Verbose -Message (
                        $script:localizedData.DynamicMaxMemoryValue -f $MaxMemory
                    )
                }
                else
                {
                    if (-not $MaxMemory)
                    {
                        $errorMessage = $script:localizedData.MaxMemoryParamMustNotBeNull
                        New-InvalidArgumentException -ArgumentName 'MaxMemory' -Message $errorMessage
                    }
                }

                Write-Verbose -Message (
                    $script:localizedData.MaximumMemoryLimited -f $InstanceName, $MaxMemory
                )

                $sqlServerObject.Configuration.MaxServerMemory.ConfigValue = $MaxMemory

                if ($MinMemory)
                {
                    $sqlServerObject.Configuration.MinServerMemory.ConfigValue = $MinMemory

                    Write-Verbose -Message (
                        $script:localizedData.MinimumMemoryLimited -f $InstanceName, $MinMemory
                    )
                }
            }

            'Absent'
            {
                $defaultMaxMemory = 2147483647
                $defaultMinMemory = 0

                Write-Verbose -Message (
                    $script:localizedData.DefaultValues -f $defaultMinMemory, $defaultMaxMemory
                )

                $sqlServerObject.Configuration.MaxServerMemory.ConfigValue = $defaultMaxMemory
                $sqlServerObject.Configuration.MinServerMemory.ConfigValue = $defaultMinMemory

                Write-Verbose -Message (
                    $script:localizedData.ResetDefaultValues -f $InstanceName
                )
            }
        }

        try
        {
            $sqlServerObject.Alter()
        }
        catch
        {
            $errorMessage = $script:localizedData.AlterServerMemoryFailed -f $ServerName, $InstanceName
            New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
        }
    }
}

<#
    .SYNOPSIS
        This function tests the value of the min and max memory server configuration option.

    .PARAMETER ServerName
        The host name of the SQL Server to be configured.

    .PARAMETER InstanceName
        The name of the SQL instance to be configured.

    .PARAMETER Ensure
        When set to 'Present' then min and max memory will be set to either the value in parameter MinMemory and MaxMemory or dynamically configured when parameter DynamicAlloc is set to $true.
        When set to 'Absent' min and max memory will be set to default values.

    .PARAMETER DynamicAlloc
        If set to $true then max memory will be dynamically configured.
        When this is set parameter is set to $true, the parameter MaxMemory must be set to $null or not be configured.

    .PARAMETER MinMemory
        This is the minimum amount of memory, in MB, in the buffer pool used by the instance of SQL Server.

    .PARAMETER MaxMemory
        This is the maximum amount of memory, in MB, in the buffer pool used by the instance of SQL Server.

    .PARAMETER ProcessOnlyOnActiveNode
        Specifies that the resource will only determine if a change is needed if the target node is the active host of the SQL Server instance.
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
        $InstanceName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName = $env:COMPUTERNAME,

        [Parameter()]
        [ValidateSet("Present", "Absent")]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.Boolean]
        $DynamicAlloc = $false,

        [Parameter()]
        [System.Int32]
        $MinMemory,

        [Parameter()]
        [System.Int32]
        $MaxMemory,

        [Parameter()]
        [System.Boolean]
        $ProcessOnlyOnActiveNode
    )

    Write-Verbose -Message (
        $script:localizedData.EvaluatingMinAndMaxMemory -f $InstanceName
    )

    $getTargetResourceParameters = @{
        InstanceName = $InstanceName
        ServerName   = $ServerName
    }

    $getTargetResourceResult = Get-TargetResource @getTargetResourceParameters

    $currentMinMemory = $getTargetResourceResult.MinMemory
    $currentMaxMemory = $getTargetResourceResult.MaxMemory
    $isServerMemoryInDesiredState = $true

    <#
        If this is supposed to process only the active node, and this is not the
        active node, don't bother evaluating the test.
    #>
    if ($ProcessOnlyOnActiveNode -and -not $getTargetResourceResult.IsActiveNode)
    {
        Write-Verbose -Message (
            $script:localizedData.NotActiveNode -f $env:COMPUTERNAME, $InstanceName
        )

        return $isServerMemoryInDesiredState
    }

    switch ($Ensure)
    {
        'Absent'
        {
            if ($currentMaxMemory -ne 2147483647)
            {
                Write-Verbose -Message (
                    $script:localizedData.WrongMaximumMemory -f $currentMaxMemory, '2147483647'
                )

                $isServerMemoryInDesiredState = $false
            }

            if ($currentMinMemory -ne 0)
            {
                Write-Verbose -Message (
                    $script:localizedData.WrongMinimumMemory -f $currentMinMemory, '0'
                )

                $isServerMemoryInDesiredState = $false
            }
        }

        'Present'
        {
            if ($DynamicAlloc)
            {
                if ($MaxMemory)
                {
                    $errorMessage = $script:localizedData.MaxMemoryParamMustBeNull
                    New-InvalidArgumentException -ArgumentName 'MaxMemory' -Message $errorMessage
                }

                $MaxMemory = Get-SqlDscDynamicMaxMemory

                Write-Verbose -Message (
                    $script:localizedData.DynamicMaxMemoryValue -f $MaxMemory
                )
            }
            else
            {
                if (-not $MaxMemory)
                {
                    $errorMessage = $script:localizedData.MaxMemoryParamMustNotBeNull
                    New-InvalidArgumentException -ArgumentName 'MaxMemory' -Message $errorMessage
                }
            }

            if ($MaxMemory -ne $currentMaxMemory)
            {
                Write-Verbose -Message (
                    $script:localizedData.WrongMaximumMemory -f $currentMaxMemory, $MaxMemory
                )

                $isServerMemoryInDesiredState = $false
            }

            if ($MinMemory)
            {
                if ($MinMemory -ne $currentMinMemory)
                {
                    Write-Verbose -Message (
                        $script:localizedData.WrongMinimumMemory -f $currentMinMemory, $MinMemory
                    )

                    $isServerMemoryInDesiredState = $false
                }
            }
        }
    }

    return $isServerMemoryInDesiredState
}

<#
    .SYNOPSIS
    This cmdlet is used to return the Dynamic MaxMemory of a SQL Instance
#>
function Get-SqlDscDynamicMaxMemory
{
    try
    {
        $physicalMemory = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory
        $physicalMemoryInMegaBytes = [Math]::Round($physicalMemory / 1MB)

        # Find how much to save for OS: 20% of total ram for under 15GB / 12.5% for over 20GB
        if ($physicalMemoryInMegaBytes -ge 20480)
        {
            $reservedOperatingSystemMemory = [Math]::Round((0.125 * $physicalMemoryInMegaBytes))
        }
        else
        {
            $reservedOperatingSystemMemory = [Math]::Round((0.2 * $physicalMemoryInMegaBytes))
        }

        $numberOfCores = (Get-CimInstance -ClassName Win32_Processor | Measure-Object -Property NumberOfCores -Sum).Sum

        # Get the number of SQL threads.
        if ($numberOfCores -ge 4)
        {
            $numberOfSqlThreads = 256 + ($numberOfCores - 4) * 8
        }
        else
        {
            $numberOfSqlThreads = 0
        }

        $operatingSystemArchitecture = (Get-CimInstance -ClassName Win32_OperatingSystem).OSArchitecture

        # Find threadStackSize 1MB x86/ 2MB x64/ 4MB IA64
        if ($operatingSystemArchitecture -eq '32-bit')
        {
            $threadStackSize = 1
        }
        elseif ($operatingSystemArchitecture -eq '64-bit')
        {
            $threadStackSize = 2
        }
        else
        {
            $threadStackSize = 4
        }

        $maxMemory = $physicalMemoryInMegaBytes - $reservedOperatingSystemMemory - ($numberOfSqlThreads * $threadStackSize) - (1024 * [System.Math]::Ceiling($numberOfCores / 4))
    }
    catch
    {
        $errorMessage = $script:localizedData.ErrorGetDynamicMaxMemory
        New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
    }

    $maxMemory
}

Export-ModuleMember -Function *-TargetResource
