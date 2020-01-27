$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SqlServerDsc.Common'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SqlServerDsc.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_SqlServerEndpointState'

<#
    .SYNOPSIS
        Returns the current state of an endpoint.

    .PARAMETER InstanceName
        The name of the SQL instance to be configured.

    .PARAMETER ServerName
        The host name of the SQL Server to be configured.

    .PARAMETER Name
        The name of the endpoint.
#>
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter()]
        [System.String]
        $ServerName = $env:COMPUTERNAME,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Name
    )

    Write-Verbose -Message (
        $script:localizedData.GetEndpointState -f $Name, $InstanceName
    )

    try
    {
        $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

        $endpointObject = $sqlServerObject.Endpoints[$Name]
        if ($null -ne $endpointObject)
        {
            $currentState = $endpointObject.EndpointState

            Write-Verbose -Message (
                $script:localizedData.CurrentState -f $currentState
            )
        }
        else
        {
            $errorMessage = $script:localizedData.EndpointNotFound -f $Name
            New-ObjectNotFoundException -Message $errorMessage
        }
    }
    catch
    {
        $errorMessage = $script:localizedData.EndpointErrorVerifyExist -f $Name
        New-ObjectNotFoundException -Message $errorMessage -ErrorRecord $_
    }

    return @{
        InstanceName = [System.String] $InstanceName
        ServerName   = [System.String] $ServerName
        Name         = [System.String] $Name
        State        = [System.String] $currentState
    }
}

<#
    .SYNOPSIS
        Changes the state of an endpoint.

    .PARAMETER InstanceName
        The name of the SQL instance to be configured.

    .PARAMETER ServerName
        The host name of the SQL Server to be configured.

    .PARAMETER Name
        The name of the endpoint.

    .PARAMETER State
        The state of the endpoint. Valid states are Started, Stopped or Disabled. Default value is 'Started'.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter()]
        [System.String]
        $ServerName = $env:COMPUTERNAME,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter()]
        [ValidateSet('Started', 'Stopped', 'Disabled')]
        [System.String]
        $State = 'Started'
    )

    Write-Verbose -Message (
        $script:localizedData.SetEndpointState -f $Name, $InstanceName
    )

    $parameters = @{
        InstanceName = [System.String] $InstanceName
        ServerName   = [System.String] $ServerName
        Name         = [System.String] $Name
    }

    $getTargetResourceResult = Get-TargetResource @parameters
    if ($null -ne $getTargetResourceResult)
    {
        if ($getTargetResourceResult.State -ne $State)
        {
            Write-Verbose -Message (
                $script:localizedData.ChangeState -f $State
            )

            $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

            $endpointObject = $sqlServerObject.Endpoints[$Name]

            $setEndpointParams = @{
                InputObject = $endpointObject
                State       = $State
            }

            Set-SqlHADREndpoint @setEndpointParams -ErrorAction 'Stop' | Out-Null
        }
        else
        {
            Write-Verbose -Message (
                $script:localizedData.InDesiredState -f $Name, $State
            )
        }
    }
    else
    {
        $errorMessage = $script:localizedData.UnexpectedErrorFromGet
        New-InvalidResultException -Message $errorMessage
    }
}

<#
    .SYNOPSIS
        Tests the state of an endpoint if it is in desired state.

    .PARAMETER InstanceName
        The name of the SQL instance to be configured.

    .PARAMETER ServerName
        The host name of the SQL Server to be configured.

    .PARAMETER Name
        The name of the endpoint.

    .PARAMETER State
        The state of the endpoint. Valid states are Started, Stopped or Disabled. Default value is 'Started'.
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter()]
        [System.String]
        $ServerName = $env:COMPUTERNAME,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter()]
        [ValidateSet('Started', 'Stopped', 'Disabled')]
        [System.String]
        $State = 'Started'
    )

    Write-Verbose -Message (
        $script:localizedData.TestingConfiguration -f $Name, $InstanceName
    )

    $parameters = @{
        InstanceName = $InstanceName
        ServerName   = $ServerName
        Name         = $Name
    }

    $getTargetResourceResult = Get-TargetResource @parameters
    if ($null -ne $getTargetResourceResult)
    {
        if ($getTargetResourceResult.State -eq $State)
        {
            Write-Verbose -Message (
                $script:localizedData.InDesiredState -f $Name, $getTargetResourceResult.State
            )

            $result = $true
        }
        else
        {
            Write-Verbose -Message (
                $script:localizedData.NotInDesiredState -f $Name, $getTargetResourceResult.State, $State
            )

            $result = $false
        }
    }
    else
    {
        $errorMessage = $script:localizedData.UnexpectedErrorFromGet
        New-InvalidResultException -Message $errorMessage
    }

    return $result
}

Export-ModuleMember -Function *-TargetResource
