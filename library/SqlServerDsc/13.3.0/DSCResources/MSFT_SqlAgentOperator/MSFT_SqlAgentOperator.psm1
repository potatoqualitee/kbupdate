$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SqlServerDsc.Common'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SqlServerDsc.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_SqlAgentOperator'

<#
    .SYNOPSIS
    This function gets the SQL Agent Operator.

    .PARAMETER Name
    The name of the SQL Agent Operator.

    .PARAMETER ServerName
    The host name of the SQL Server to be configured. Default is $env:COMPUTERNAME.

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
        $Name,

        [Parameter()]
        [System.String]
        $ServerName = $env:COMPUTERNAME,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $InstanceName

    )

    $returnValue = @{
        Name         = $null
        Ensure       = 'Absent'
        ServerName   = $ServerName
        InstanceName = $InstanceName
        EmailAddress = $null
    }

    $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

    if ($sqlServerObject)
    {
        Write-Verbose -Message (
            $script:localizedData.GetSqlAgents
        )
        # Check operator exists
        $sqlOperatorObject = $sqlServerObject.JobServer.Operators | Where-Object {$_.Name -eq $Name}
        if ($sqlOperatorObject)
        {
            Write-Verbose -Message (
                $script:localizedData.SqlAgentPresent `
                    -f $Name
            )
            $returnValue['Ensure'] = 'Present'
            $returnValue['Name'] = $sqlOperatorObject.Name
            $returnValue['EmailAddress'] = $sqlOperatorObject.EmailAddress
        }
        else
        {
            Write-Verbose -Message (
                $script:localizedData.SqlAgentAbsent `
                    -f $Name
            )
        }
    }
    else
    {
        $errorMessage = $script:localizedData.ConnectServerFailed -f $ServerName, $InstanceName
        New-InvalidOperationException -Message $errorMessage
    }

    return $returnValue
}

<#
    .SYNOPSIS
    This function sets the SQL Agent Operator.

    .PARAMETER Ensure
    Specifies if the SQL Agent Operator should be present or absent. Default is Present

    .PARAMETER Name
    The name of the SQL Agent Operator.

    .PARAMETER ServerName
    The host name of the SQL Server to be configured. Default is $env:COMPUTERNAME.

    .PARAMETER InstanceName
    The name of the SQL instance to be configured.

    .PARAMETER EmailAddress
    The email address to be used for the SQL Agent Operator.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [Parameter()]
        [System.String]
        $ServerName = $env:COMPUTERNAME,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $InstanceName,

        [Parameter()]
        [System.String]
        $EmailAddress
    )

    $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

    if ($sqlServerObject)
    {
        switch ($Ensure)
        {
            'Present'
            {
                $sqlOperatorObject = $sqlServerObject.JobServer.Operators | Where-Object {$_.Name -eq $Name}

                if ($sqlOperatorObject)
                {
                    if ($PSBoundParameters.ContainsKey('EmailAddress'))
                    {
                        try
                        {
                            Write-Verbose -Message (
                                $script:localizedData.UpdateEmailAddress `
                                    -f $EmailAddress, $Name
                            )
                            $sqlOperatorObject.EmailAddress = $EmailAddress
                            $sqlOperatorObject.Alter()
                        }
                        catch
                        {
                            $errorMessage = $script:localizedData.UpdateOperatorSetError -f $ServerName, $InstanceName, $Name, $EmailAddress
                            New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
                        }
                    }
                }
                else
                {
                    try
                    {
                        $sqlOperatorObjectToCreate = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Agent.Operator -ArgumentList $sqlServerObject.JobServer, $Name

                        if ($sqlOperatorObjectToCreate)
                        {
                            Write-Verbose -Message (
                                $script:localizedData.AddSqlAgentOperator `
                                    -f $Name
                            )
                            if ($PSBoundParameters.ContainsKey('EmailAddress'))
                            {
                                Write-Verbose -Message (
                                    $script:localizedData.UpdateEmailAddress `
                                        -f $EmailAddress, $Name
                                )
                                $sqlOperatorObjectToCreate.EmailAddress = $EmailAddress
                            }
                            $sqlOperatorObjectToCreate.Create()
                        }
                    }
                    catch
                    {
                        $errorMessage = $script:localizedData.CreateOperatorSetError -f $Name, $ServerName, $InstanceName
                        New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
                    }
                }
            }

            'Absent'
            {
                try
                {
                    $sqlOperatorObjectToDrop = $sqlServerObject.JobServer.Operators | Where-Object {$_.Name -eq $Name}
                    if ($sqlOperatorObjectToDrop)
                    {
                        Write-Verbose -Message (
                            $script:localizedData.DeleteSqlAgentOperator `
                                -f $Name
                        )
                        $sqlOperatorObjectToDrop.Drop()
                    }
                }
                catch
                {
                    $errorMessage = $script:localizedData.DropOperatorSetError -f $Name, $ServerName, $InstanceName
                    New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
                }
            }
        }
    }
    else
    {
        $errorMessage = $script:localizedData.ConnectServerFailed -f $ServerName, $InstanceName
        New-InvalidOperationException -Message $errorMessage
    }
}

<#
    .SYNOPSIS
    This function tests the SQL Agent Operator.

    .PARAMETER Ensure
    Specifies if the SQL Agent Operator should be present or absent. Default is Present

    .PARAMETER Name
    The name of the SQL Agent Operator.

    .PARAMETER ServerName
    The host name of the SQL Server to be configured. Default is $env:COMPUTERNAME.

    .PARAMETER InstanceName
    The name of the SQL instance to be configured.

    .PARAMETER EmailAddress
    The email address to be used for the SQL Agent Operator.
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [Parameter()]
        [System.String]
        $ServerName = $env:COMPUTERNAME,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $InstanceName,

        [Parameter()]
        [System.String]
        $EmailAddress
    )

    Write-Verbose -Message (
        $script:localizedData.TestSqlAgentOperator `
            -f $Name
    )

    $getTargetResourceParameters = @{
        Name           = $Name
        ServerName     = $ServerName
        InstanceName   = $InstanceName
    }

    $getTargetResourceResult = Get-TargetResource @getTargetResourceParameters
    $isOperatorInDesiredState = $true

    switch ($Ensure)
    {
        'Absent'
        {
            if ($getTargetResourceResult.Ensure -ne 'Absent')
            {
                Write-Verbose -Message (
                    $script:localizedData.SqlAgentOperatorExistsButShouldNot `
                        -f $Name
                )
                $isOperatorInDesiredState = $false
            }
        }

        'Present'
        {
            if ($getTargetResourceResult.EmailAddress -ne $EmailAddress -and $PSBoundParameters.ContainsKey('EmailAddress'))
            {
                Write-Verbose -Message (
                    $script:localizedData.SqlAgentOperatorExistsButEmailWrong `
                        -f $Name, $getTargetResourceResult.EmailAddress, $EmailAddress
                )
                $isOperatorInDesiredState = $false
            }
            elseif ($getTargetResourceResult.Ensure -ne 'Present')
            {
                Write-Verbose -Message (
                    $script:localizedData.SqlAgentOperatorDoesNotExistButShould `
                        -f $Name
                )
                $isOperatorInDesiredState = $false
            }
        }
    }
    $isOperatorInDesiredState
}

Export-ModuleMember -Function *-TargetResource
