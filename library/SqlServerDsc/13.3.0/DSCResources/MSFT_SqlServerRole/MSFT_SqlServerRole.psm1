$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SqlServerDsc.Common'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SqlServerDsc.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_SqlServerRole'

<#
    .SYNOPSIS
    This function gets the sql server role properties.

    .PARAMETER Members
    The members the server role should have.

    .PARAMETER MembersToInclude
    The members the server role should include.

    .PARAMETER MembersToExclude
    The members the server role should exclude.

    .PARAMETER ServerRoleName
    The name of server role to be created or dropped.

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
        [Parameter()]
        [System.String[]]
        $Members,

        [Parameter()]
        [System.String[]]
        $MembersToInclude,

        [Parameter()]
        [System.String[]]
        $MembersToExclude,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerRoleName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $InstanceName
    )

    $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName
    $ensure = 'Present'

    if ($sqlServerObject)
    {
        Write-Verbose -Message (
            $script:localizedData.GetProperties `
                -f $ServerRoleName
        )

        if ($sqlServerRoleObject = $sqlServerObject.Roles[$ServerRoleName])
        {
            try
            {
                [System.String[]] $membersInRole = $sqlServerRoleObject.EnumMemberNames()
            }
            catch
            {
                $errorMessage = $script:localizedData.EnumMemberNamesServerRoleGetError `
                    -f $ServerName, $InstanceName, $ServerRoleName

                New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
            }

            if ($Members)
            {
                if ($MembersToInclude -or $MembersToExclude)
                {
                    $errorMessage = $script:localizedData.MembersToIncludeAndExcludeParamMustBeNull
                    New-InvalidOperationException -Message $errorMessage
                }

                if ( $null -ne (Compare-Object -ReferenceObject $membersInRole -DifferenceObject $Members))
                {
                    Write-Verbose -Message (
                        $script:localizedData.DesiredMembersNotPresent `
                            -f $ServerRoleName
                    )

                    $ensure = 'Absent'
                }
            }
            else
            {
                if ($MembersToInclude)
                {
                    foreach ($memberToInclude in $MembersToInclude)
                    {
                        if ($membersInRole -notcontains $memberToInclude)
                        {
                            Write-Verbose -Message (
                                $script:localizedData.MemberNotPresent `
                                    -f $ServerRoleName, $memberToInclude
                            )

                            $ensure = 'Absent'
                        }
                    }
                }

                if ($MembersToExclude)
                {
                    foreach ($memberToExclude in $MembersToExclude)
                    {
                        if ($membersInRole -contains $memberToExclude)
                        {
                            Write-Verbose -Message (
                                $script:localizedData.MemberPresent `
                                    -f $ServerRoleName, $memberToExclude
                            )

                            $ensure = 'Absent'
                        }
                    }
                }
            }
        }
        else
        {
            $ensure = 'Absent'
        }
    }

    $returnValue = @{
        Ensure           = $ensure
        Members          = $membersInRole
        MembersToInclude = $MembersToInclude
        MembersToExclude = $MembersToExclude
        ServerRoleName   = $ServerRoleName
        ServerName       = $ServerName
        InstanceName     = $InstanceName
    }
    $returnValue
}

<#
    .SYNOPSIS
    This function sets the sql server role properties.

    .PARAMETER Ensure
    When set to 'Present', the server role will be created.
    When set to 'Absent', the server role will be dropped.

    .PARAMETER Members
    The members the server role should have.

    .PARAMETER MembersToInclude
    The members the server role should include.

    .PARAMETER MembersToExclude
    The members the server role should exclude.

    .PARAMETER ServerRoleName
    The name of server role to be created or dropped.

    .PARAMETER ServerName
    The host name of the SQL Server to be configured.

    .PARAMETER InstanceName
    The name of the SQL instance to be configured.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.String[]]
        $Members,

        [Parameter()]
        [System.String[]]
        $MembersToInclude,

        [Parameter()]
        [System.String[]]
        $MembersToExclude,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerRoleName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $InstanceName
    )

    $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

    if ($sqlServerObject)
    {
        Write-Verbose -Message (
            $script:localizedData.SetProperties `
                -f $ServerRoleName
        )

        switch ($Ensure)
        {
            'Absent'
            {
                try
                {
                    $sqlServerRoleObjectToDrop = $sqlServerObject.Roles[$ServerRoleName]
                    if ($sqlServerRoleObjectToDrop)
                    {
                        Write-Verbose -Message (
                            $script:localizedData.DropRole `
                                -f $ServerRoleName
                        )

                        $sqlServerRoleObjectToDrop.Drop()
                    }
                }
                catch
                {
                    $errorMessage = $script:localizedData.DropServerRoleSetError `
                        -f $ServerName, $InstanceName, $ServerRoleName

                    New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
                }
            }

            'Present'
            {
                if ($null -eq $sqlServerObject.Roles[$ServerRoleName])
                {
                    try
                    {
                        $sqlServerRoleObjectToCreate = New-Object -TypeName Microsoft.SqlServer.Management.Smo.ServerRole `
                            -ArgumentList $sqlServerObject, $ServerRoleName
                        if ($sqlServerRoleObjectToCreate)
                        {
                            Write-Verbose -Message (
                                $script:localizedData.CreateRole `
                                    -f $ServerRoleName
                            )

                            $sqlServerRoleObjectToCreate.Create()
                        }
                    }
                    catch
                    {
                        $errorMessage = $script:localizedData.CreateServerRoleSetError `
                            -f $ServerName, $InstanceName, $ServerRoleName

                        New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
                    }
                }

                if ($Members)
                {
                    if ($MembersToInclude -or $MembersToExclude)
                    {
                        $errorMessage = $script:localizedData.MembersToIncludeAndExcludeParamMustBeNull
                        New-InvalidOperationException -Message $errorMessage
                    }

                    $memberNamesInRoleObject = $sqlServerObject.Roles[$ServerRoleName].EnumMemberNames()

                    foreach ($memberName in $memberNamesInRoleObject)
                    {
                        if ($Members -notcontains $memberName)
                        {
                            Remove-SqlDscServerRoleMember -SqlServerObject $sqlServerObject `
                                -SecurityPrincipal $memberName `
                                -ServerRoleName $ServerRoleName
                        }
                    }

                    foreach ($memberToAdd in $Members)
                    {
                        if ($memberNamesInRoleObject -notcontains $memberToAdd)
                        {
                            Add-SqlDscServerRoleMember -SqlServerObject $sqlServerObject `
                                -SecurityPrincipal $memberToAdd `
                                -ServerRoleName $ServerRoleName
                        }
                    }
                }
                else
                {
                    if ($MembersToInclude)
                    {
                        $memberNamesInRoleObject = $sqlServerObject.Roles[$ServerRoleName].EnumMemberNames()

                        foreach ($memberToInclude in $MembersToInclude)
                        {
                            if ($memberNamesInRoleObject -notcontains $memberToInclude)
                            {
                                Add-SqlDscServerRoleMember -SqlServerObject $sqlServerObject `
                                    -SecurityPrincipal $memberToInclude `
                                    -ServerRoleName $ServerRoleName
                            }
                        }
                    }

                    if ($MembersToExclude)
                    {
                        $memberNamesInRoleObject = $sqlServerObject.Roles[$ServerRoleName].EnumMemberNames()

                        foreach ($memberToExclude in $MembersToExclude)
                        {
                            if ($memberNamesInRoleObject -contains $memberToExclude)
                            {
                                Remove-SqlDscServerRoleMember -SqlServerObject $sqlServerObject `
                                    -SecurityPrincipal $memberToExclude `
                                    -ServerRoleName $ServerRoleName
                            }
                        }
                    }
                }
            }
        }
    }
}

<#
    .SYNOPSIS
    This function tests the sql server role properties.

    .PARAMETER Ensure
    When set to 'Present', the server role will be created.
    When set to 'Absent', the server role will be dropped.

    .PARAMETER Members
    The members the server role should have.

    .PARAMETER MembersToInclude
    The members the server role should include.

    .PARAMETER MembersToExclude
    The members the server role should exclude.

    .PARAMETER ServerRoleName
    The name of server role to be created or dropped.

    .PARAMETER ServerName
    The host name of the SQL Server to be configured.

    .PARAMETER InstanceName
    The name of the SQL instance to be configured.
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
        $Ensure = 'Present',

        [Parameter()]
        [System.String[]]
        $Members,

        [Parameter()]
        [System.String[]]
        $MembersToInclude,

        [Parameter()]
        [System.String[]]
        $MembersToExclude,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerRoleName,

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
        $script:localizedData.TestProperties `
            -f $ServerRoleName
    )

    $getTargetResourceParameters = @{
        InstanceName     = $PSBoundParameters.InstanceName
        ServerName       = $PSBoundParameters.ServerName
        ServerRoleName   = $PSBoundParameters.ServerRoleName
        Members          = $PSBoundParameters.Members
        MembersToInclude = $PSBoundParameters.MembersToInclude
        MembersToExclude = $PSBoundParameters.MembersToExclude
    }

    $getTargetResourceResult = Get-TargetResource @getTargetResourceParameters
    $isServerRoleInDesiredState = $true

    switch ($Ensure)
    {
        'Absent'
        {
            if ($getTargetResourceResult.Ensure -ne 'Absent')
            {
                Write-Verbose -Message (
                    $script:localizedData.EnsureIsAbsent `
                        -f $ServerRoleName
                )

                $isServerRoleInDesiredState = $false
            }
        }

        'Present'
        {
            if ($getTargetResourceResult.Ensure -ne 'Present')
            {
                Write-Verbose -Message (
                    $script:localizedData.EnsureIsPresent `
                        -f $ServerRoleName
                )

                $isServerRoleInDesiredState = $false
            }
        }
    }

    $isServerRoleInDesiredState
}

<#
    .SYNOPSIS
        Add a user to a server role in the SQL Server instance provided.

    .PARAMETER SqlServerObject
        An object returned from Connect-SQL function.

    .PARAMETER SecurityPrincipal
        String containing the login (user) which should be added as a member to the server role.

    .PARAMETER ServerRoleName
        String containing the name of the server role which the user will be added as a member to.
#>
function Add-SqlDscServerRoleMember
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Object]
        $SqlServerObject,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $SecurityPrincipal,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerRoleName
    )

    try
    {
        Test-SqlSecurityPrincipal -SqlServerObject $SqlServerObject -SecurityPrincipal $SecurityPrincipal

        Write-Verbose -Message (
            $script:localizedData.AddMemberToRole `
                -f $SecurityPrincipal, $ServerRoleName
        )

        $SqlServerObject.Roles[$ServerRoleName].AddMember($SecurityPrincipal)
    }
    catch
    {
        $errorMessage = $script:localizedData.AddMemberServerRoleSetError `
            -f $ServerName, $InstanceName, $ServerRoleName, $SecurityPrincipal

        New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
    }
}

<#
    .SYNOPSIS
        Remove a user in a server role in the SQL Server instance provided.

    .PARAMETER SqlServerObject
        An object returned from Connect-SQL function.

    .PARAMETER SecurityPrincipal
        String containing the login (user) which should be removed as a member in the server role.

    .PARAMETER ServerRoleName
        String containing the name of the server role for which the user will be removed as a member.
#>
function Remove-SqlDscServerRoleMember
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Object]
        $SqlServerObject,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $SecurityPrincipal,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerRoleName
    )

    try
    {
        # Determine whether a valid principal has been supplied
        Test-SqlSecurityPrincipal -SqlServerObject $SqlServerObject -SecurityPrincipal $SecurityPrincipal

        Write-Verbose -Message (
            $script:localizedData.RemoveMemberFromRole `
                -f $SecurityPrincipal, $ServerRoleName
        )

        $SqlServerObject.Roles[$ServerRoleName].DropMember($SecurityPrincipal)
    }
    catch
    {
        $errorMessage = $script:localizedData.DropMemberServerRoleSetError `
            -f $ServerName, $InstanceName, $ServerRoleName, $SecurityPrincipal

        New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
    }
}

<#
    .SYNOPSIS
        Tests whether a security principal is valid on the specified SQL Server instance.

    .PARAMETER SqlServerObject
        The object returned from the Connect-SQL function.

    .PARAMETER SecurityPrincipal
        String containing the name of the principal to validate.
#>
function Test-SqlSecurityPrincipal
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Object]
        $SqlServerObject,

        [Parameter(Mandatory = $true)]
        [System.String]
        $SecurityPrincipal
    )

    if ($SqlServerObject.Logins.Name -notcontains $SecurityPrincipal)
    {
        if ($SqlServerObject.Roles.Name -notcontains $SecurityPrincipal)
        {
            $errorMessage = $script:localizedData.SecurityPrincipalNotFound -f (
                $SecurityPrincipal,
                $($SqlServerObject.Name)
            )

            # Principal is neither a Login nor a Server role, raise exception
            New-ObjectNotFoundException -Message $errorMessage

            return $false
        }
    }

    return $true
}

Export-ModuleMember -Function *-TargetResource
