$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SqlServerDsc.Common'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SqlServerDsc.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_SqlDatabasePermission'

<#
    .SYNOPSIS
    Returns the current permissions for the user in the database

    .PARAMETER Database
    This is the SQL database

    .PARAMETER Name
    This is the name of the SQL login for the permission set

    .PARAMETER PermissionState
    This is the state of permission set. Valid values are 'Grant' or 'Deny'

    .PARAMETER Permissions
    This is a list that represents a SQL Server set of database permissions

    .PARAMETER ServerName
    This is the SQL Server for the database

    .PARAMETER InstanceName
    This is the SQL instance for the database
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
        $Database,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Grant', 'Deny', 'GrantWithGrant')]
        [System.String]
        $PermissionState,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Permissions,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $InstanceName
    )

    Write-Verbose -Message (
        $script:localizedData.GetDatabasePermission -f $Name, $Database, $InstanceName
    )

    $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName
    if ($sqlServerObject)
    {
        $currentEnsure = 'Absent'

        if ($sqlDatabaseObject = $sqlServerObject.Databases[$Database])
        {
            if ($sqlServerObject.Logins[$Name])
            {
                # Initialize variable permission
                [System.String[]] $getSqlDatabasePermissionResult = @()

                try
                {
                    $databasePermissionInfo = $sqlDatabaseObject.EnumDatabasePermissions($Name) | Where-Object -FilterScript {
                        $_.PermissionState -eq $PermissionState
                    }

                    foreach ($currentDatabasePermissionInfo in $databasePermissionInfo)
                    {
                        $permissionProperty = ($currentDatabasePermissionInfo.PermissionType | Get-Member -MemberType Property).Name

                        foreach ($currentPermissionProperty in $permissionProperty)
                        {
                            if ($currentDatabasePermissionInfo.PermissionType."$currentPermissionProperty")
                            {
                                $getSqlDatabasePermissionResult += $currentPermissionProperty
                            }
                        }
                    }
                }
                catch
                {
                    $errorMessage = $script:localizedData.FailedToEnumDatabasePermissions -f $Name, $Database
                    New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
                }

            }
            else
            {
                $errorMessage = $script:localizedData.LoginNotFound -f $Name
                New-ObjectNotFoundException -Message $errorMessage
            }
        }
        else
        {
            $errorMessage = $script:localizedData.DatabaseNotFound -f $Database
            New-ObjectNotFoundException -Message $errorMessage
        }

        if ($getSqlDatabasePermissionResult)
        {
            $resultOfPermissionCompare = Compare-Object -ReferenceObject $Permissions `
                -DifferenceObject $getSqlDatabasePermissionResult
            if ($null -eq $resultOfPermissionCompare)
            {
                $currentEnsure = 'Present'
            }
        }
    }

    return @{
        Ensure          = $currentEnsure
        Database        = $Database
        Name            = $Name
        PermissionState = $PermissionState
        Permissions     = $getSqlDatabasePermissionResult
        ServerName      = $ServerName
        InstanceName    = $InstanceName
    }
}

<#
    .SYNOPSIS
    Sets the permissions for the user in the database.

    .PARAMETER Ensure
    This is The Ensure if the permission should be granted (Present) or revoked (Absent)

    .PARAMETER Database
    This is the SQL database

    .PARAMETER Name
    This is the name of the SQL login for the permission set

    .PARAMETER PermissionState
    This is the state of permission set. Valid values are 'Grant' or 'Deny'

    .PARAMETER Permissions
    This is a list that represents a SQL Server set of database permissions

    .PARAMETER ServerName
    This is the SQL Server for the database

    .PARAMETER InstanceName
    This is the SQL instance for the database
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Database,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Grant', 'Deny', 'GrantWithGrant')]
        [System.String]
        $PermissionState,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Permissions,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName = $env:COMPUTERNAME,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $InstanceName = 'MSSQLSERVER'
    )

    $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName
    if ($sqlServerObject)
    {
        Write-Verbose -Message (
            $script:localizedData.ChangePermissionForUser -f $Name, $Database, $InstanceName
        )

        if ($sqlDatabaseObject = $sqlServerObject.Databases[$Database])
        {
            if ($sqlServerObject.Logins[$Name])
            {
                if ( -not ($sqlDatabaseObject.Users[$Name]))
                {
                    try
                    {
                        Write-Verbose -Message (
                            '{0} {1}' -f
                                ($script:localizedData.LoginIsNotUser -f $Name, $Database),
                                $script:localizedData.AddingLoginAsUser
                        )

                        $sqlDatabaseUser = New-Object -TypeName 'Microsoft.SqlServer.Management.Smo.User' -ArgumentList ($sqlDatabaseObject, $Name)
                        $sqlDatabaseUser.Login = $Name
                        $sqlDatabaseUser.Create()
                    }
                    catch
                    {
                        $errorMessage = $script:localizedData.FailedToAddUser -f $Name, $Database
                        New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
                    }
                }

                if ($sqlDatabaseObject.Users[$Name])
                {
                    try
                    {
                        $permissionSet = New-Object -TypeName 'Microsoft.SqlServer.Management.Smo.DatabasePermissionSet'

                        foreach ($permission in $permissions)
                        {
                            $permissionSet."$permission" = $true
                        }

                        switch ($Ensure)
                        {
                            'Present'
                            {
                                Write-Verbose -Message (
                                    $script:localizedData.AddPermission -f $PermissionState, ($Permissions -join ','), $Database
                                )

                                switch ($PermissionState)
                                {
                                    'GrantWithGrant'
                                    {
                                        $sqlDatabaseObject.Grant($permissionSet, $Name, $true)
                                    }

                                    'Grant'
                                    {
                                        $sqlDatabaseObject.Grant($permissionSet, $Name)
                                    }

                                    'Deny'
                                    {
                                        $sqlDatabaseObject.Deny($permissionSet, $Name)
                                    }
                                }
                            }

                            'Absent'
                            {
                                Write-Verbose -Message (
                                    $script:localizedData.DropPermission -f $PermissionState, ($Permissions -join ','), $Database
                                )

                                if ($PermissionState -eq 'GrantWithGrant')
                                {
                                    $sqlDatabaseObject.Revoke($permissionSet, $Name, $false, $true)
                                }
                                else
                                {
                                    $sqlDatabaseObject.Revoke($permissionSet, $Name)
                                }
                            }
                        }
                    }
                    catch
                    {
                        $errorMessage = $script:localizedData.FailedToSetPermissionDatabase -f $Name, $Database
                        New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
                    }
                }
            }
            else
            {
                $errorMessage = $script:localizedData.LoginNotFound -f $Name
                New-ObjectNotFoundException -Message $errorMessage
            }
        }
        else
        {
            $errorMessage = $script:localizedData.DatabaseNotFound -f $Database
            New-ObjectNotFoundException -Message $errorMessage
        }
    }
}

<#
    .SYNOPSIS
    Tests if the permissions is set for the user in the database

    .PARAMETER Ensure
    This is The Ensure if the permission should be granted (Present) or revoked (Absent)

    .PARAMETER Database
    This is the SQL database

    .PARAMETER Name
    This is the name of the SQL login for the permission set

    .PARAMETER PermissionState
    This is the state of permission set. Valid values are 'Grant' or 'Deny'

    .PARAMETER Permissions
    This is a list that represents a SQL Server set of database permissions

    .PARAMETER ServerName
    This is the SQL Server for the database

    .PARAMETER InstanceName
    This is the SQL instance for the database
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Database,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Grant', 'Deny', 'GrantWithGrant')]
        [System.String]
        $PermissionState,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Permissions,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName = $env:COMPUTERNAME,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $InstanceName = 'MSSQLSERVER'
    )

    Write-Verbose -Message (
        $script:localizedData.TestingConfiguration -f $Name, $Database, $InstanceName
    )

    $getTargetResourceParameters = @{
        InstanceName    = $PSBoundParameters.InstanceName
        ServerName      = $PSBoundParameters.ServerName
        Database        = $PSBoundParameters.Database
        Name            = $PSBoundParameters.Name
        PermissionState = $PSBoundParameters.PermissionState
        Permissions     = $PSBoundParameters.Permissions
    }

    $getTargetResourceResult = Get-TargetResource @getTargetResourceParameters

    <#
        There is no need to evaluate the parameter Permissions here.
        In the Get-TargetResource function there is a test to verify if Permissions is in
        desired state. If the permissions are correct, then Get-TargetResource will return
        the value 'Present' for the Ensure parameter, otherwise Ensure will have the value
        'Absent'.
    #>
    return Test-DscParameterState -CurrentValues $getTargetResourceResult `
        -DesiredValues $PSBoundParameters `
        -ValuesToCheck @('Name', 'Ensure', 'PermissionState')
}

Export-ModuleMember -Function *-TargetResource
