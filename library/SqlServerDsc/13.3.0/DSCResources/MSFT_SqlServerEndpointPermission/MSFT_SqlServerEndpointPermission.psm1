$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SqlServerDsc.Common'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SqlServerDsc.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_SqlServerEndpointPermission'

<#
    .SYNOPSIS
        Returns the current state of the permissions for the principal (login).

    .PARAMETER InstanceName
        The name of the SQL instance to be configured.

    .PARAMETER ServerName
        The host name of the SQL Server to be configured.

    .PARAMETER Name
        The name of the endpoint.

    .PARAMETER Principal
        The login to which permission will be set.
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

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Principal
    )

    Write-Verbose -Message (
        $script:localizedData.GetEndpointPermission -f $EndpointName, $InstanceName
    )

    try
    {
        $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

        $endpointObject = $sqlServerObject.Endpoints[$Name]
        if ( $null -ne $endpointObject )
        {
            $permissionSet = New-Object -TypeName 'Microsoft.SqlServer.Management.Smo.ObjectPermissionSet' -Property @{
                Connect = $true
            }

            $endpointPermission = $endpointObject.EnumObjectPermissions($permissionSet) | Where-Object -FilterScript {
                $_.PermissionState -eq 'Grant' -and $_.Grantee -eq $Principal
            }

            if ($endpointPermission.Count -ne 0)
            {
                $Ensure = 'Present'
                $Permission = 'CONNECT'
            }
            else
            {
                $Ensure = 'Absent'
                $Permission = ''
            }
        }
        else
        {
            $errorMessage = $script:localizedData.EndpointNotFound -f $Name
            New-ObjectNotFoundException -Message $errorMessage
        }
    }
    catch
    {
        $errorMessage = $script:localizedData.UnexpectedErrorFromGet -f $Name
        New-ObjectNotFoundException -Message $errorMessage -ErrorRecord $_
    }

    return @{
        InstanceName = [System.String] $InstanceName
        ServerName   = [System.String] $ServerName
        Ensure       = [System.String] $Ensure
        Name         = [System.String] $Name
        Principal    = [System.String] $Principal
        Permission   = [System.String] $Permission
    }
}

<#
    .SYNOPSIS
        Grants or revokes the permission for the the principal (login).

    .PARAMETER InstanceName
        The name of the SQL instance to be configured.

    .PARAMETER ServerName
        The host name of the SQL Server to be configured.

    .PARAMETER Ensure
        If the permission should be present or absent. Default value is 'Present'.

    .PARAMETER Name
        The name of the endpoint.

    .PARAMETER Permission
        The permission to set for the login. Valid value for permission are only CONNECT.

    .PARAMETER Principal
        The permission to set for the login.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Principal,

        [Parameter()]
        [ValidateSet('CONNECT')]
        [System.String]
        $Permission
    )

    $parameters = @{
        InstanceName = [System.String] $InstanceName
        ServerName   = [System.String] $ServerName
        Name         = [System.String] $Name
        Principal    = [System.String] $Principal
    }

    $getTargetResourceResult = Get-TargetResource @parameters
    if ($getTargetResourceResult.Ensure -ne $Ensure)
    {
        Write-Verbose -Message (
            $script:localizedData.SetEndpointPermission -f $EndpointName, $InstanceName
        )

        $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

        $endpointObject = $sqlServerObject.Endpoints[$Name]
        if ($null -ne $endpointObject)
        {
            $permissionSet = New-Object -TypeName 'Microsoft.SqlServer.Management.Smo.ObjectPermissionSet' -Property @{
                Connect = $true
            }

            if ($Ensure -eq 'Present')
            {
                Write-Verbose -Message (
                    $script:localizedData.GrantPermission -f $Principal
                )

                $endpointObject.Grant($permissionSet, $Principal)
            }
            else
            {
                Write-Verbose -Message (
                    $script:localizedData.RevokePermission -f $Principal
                )

                $endpointObject.Revoke($permissionSet, $Principal)
            }
        }
        else
        {
            $errorMessage = $script:localizedData.EndpointNotFound -f $Name
            New-ObjectNotFoundException -Message $errorMessage
        }
    }
    else
    {
        Write-Verbose -Message (
            $script:localizedData.InDesiredState -f $Name
        )
    }
}

<#
    .SYNOPSIS
        Tests if the principal (login) has the desired permissions.

    .PARAMETER InstanceName
        The name of the SQL instance to be configured.

    .PARAMETER ServerName
        The host name of the SQL Server to be configured.

    .PARAMETER Ensure
        If the permission should be present or absent. Default value is 'Present'.

    .PARAMETER Name
        The name of the endpoint.

    .PARAMETER Permission
        The permission to set for the login. Valid value for permission are only CONNECT.

    .PARAMETER Principal
        The permission to set for the login.
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

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Principal,

        [Parameter()]
        [ValidateSet('CONNECT')]
        [System.String]
        $Permission
    )

    $parameters = @{
        InstanceName = [System.String] $InstanceName
        ServerName   = [System.String] $ServerName
        Name         = [System.String] $Name
        Principal    = [System.String] $Principal
    }

    Write-Verbose -Message (
        $script:localizedData.TestingConfiguration -f $Name, $InstanceName
    )

    $getTargetResourceResult = Get-TargetResource @parameters

    $isInDesiredState = $getTargetResourceResult.Ensure -eq $Ensure

    if ($isInDesiredState)
    {
        Write-Verbose -Message (
            $script:localizedData.InDesiredState -f $Name
        )
    }
    else
    {
        Write-Verbose -Message (
            $script:localizedData.NotInDesiredState -f $Name
        )
    }

    return $isInDesiredState
}

Export-ModuleMember -Function *-TargetResource
