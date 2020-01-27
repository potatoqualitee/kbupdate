$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SqlServerDsc.Common'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SqlServerDsc.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_SqlServerMaxDop'

<#
    .SYNOPSIS
    This function gets the max degree of parallelism server configuration option.

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
        $script:localizedData.GetConfiguration -f $InstanceName
    )

    $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName
    if ($sqlServerObject)
    {
        # Is this node actively hosting the SQL instance?
        $isActiveNode = Test-ActiveNode -ServerObject $sqlServerObject

        $currentMaxDop = $sqlServerObject.Configuration.MaxDegreeOfParallelism.ConfigValue
    }

    $returnValue = @{
        InstanceName = $InstanceName
        ServerName   = $ServerName
        MaxDop       = $currentMaxDop
        IsActiveNode = $isActiveNode
    }

    $returnValue
}

<#
    .SYNOPSIS
    This function sets the max degree of parallelism server configuration option.

    .PARAMETER ServerName
    The host name of the SQL Server to be configured.

    .PARAMETER InstanceName
    The name of the SQL instance to be configured.

    .PARAMETER Ensure
    When set to 'Present' then max degree of parallelism will be set to either the value in parameter MaxDop or dynamically configured when parameter DynamicAlloc is set to $true.
    When set to 'Absent' max degree of parallelism will be set to 0 which means no limit in number of processors used in parallel plan execution.

    .PARAMETER DynamicAlloc
    If set to $true then max degree of parallelism will be dynamically configured.
    When this is set parameter is set to $true, the parameter MaxDop must be set to $null or not be configured.

    .PARAMETER MaxDop
    A numeric value to limit the number of processors used in parallel plan execution.

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
        $InstanceName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName = $env:COMPUTERNAME,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.Boolean]
        $DynamicAlloc,

        [Parameter()]
        [System.Int32]
        $MaxDop,

        [Parameter()]
        [System.Boolean]
        $ProcessOnlyOnActiveNode
    )

    $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName
    if ($sqlServerObject)
    {
        Write-Verbose -Message (
            $script:localizedData.SetConfiguration -f $InstanceName
        )

        switch ($Ensure)
        {
            'Present'
            {
                if ($DynamicAlloc)
                {
                    if ($MaxDop)
                    {
                        $errorMessage = $script:localizedData.MaxDopParamMustBeNull
                        New-InvalidArgumentException -ArgumentName 'MaxDop' -Message $errorMessage
                    }

                    $targetMaxDop = Get-SqlDscDynamicMaxDop -SqlServerObject $sqlServerObject

                    Write-Verbose -Message (
                        $script:localizedData.DynamicMaxDop -f $targetMaxDop
                    )
                }
                else
                {
                    $targetMaxDop = $MaxDop
                }
            }

            'Absent'
            {
                $targetMaxDop = 0

                Write-Verbose -Message (
                    $script:localizedData.SettingDefaultValue -f $targetMaxDop
                )
            }
        }

        try
        {
            $sqlServerObject.Configuration.MaxDegreeOfParallelism.ConfigValue = $targetMaxDop
            $sqlServerObject.Alter()

            Write-Verbose -Message (
                $script:localizedData.ChangeValue -f $targetMaxDop
            )
        }
        catch
        {
            $errorMessage = $script:localizedData.MaxDopSetError
            New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
        }
    }
}

<#
    .SYNOPSIS
    This function tests the max degree of parallelism server configuration option.

    .PARAMETER ServerName
    The host name of the SQL Server to be configured.

    .PARAMETER InstanceName
    The name of the SQL instance to be configured.

    .PARAMETER Ensure
    When set to 'Present' then max degree of parallelism will be set to either the value in parameter MaxDop or dynamically configured when parameter DynamicAlloc is set to $true.
    When set to 'Absent' max degree of parallelism will be set to 0 which means no limit in number of processors used in parallel plan execution.

    .PARAMETER DynamicAlloc
    If set to $true then max degree of parallelism will be dynamically configured.
    When this is set parameter is set to $true, the parameter MaxDop must be set to $null or not be configured.

    .PARAMETER MaxDop
    A numeric value to limit the number of processors used in parallel plan execution.

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
        $InstanceName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName = $env:COMPUTERNAME,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.Boolean]
        $DynamicAlloc,

        [Parameter()]
        [System.Int32]
        $MaxDop,

        [Parameter()]
        [System.Boolean]
        $ProcessOnlyOnActiveNode
    )

    Write-Verbose -Message (
        $script:localizedData.EvaluationConfiguration -f $targetMaxDop
    )

    $parameters = @{
        InstanceName = $InstanceName
        ServerName   = $ServerName
    }

    $currentValues = Get-TargetResource @parameters

    $getMaxDop = $currentValues.MaxDop
    $isMaxDopInDesiredState = $true

    <#
        If this is supposed to process only the active node, and this is not the
        active node, don't bother evaluating the test.
    #>
    if ( $ProcessOnlyOnActiveNode -and -not $getTargetResourceResult.IsActiveNode )
    {
        Write-Verbose -Message (
            $script:localizedData.NotActiveNode -f $env:COMPUTERNAME, $InstanceName
        )

        return $isMaxDopInDesiredState
    }

    switch ($Ensure)
    {
        'Absent'
        {
            $defaultMaxDopValue = 0

            if ($getMaxDop -ne $defaultMaxDopValue)
            {
                Write-Verbose -Message (
                    $script:localizedData.WrongMaxDop -f $getMaxDop, $defaultMaxDopValue
                )

                $isMaxDopInDesiredState = $false
            }
        }

        'Present'
        {
            if ($DynamicAlloc)
            {
                if ($MaxDop)
                {
                    $errorMessage = $script:localizedData.MaxDopParamMustBeNull
                    New-InvalidArgumentException -ArgumentName 'MaxDop' -Message $errorMessage
                }

                $MaxDop = Get-SqlDscDynamicMaxDop

                Write-Verbose -Message (
                    $script:localizedData.DynamicMaxDop -f $MaxDop
                )
            }

            if ($getMaxDop -ne $MaxDop)
            {
                Write-Verbose -Message (
                    $script:localizedData.WrongMaxDop -f $getMaxDop, $MaxDop
                )

                $isMaxDopInDesiredState = $false
            }
        }
    }

    $isMaxDopInDesiredState
}

<#
    .SYNOPSIS
    This cmdlet is used to return the dynamic max degree of parallelism
#>
function Get-SqlDscDynamicMaxDop
{
    $cimInstanceProc = Get-CimInstance -ClassName Win32_Processor

    # init variables
    $numberOfLogicalProcessors = 0
    $numberOfCores = 0

    # Loop through returned objects
    foreach ($processor in $cimInstanceProc)
    {
        # increment number of processors
        $numberOfLogicalProcessors += $processor.NumberOfLogicalProcessors

        # increment number of cores
        $numberOfCores += $processor.NumberOfCores
    }


    if ($numberOfLogicalProcessors -eq 1)
    {
        $dynamicMaxDop = [Math]::Round($numberOfCores / 2, [System.MidpointRounding]::AwayFromZero)
    }
    elseif ($numberOfCores -ge 8)
    {
        $dynamicMaxDop = 8
    }
    else
    {
        $dynamicMaxDop = $numberOfCores
    }

    $dynamicMaxDop
}

Export-ModuleMember -Function *-TargetResource
