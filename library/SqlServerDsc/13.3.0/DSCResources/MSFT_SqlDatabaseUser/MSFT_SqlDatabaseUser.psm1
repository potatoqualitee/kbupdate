$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SqlServerDsc.Common'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SqlServerDsc.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_SqlDatabaseUser'

<#
    .SYNOPSIS
        Returns the current state of the database user in a database.

    .PARAMETER Name
        Specifies the name of the database user to be added or removed.

    .PARAMETER ServerName
        Specifies the host name of the SQL Server on which the instance exist.

    .PARAMETER InstanceName
        Specifies the SQL instance in which the database exist.

    .PARAMETER DatabaseName
        Specifies the name of the database in which to configure the database user.
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

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $DatabaseName
    )

    $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

    Write-Verbose -Message (
        $script:localizedData.RetrievingDatabaseUser -f $Name, $DatabaseName
    )

    $returnValue = @{
        Ensure             = 'Absent'
        Name               = $Name
        ServerName         = $ServerName
        InstanceName       = $InstanceName
        DatabaseName       = $DatabaseName
        LoginName          = $null
        AsymmetricKeyName  = $null
        CertificateName    = $null
        UserType           = $null
        AuthenticationType = $null
        LoginType          = $null
    }

    # Check if database exists.
    $sqlDatabaseObject = $sqlServerObject.Databases[$DatabaseName]

    if ($sqlDatabaseObject)
    {
        $sqlUserObject = $sqlDatabaseObject.Users[$Name]

        if ($sqlUserObject)
        {
            Write-Verbose -Message (
                $script:localizedData.DatabaseUserExist -f $Name, $DatabaseName
            )

            $returnValue['Ensure'] = 'Present'
            $returnValue['LoginName'] = $sqlUserObject.Login
            $returnValue['AsymmetricKeyName'] = $sqlUserObject.AsymmetricKey
            $returnValue['CertificateName'] = $sqlUserObject.Certificate
            $returnValue['AuthenticationType'] = $sqlUserObject.AuthenticationType
            $returnValue['LoginType'] = $sqlUserObject.LoginType
            $returnValue['UserType'] = ConvertTo-UserType -AuthenticationType $sqlUserObject.AuthenticationType -LoginType $sqlUserObject.LoginType
        }
        else
        {
            Write-Verbose -Message (
                $script:localizedData.DatabaseUserDoesNotExist -f $Name, $DatabaseName
            )
        }
    }
    else
    {
        $errorMessage = $script:localizedData.DatabaseNotFound -f $DatabaseName
        New-ObjectNotFoundException -Message $errorMessage
    }

    return $returnValue
}

<#
    .SYNOPSIS
        Creates, removes or updates a database user in a database.

    .PARAMETER Name
        Specifies the name of the database user to be added or removed.

    .PARAMETER ServerName
        Specifies the host name of the SQL Server on which the instance exist.

    .PARAMETER InstanceName
        Specifies the SQL instance in which the database exist.

    .PARAMETER DatabaseName
        Specifies the name of the database in which to configure the database user.

    .PARAMETER LoginName
        Specifies the name of the SQL login to associate with the database user.
        This must be specified if parameter UserType is set to 'Login'.

    .PARAMETER AsymmetricKeyName
        Specifies the name of the asymmetric key to associate with the database
        user. This must be specified if parameter UserType is set to 'AsymmetricKey'.

    .PARAMETER CertificateName
        Specifies the name of the certificate to associate with the database
        user. This must be specified if parameter UserType is set to 'Certificate'.

    .PARAMETER UserType
        Specifies the type of the database user. Valid values are 'Login',
        'NoLogin', 'Certificate', or 'AsymmetricKey'. Defaults to 'NoLogin'.

    .PARAMETER Ensure
        Specifies if the database user should be present or absent. If 'Present'
        then the user will be added to the database and, if needed, the login
        mapping will be updated. If 'Absent' then the user will be removed from
        the database. Defaults to 'Present'.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $DatabaseName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $LoginName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $AsymmetricKeyName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CertificateName,

        [Parameter()]
        [ValidateSet(
            'Login',
            'NoLogin',
            'Certificate',
            'AsymmetricKey'
        )]
        [System.String]
        $UserType = 'NoLogin',

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.Boolean]
        $Force = $false
    )

    Assert-Parameters @PSBoundParameters

    Write-Verbose -Message (
        $script:localizedData.SetDatabaseUser -f $Name, $DatabaseName
    )

    $getTargetResourceParameters = @{
        ServerName   = $ServerName
        InstanceName = $InstanceName
        Database     = $DatabaseName
        Name         = $Name
    }

    # Get-TargetResource will also help us to test if the database exist.
    $getTargetResourceResult = Get-TargetResource @getTargetResourceParameters

    # Default parameters for the cmdlet Invoke-Query used throughout.
    $invokeQueryParameters = @{
        ServerName   = $ServerName
        InstanceName = $InstanceName
        Database     = $DatabaseName
    }

    $recreateDatabaseUser = $false

    if ($getTargetResourceResult.Ensure -eq $Ensure)
    {
        if ($Ensure -eq 'Present')
        {
            # Update database user properties, if needed.
            if ($UserType -eq $getTargetResourceResult.UserType)
            {
                switch ($UserType)
                {
                    'Login'
                    {
                        if ($getTargetResourceResult.LoginName -ne $LoginName)
                        {
                            Write-Verbose -Message (
                                $script:localizedData.ChangingLoginName -f $Name, $LoginName
                            )

                            # Assert that the login exist.
                            Assert-SqlLogin @PSBoundParameters

                            try
                            {
                                <#
                                    Must provide 'WITH NAME' and set to the same name, otherwise
                                    the database user could be renamed in certain conditions.
                                    See remarks section in this article:
                                    https://docs.microsoft.com/en-us/sql/t-sql/statements/alter-user-transact-sql#remarks
                                #>
                                Invoke-Query @invokeQueryParameters -Query (
                                    'ALTER USER [{0}] WITH NAME = [{1}], LOGIN = [{2}];' -f $Name, $Name, $LoginName
                                )
                            }
                            catch
                            {
                                $errorMessage = $script:localizedData.FailedUpdateDatabaseUser -f $Name, $DatabaseName, $UserType
                                New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
                            }
                        }
                    }

                    'AsymmetricKey'
                    {
                        if ($getTargetResourceResult.AsymmetricKeyName -ne $AsymmetricKeyName)
                        {
                            <#
                                    Not allowed to alter a database user mapped to an asymmetric key,
                                    the database user need to be re-created.
                                #>
                            Write-Verbose -Message (
                                $script:localizedData.ChangingAsymmetricKey -f $Name, $getTargetResourceResult.AsymmetricKeyName, $AsymmetricKeyName, $DatabaseName
                            )

                            $recreateDatabaseUser = $true
                        }
                    }

                    'Certificate'
                    {
                        if ($getTargetResourceResult.CertificateName -ne $CertificateName)
                        {
                            <#
                                    Not allowed to alter a database user mapped to a certificate,
                                    the database user need to be re-created.
                                #>
                            Write-Verbose -Message (
                                $script:localizedData.ChangingCertificate -f $Name, $getTargetResourceResult.CertificateName, $CertificateName, $DatabaseName
                            )

                            $recreateDatabaseUser = $true
                        }
                    }
                }
            }
            else
            {
                <#
                        Current database user have a different user type, the
                        database user need to be re-created.
                    #>
                Write-Verbose -Message (
                    $script:localizedData.ChangingUserType -f $Name, $getTargetResourceResult.UserType, $UserType, $DatabaseName
                )

                $recreateDatabaseUser = $true
            }

        }
    }

    # Throw if not opt-in to re-create database user.
    if ($recreateDatabaseUser -and -not $Force)
    {
        $errorMessage = $script:localizedData.ForceNotEnabled
        New-InvalidOperationException -Message $errorMessage
    }

    if (($Ensure -eq 'Absent' -and $getTargetResourceResult.Ensure -ne $Ensure) -or $recreateDatabaseUser)
    {
        # Drop the database user.
        try
        {
            Write-Verbose -Message (
                $script:localizedData.DropDatabaseUser -f $Name, $DatabaseName
            )

            Invoke-Query @invokeQueryParameters -Query (
                'DROP USER [{0}];' -f $Name
            )
        }
        catch
        {
            $errorMessage = $script:localizedData.FailedDropDatabaseUser -f $Name, $DatabaseName
            New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
        }
    }

    <#
        This evaluation is made to handle creation and re-creation of a database
        user to minimize the logic when the user has a different user type, or
        when there are restrictions on altering an existing database user.
    #>
    if (($Ensure -eq 'Present' -and $getTargetResourceResult.Ensure -ne $Ensure) -or $recreateDatabaseUser)
    {
        # Create the database user.
        try
        {
            Write-Verbose -Message (
                $script:localizedData.CreateDatabaseUser -f $Name, $DatabaseName, $UserType
            )

            switch ($UserType)
            {
                'Login'
                {
                    # Assert that the login exist.
                    Assert-SqlLogin @PSBoundParameters

                    Invoke-Query @invokeQueryParameters -Query (
                        'CREATE USER [{0}] FOR LOGIN [{1}];' -f $Name, $LoginName
                    )
                }

                'NoLogin'
                {
                    Invoke-Query @invokeQueryParameters -Query (
                        'CREATE USER [{0}] WITHOUT LOGIN;' -f $Name
                    )
                }

                'AsymmetricKey'
                {
                    # Assert that the asymmetric key exist.
                    Assert-DatabaseAsymmetricKey @PSBoundParameters

                    Invoke-Query @invokeQueryParameters -Query (
                        'CREATE USER [{0}] FOR ASYMMETRIC KEY [{1}];' -f $Name, $AsymmetricKeyName
                    )
                }

                'Certificate'
                {
                    # Assert that the certificate exist.
                    Assert-DatabaseCertificate @PSBoundParameters

                    Invoke-Query @invokeQueryParameters -Query (
                        'CREATE USER [{0}] FOR CERTIFICATE [{1}];' -f $Name, $CertificateName
                    )
                }
            }
        }
        catch
        {
            $errorMessage = $script:localizedData.FailedCreateDatabaseUser -f $Name, $DatabaseName, $UserType
            New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
        }
    }
}

<#
    .SYNOPSIS
        Determines if the database user in a database is in desired state.

    .PARAMETER Name
        Specifies the name of the database user to be added or removed.

    .PARAMETER ServerName
        Specifies the host name of the SQL Server on which the instance exist.

    .PARAMETER InstanceName
        Specifies the SQL instance in which the database exist.

    .PARAMETER DatabaseName
        Specifies the name of the database in which to configure the database user.

    .PARAMETER LoginName
        Specifies the name of the SQL login to associate with the database user.
        This must be specified if parameter UserType is set to 'Login'.

    .PARAMETER AsymmetricKeyName
        Specifies the name of the asymmetric key to associate with the database
        user. This must be specified if parameter UserType is set to 'AsymmetricKey'.

    .PARAMETER CertificateName
        Specifies the name of the certificate to associate with the database
        user. This must be specified if parameter UserType is set to 'Certificate'.

    .PARAMETER UserType
        Specifies the type of the database user. Valid values are 'Login',
        'NoLogin', 'Certificate', or 'AsymmetricKey'. Defaults to 'NoLogin'.

    .PARAMETER Ensure
        Specifies if the database user should be present or absent. If 'Present'
        then the user will be added to the database and, if needed, the login
        mapping will be updated. If 'Absent' then the user will be removed from
        the database. Defaults to 'Present'.
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

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $DatabaseName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $LoginName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $AsymmetricKeyName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CertificateName,

        [Parameter()]
        [ValidateSet(
            'Login',
            'NoLogin',
            'Certificate',
            'AsymmetricKey'
        )]
        [System.String]
        $UserType = 'NoLogin',

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.Boolean]
        $Force = $false
    )

    Assert-Parameters @PSBoundParameters

    Write-Verbose -Message (
        $script:localizedData.EvaluateDatabaseUser -f $Name, $DatabaseName
    )

    $getTargetResourceParameters = @{
        ServerName   = $ServerName
        InstanceName = $InstanceName
        Database     = $DatabaseName
        Name         = $Name
    }

    $getTargetResourceResult = Get-TargetResource @getTargetResourceParameters

    if ($getTargetResourceResult.Ensure -eq $Ensure)
    {
        if ($Ensure -eq 'Present')
        {
            <#
                Make sure default values are part of desired values if the user did
                not specify them in the configuration.
            #>
            $desiredValues = @{} + $PSBoundParameters
            $desiredValues['Ensure'] = $Ensure
            $desiredValues['UserType'] = $UserType

            $testTargetResourceReturnValue = Test-DscParameterState -CurrentValues $getTargetResourceResult `
                -DesiredValues $desiredValues `
                -ValuesToCheck @(
                'LoginName'
                'AsymmetricKeyName'
                'CertificateName'
                'UserType'
            )
        }
        else
        {
            $testTargetResourceReturnValue = $true
        }
    }
    else
    {
        $testTargetResourceReturnValue = $false
    }

    if ($testTargetResourceReturnValue)
    {
        Write-Verbose -Message $script:localizedData.InDesiredState
    }
    else
    {
        Write-Verbose -Message $script:localizedData.NotInDesiredState
    }

    return $testTargetResourceReturnValue
}

<#
    .SYNOPSIS
        Convert a database user's authentication type property to the correct
        user type.

    .PARAMETER AuthenticationType
        The authentication type for the database user.

    .PARAMETER LoginType
        The login type of the database user.
#>
function ConvertTo-UserType
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $AuthenticationType,

        [Parameter()]
        [System.String]
        $LoginType
    )

    $userType = switch ($AuthenticationType)
    {
        { $_ -eq 'Windows' -or $_ -eq 'Instance' }
        {
            'Login'
        }

        'None'
        {
            switch ($LoginType)
            {
                'SqlLogin'
                {
                    'NoLogin'
                }

                Default
                {
                    $LoginType
                }
            }

        }

        Default
        {
            $errorMessage = $script:localizedData.UnknownAuthenticationType -f $AuthenticationType, $LoginType
            New-InvalidOperationException -Message $errorMessage
        }
    }

    return $userType
}

<#
    .SYNOPSIS
        Test if a SQL login exist on the instance. Throws and error
        if it does not exist.

    .PARAMETER LoginName
        Specifies the name of the SQL login to associate with the database user.

    .PARAMETER AsymmetricKeyName
        Specifies the name of the asymmetric key to associate with the database
        user.

    .PARAMETER CertificateName
        Specifies the name of the certificate to associate with the database
        user.

    .PARAMETER UserType
        Specifies the type of the database user. Defaults to 'NoLogin'.

    .PARAMETER RemainingArguments
        Not used.
#>
function Assert-Parameters
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.String]
        $LoginName,

        [Parameter()]
        [System.String]
        $AsymmetricKeyName,

        [Parameter()]
        [System.String]
        $CertificateName,

        [Parameter()]
        [System.String]
        $UserType = 'NoLogin',

        # Catch all other splatted parameters from $PSBoundParameters
        [Parameter(ValueFromRemainingArguments = $true)]
        $RemainingArguments
    )

    if ($UserType -ne 'Login' -and $PSBoundParameters.ContainsKey('LoginName'))
    {
        $errorMessage = $script:localizedData.LoginNameProvidedWithWrongUserType -f $UserType
        New-InvalidArgumentException -ArgumentName 'Action' -Message $errorMessage
    }

    if ($UserType -ne 'Certificate' -and $PSBoundParameters.ContainsKey('CertificateName'))
    {
        $errorMessage = $script:localizedData.CertificateNameProvidedWithWrongUserType -f $UserType
        New-InvalidArgumentException -ArgumentName 'Action' -Message $errorMessage
    }

    if ($UserType -ne 'AsymmetricKey' -and $PSBoundParameters.ContainsKey('AsymmetricKeyName'))
    {
        $errorMessage = $script:localizedData.AsymmetricKeyNameProvidedWithWrongUserType -f $UserType
        New-InvalidArgumentException -ArgumentName 'Action' -Message $errorMessage
    }

    if ($UserType -eq 'Login' -and -not $PSBoundParameters.ContainsKey('LoginName'))
    {
        $errorMessage = $script:localizedData.LoginUserTypeWithoutLoginName -f $UserType
        New-InvalidArgumentException -ArgumentName 'Action' -Message $errorMessage
    }

    if ($UserType -eq 'AsymmetricKey' -and -not $PSBoundParameters.ContainsKey('AsymmetricKeyName'))
    {
        $errorMessage = $script:localizedData.AsymmetricKeyUserTypeWithoutAsymmetricKeyName -f $UserType
        New-InvalidArgumentException -ArgumentName 'Action' -Message $errorMessage
    }

    if ($UserType -eq 'Certificate' -and -not $PSBoundParameters.ContainsKey('CertificateName'))
    {
        $errorMessage = $script:localizedData.CertificateUserTypeWithoutCertificateName -f $UserType
        New-InvalidArgumentException -ArgumentName 'Action' -Message $errorMessage
    }
}

<#
    .SYNOPSIS
        Test if a SQL login exist on the instance. Throws and error
        if it does not exist.

    .PARAMETER ServerName
        Specifies the host name of the SQL Server on which the instance exist.

    .PARAMETER InstanceName
        Specifies the SQL instance in which the SQL login should be evaluated.

    .PARAMETER LoginName
        Specifies the name of the SQL login to be evaluated.

    .PARAMETER RemainingArguments
        Not used.
#>
function Assert-SqlLogin
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
        $LoginName,

        # Catch all other splatted parameters from $PSBoundParameters
        [Parameter(ValueFromRemainingArguments = $true)]
        $RemainingArguments
    )

    $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

    if (-not $sqlServerObject.Logins[$LoginName])
    {
        $errorMessage = $script:localizedData.SqlLoginNotFound -f $LoginName
        New-ObjectNotFoundException -Message $errorMessage
    }
}

<#
    .SYNOPSIS
        Test if a database certificate exist in the database. Throws and error
        if it does not exist.

    .PARAMETER ServerName
        Specifies the host name of the SQL Server on which the instance exist.

    .PARAMETER InstanceName
        Specifies the SQL instance in which the database exist.

    .PARAMETER DatabaseName
        Specifies the name of the database in which the certificate should be
        evaluated.

    .PARAMETER CertificateName
        Specifies the name of the certificate to be evaluated.

    .PARAMETER RemainingArguments
        Not used.
#>
function Assert-DatabaseCertificate
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
        $DatabaseName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $CertificateName,

        # Catch all other splatted parameters from $PSBoundParameters
        [Parameter(ValueFromRemainingArguments = $true)]
        $RemainingArguments
    )

    $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

    if (-not $sqlServerObject.Databases[$DatabaseName].Certificates[$CertificateName])
    {
        $errorMessage = $script:localizedData.CertificateNotFound -f $CertificateName, $DatabaseName
        New-ObjectNotFoundException -Message $errorMessage
    }
}

<#
    .SYNOPSIS
        Test if a database asymmetric key exist in the database. Throws and error
        if it does not exist.

    .PARAMETER ServerName
        Specifies the host name of the SQL Server on which the instance exist.

    .PARAMETER InstanceName
        Specifies the SQL instance in which the database exists.

    .PARAMETER DatabaseName
        Specifies the name of the database in which the asymmetric key should be
        evaluated.

    .PARAMETER AsymmetricKeyName
        Specifies the name of the asymmetric key to be evaluated.

    .PARAMETER RemainingArguments
        Not used.
#>
function Assert-DatabaseAsymmetricKey
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
        $DatabaseName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $AsymmetricKeyName,

        # Catch all other splatted parameters from $PSBoundParameters
        [Parameter(ValueFromRemainingArguments = $true)]
        $RemainingArguments
    )

    $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

    if (-not $sqlServerObject.Databases[$DatabaseName].AsymmetricKeys[$AsymmetricKeyName])
    {
        $errorMessage = $script:localizedData.AsymmetryKeyNotFound -f $AsymmetricKeyName, $DatabaseName
        New-ObjectNotFoundException -Message $errorMessage
    }
}

Export-ModuleMember -Function *-TargetResource
