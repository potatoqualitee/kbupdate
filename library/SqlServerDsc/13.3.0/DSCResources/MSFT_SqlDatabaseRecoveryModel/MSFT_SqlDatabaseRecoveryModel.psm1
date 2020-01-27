$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SqlServerDsc.Common'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SqlServerDsc.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_SqlDatabaseRecoveryModel'

<#
    .SYNOPSIS
    This function gets all Key properties defined in the resource schema file

    .PARAMETER Name
    This is the SQL database

    .PARAMETER RecoveryModel
    This is the RecoveryModel of the SQL database

    .PARAMETER ServerName
    This is a the SQL Server for the database

    .PARAMETER InstanceName
    This is a the SQL instance for the database
#>
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Full', 'Simple', 'BulkLogged')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $RecoveryModel,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name
    )

    Write-Verbose -Message (
        $script:localizedData.GetRecoveryModel -f $Name, $InstanceName
    )

    $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName
    if ($sqlServerObject)
    {
        $sqlDatabaseObject = $sqlServerObject.Databases[$Name]
        if ($sqlDatabaseObject)
        {
            $sqlDatabaseRecoveryModel = $sqlDatabaseObject.RecoveryModel

            Write-Verbose -Message (
                $script:localizedData.CurrentRecoveryModel -f $sqlDatabaseRecoveryModel, $Name
            )
        }
        else
        {
            $errorMessage = $script:localizedData.DatabaseNotFound -f $Name
            New-InvalidResultException -Message $errorMessage
        }
    }

    return @{
        Name          = $Name
        RecoveryModel = $sqlDatabaseRecoveryModel
        ServerName    = $ServerName
        InstanceName  = $InstanceName
    }
}

<#
    .SYNOPSIS
    This function gets all Key properties defined in the resource schema file

    .PARAMETER Name
    This is the SQL database

    .PARAMETER RecoveryModel
    This is the RecoveryModel of the SQL database

    .PARAMETER ServerName
    This is a the SQL Server for the database

    .PARAMETER InstanceName
    This is a the SQL instance for the database
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Full', 'Simple', 'BulkLogged')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $RecoveryModel,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name
    )

    $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName
    if ($sqlServerObject)
    {
        Write-Verbose -Message (
            $script:localizedData.SetRecoveryModel -f $Name
        )

        $sqlDatabaseObject = $sqlServerObject.Databases[$Name]
        if ($sqlDatabaseObject)
        {
            if ($sqlDatabaseObject.RecoveryModel -ne $RecoveryModel)
            {
                $sqlDatabaseObject.RecoveryModel = $RecoveryModel
                $sqlDatabaseObject.Alter()

                Write-Verbose -Message (
                    $script:localizedData.ChangeRecoveryModel -f $Name, $RecoveryModel
                )
            }
        }
        else
        {
            $errorMessage = $script:localizedData.DatabaseNotFound -f $Name
            New-InvalidResultException -Message $errorMessage
        }
    }
}

<#
    .SYNOPSIS
    This function gets all Key properties defined in the resource schema file

    .PARAMETER Name
    This is the SQL database

    .PARAMETER RecoveryModel
    This is the RecoveryModel of the SQL database

    .PARAMETER ServerName
    This is a the SQL Server for the database

    .PARAMETER InstanceName
    This is a the SQL instance for the database
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Full', 'Simple', 'BulkLogged')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $RecoveryModel,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name
    )

    Write-Verbose -Message (
        $script:localizedData.TestingConfiguration -f $Name, $InstanceName
    )

    $currentValues = Get-TargetResource @PSBoundParameters

    return Test-DscParameterState -CurrentValues $currentValues `
        -DesiredValues $PSBoundParameters `
        -ValuesToCheck @('Name', 'RecoveryModel')
}

Export-ModuleMember -Function *-TargetResource
