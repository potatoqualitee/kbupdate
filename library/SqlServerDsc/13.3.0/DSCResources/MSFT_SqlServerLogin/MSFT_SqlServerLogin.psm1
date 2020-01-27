$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SqlServerDsc.Common'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SqlServerDsc.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_SqlServerLogin'

<#
    .SYNOPSIS
    Gets the specified login by name.

    .PARAMETER Name
    The name of the login to retrieve.

    .PARAMETER ServerName
    Hostname of the SQL Server to retrieve the login from.

    .PARAMETER InstanceName
    Name of the SQL instance to retrieve the login from.
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
        $InstanceName
    )

    Write-Verbose -Message (
        $script:localizedData.GetLogin -f $Name, $ServerName, $InstanceName
    )

    $serverObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName
    if ($serverObject)
    {
        $login = $serverObject.Logins[$Name]

        if ($login)
        {
            $ensure = 'Present'
        }
        else
        {
            $ensure = 'Absent'
        }
    }

    Write-Verbose -Message (
        $script:localizedData.LoginCurrentState -f $Name, $ensure, $ServerName, $InstanceName
    )

    $returnValue = @{
        Ensure       = $ensure
        Name         = $Name
        LoginType    = $login.LoginType
        ServerName   = $ServerName
        InstanceName = $InstanceName
        Disabled     = $login.IsDisabled
    }

    if ($login.LoginType -eq 'SqlLogin')
    {
        $returnValue.Add('LoginMustChangePassword', $login.MustChangePassword)
        $returnValue.Add('LoginPasswordExpirationEnabled', $login.PasswordExpirationEnabled)
        $returnValue.Add('LoginPasswordPolicyEnforced', $login.PasswordPolicyEnforced)
    }

    return $returnValue
}

<#
    .SYNOPSIS
    Creates a login.

    .PARAMETER Ensure
    Specifies if the login to exist. Default is 'Present'.

    .PARAMETER Name
    The name of the login to retrieve.

    .PARAMETER LoginType
    The type of login to create. Default is 'WindowsUser'

    .PARAMETER ServerName
    Hostname of the SQL Server to create the login on.

    .PARAMETER InstanceName
    Name of the SQL instance to create the login on.

    .PARAMETER LoginCredential
    The credential containing the password for a SQL Login. Only applies if the login type is SqlLogin.

    .PARAMETER LoginMustChangePassword
    Specifies if the login is required to have its password change on the next login. Only applies to SQL Logins. Default is $true.

    .PARAMETER LoginPasswordExpirationEnabled
    Specifies if the login password is required to expire in accordance to the operating system security policy. Only applies to SQL Logins. Default is $true.

    .PARAMETER LoginPasswordPolicyEnforced
    Specifies if the login password is required to conform to the password policy specified in the system security policy. Only applies to SQL Logins. Default is $true.

    .PARAMETER Disabled
    Specifies if the login is disabled. Default is $false.
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

        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter()]
        [ValidateSet(
            'WindowsUser',
            'WindowsGroup',
            'SqlLogin',
            'Certificate',
            'AsymmetricKey',
            'ExternalUser',
            'ExternalGroup'
        )]
        [System.String]
        $LoginType = 'WindowsUser',

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $LoginCredential,

        [Parameter()]
        [System.Boolean]
        $LoginMustChangePassword = $true,

        [Parameter()]
        [System.Boolean]
        $LoginPasswordExpirationEnabled = $true,

        [Parameter()]
        [System.Boolean]
        $LoginPasswordPolicyEnforced = $true,

        [Parameter()]
        [System.Boolean]
        $Disabled
    )

    $serverObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

    switch ( $Ensure )
    {
        'Present'
        {
            if ( $serverObject.Logins[$Name] )
            {
                $login = $serverObject.Logins[$Name]

                if ( $login.LoginType -eq 'SqlLogin' )
                {
                    if ( $login.PasswordExpirationEnabled -ne $LoginPasswordExpirationEnabled )
                    {
                        Write-Verbose -Message (
                            $script:localizedData.SetPasswordExpirationEnabled -f $LoginPasswordExpirationEnabled, $Name, $ServerName, $InstanceName
                        )

                        $login.PasswordExpirationEnabled = $LoginPasswordExpirationEnabled
                        Update-SQLServerLogin -Login $login
                    }

                    if ( $login.PasswordPolicyEnforced -ne $LoginPasswordPolicyEnforced )
                    {
                        Write-Verbose -Message (
                            $script:localizedData.SetPasswordPolicyEnforced -f $LoginPasswordPolicyEnforced, $Name, $ServerName, $InstanceName
                        )

                        $login.PasswordPolicyEnforced = $LoginPasswordPolicyEnforced
                        Update-SQLServerLogin -Login $login
                    }

                    # Set the password if it is specified
                    if ( $LoginCredential )
                    {
                        Write-Verbose -Message (
                            $script:localizedData.SetPassword -f $Name, $ServerName, $InstanceName
                        )

                        Set-SQLServerLoginPassword -Login $login -SecureString $LoginCredential.Password
                    }
                }

                if ( $PSBoundParameters.ContainsKey('Disabled') -and ($login.IsDisabled -ne $Disabled) )
                {
                    if ( $Disabled )
                    {
                        Write-Verbose -Message (
                            $script:localizedData.SetDisabled -f $Name, $ServerName, $InstanceName
                        )

                        $login.Disable()
                    }
                    else
                    {
                        Write-Verbose -Message (
                            $script:localizedData.SetEnabled -f $Name, $ServerName, $InstanceName
                        )

                        $login.Enable()
                    }
                }
            }
            else
            {
                # Some login types need additional work. These will need to be fleshed out more in the future
                if ( @('Certificate', 'AsymmetricKey', 'ExternalUser', 'ExternalGroup') -contains $LoginType )
                {
                    $errorMessage = $script:localizedData.LoginTypeNotImplemented -f $LoginType
                    New-NotImplementedException -Message $errorMessage
                }

                if ( ( $LoginType -eq 'SqlLogin' ) -and ( -not $LoginCredential ) )
                {
                    $errorMessage = $script:localizedData.LoginCredentialNotFound -f $Name
                    New-ObjectNotFoundException -Message $errorMessage
                }

                Write-Verbose -Message (
                    $script:localizedData.CreateLogin -f $Name, $LoginType, $ServerName, $InstanceName
                )

                $login = New-Object -TypeName 'Microsoft.SqlServer.Management.Smo.Login' -ArgumentList $serverObject, $Name
                $login.LoginType = $LoginType

                switch ($LoginType)
                {
                    'SqlLogin'
                    {
                        # Verify the instance is in Mixed authentication mode
                        if ( $serverObject.LoginMode -notmatch 'Mixed|Normal' )
                        {
                            $errorMessage = $script:localizedData.IncorrectLoginMode -f $ServerName, $InstanceName, $serverObject.LoginMode
                            New-InvalidOperationException -Message $errorMessage
                        }

                        $login.PasswordPolicyEnforced = $LoginPasswordPolicyEnforced
                        $login.PasswordExpirationEnabled = $LoginPasswordExpirationEnabled
                        if ( $LoginMustChangePassword )
                        {
                            $LoginCreateOptions = [Microsoft.SqlServer.Management.Smo.LoginCreateOptions]::MustChange
                        }
                        else
                        {
                            $LoginCreateOptions = [Microsoft.SqlServer.Management.Smo.LoginCreateOptions]::None
                        }

                        New-SQLServerLogin -Login $login -LoginCreateOptions $LoginCreateOptions -SecureString $LoginCredential.Password -ErrorAction Stop
                    }

                    default
                    {
                        New-SQLServerLogin -Login $login
                    }
                }

                # we can only disable the login once it's been created
                if ( $Disabled )
                {
                    Write-Verbose -Message (
                        $script:localizedData.SetDisabled -f $Name, $ServerName, $InstanceName
                    )

                    $login.Disable()
                }
            }
        }

        'Absent'
        {
            if ( $serverObject.Logins[$Name] )
            {
                Write-Verbose -Message (
                    $script:localizedData.DropLogin -f $Name, $ServerName, $InstanceName
                )

                Remove-SQLServerLogin -Login $serverObject.Logins[$Name]
            }
        }
    }
}

<#
    .SYNOPSIS
    Tests to verify the login exists and the properties are correctly set.

    .PARAMETER Ensure
    Specifies if the login is supposed to exist. Default is 'Present'.

    .PARAMETER Name
    The name of the login.

    .PARAMETER LoginType
    The type of login. Default is 'WindowsUser'

    .PARAMETER ServerName
    Hostname of the SQL Server.

    .PARAMETER InstanceName
    Name of the SQL instance.

    .PARAMETER LoginCredential
    The credential containing the password for a SQL Login. Only applies if the login type is SqlLogin.

    .PARAMETER LoginMustChangePassword
    Specifies if the login is required to have its password change on the next login. Only applies to SQL Logins. Default is $true.

    .PARAMETER LoginPasswordExpirationEnabled
    Specifies if the login password is required to expire in accordance to the operating system security policy. Only applies to SQL Logins. Default is $true.

    .PARAMETER LoginPasswordPolicyEnforced
    Specifies if the login password is required to conform to the password policy specified in the system security policy. Only applies to SQL Logins. Default is $true.

    .PARAMETER Disabled
    Specifies if the login is disabled. Default is $false.
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

        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter()]
        [ValidateSet('WindowsUser',
            'WindowsGroup',
            'SqlLogin',
            'Certificate',
            'AsymmetricKey',
            'ExternalUser',
            'ExternalGroup'
        )]
        [System.String]
        $LoginType = 'WindowsUser',

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $LoginCredential,

        [Parameter()]
        [System.Boolean]
        $LoginMustChangePassword = $true,

        [Parameter()]
        [System.Boolean]
        $LoginPasswordExpirationEnabled = $true,

        [Parameter()]
        [System.Boolean]
        $LoginPasswordPolicyEnforced = $true,

        [Parameter()]
        [System.Boolean]
        $Disabled
    )

    Write-Verbose -Message (
        $script:localizedData.TestingConfiguration -f $Name, $ServerName, $InstanceName
    )

    # Assume the test will pass
    $testPassed = $true

    $getParams = @{
        Name         = $Name
        ServerName   = $ServerName
        InstanceName = $InstanceName
    }

    $loginInfo = Get-TargetResource @getParams

    if ( $Ensure -ne $loginInfo.Ensure )
    {
        Write-Verbose -Message (
            $script:localizedData.WrongEnsureState -f $Name, $loginInfo.Ensure, $Ensure
        )

        $testPassed = $false
    }

    if ( $Ensure -eq 'Present' -and $($loginInfo.Ensure) -eq 'Present' )
    {
        if ( $LoginType -ne $loginInfo.LoginType )
        {
            Write-Verbose -Message (
                $script:localizedData.WrongLoginType -f $Name, $loginInfo.LoginType, $LoginType
            )

            $testPassed = $false
        }

        if ( $PSBoundParameters.ContainsKey('Disabled') -and ($loginInfo.Disabled -ne $Disabled) )
        {
            if ($Disabled)
            {
                Write-Verbose -Message (
                    $script:localizedData.ExpectedDisabled -f $Name
                )
            }
            else
            {
                Write-Verbose -Message (
                    $script:localizedData.ExpectedEnabled -f $Name
                )
            }

            $testPassed = $false
        }

        if ( $LoginType -eq 'SqlLogin' )
        {
            if ( $LoginPasswordExpirationEnabled -ne $loginInfo.LoginPasswordExpirationEnabled )
            {
                if ($LoginPasswordExpirationEnabled)
                {
                    Write-Verbose -Message (
                        $script:localizedData.ExpectedLoginPasswordExpirationEnabled -f $Name
                    )
                }
                else
                {
                    Write-Verbose -Message (
                        $script:localizedData.ExpectedLoginPasswordExpirationDisabled -f $Name
                    )
                }

                $testPassed = $false
            }

            if ( $LoginPasswordPolicyEnforced -ne $loginInfo.LoginPasswordPolicyEnforced )
            {
                if ($LoginPasswordPolicyEnforced)
                {
                    Write-Verbose -Message (
                        $script:localizedData.ExpectedLoginPasswordPolicyEnforcedEnabled -f $Name
                    )
                }
                else
                {
                    Write-Verbose -Message (
                        $script:localizedData.ExpectedLoginPasswordPolicyEnforcedDisabled -f $Name
                    )
                }

                $testPassed = $false
            }

            # If testPassed is still true and a login credential was specified, test the password
            if ( $testPassed -and $LoginCredential )
            {
                $userCredential = [System.Management.Automation.PSCredential]::new($Name, $LoginCredential.Password)

                try
                {
                    Connect-SQL -ServerName $ServerName -InstanceName $InstanceName -SetupCredential $userCredential -LoginType 'SqlLogin' | Out-Null
                }
                catch
                {
                    # Check to see if the parameter of $Disabled is true
                    if ($Disabled)
                    {
                        <#
                            An exception occurred and $Disabled is true, we neeed
                            to check the error codes for expected error numbers.
                            Recursively search the Exception variable and inner
                            Exceptions for the specific numbers.
                            18470 - Username and password are correct, but
                            account is disabled.
                            18456 - Login failed for user.
                        #>
                        if ((Find-ExceptionByNumber -ExceptionToSearch $_.Exception -ErrorNumber 18470))
                        {
                            Write-Verbose -Message (
                                    $script:localizedData.PasswordValidButLoginDisabled -f $Name
                            )
                        }
                        elseif ((Find-ExceptionByNumber -ExceptionToSearch $_.Exception -ErrorNumber 18456))
                        {
                            Write-Verbose -Message (
                                '{0} {1}' -f
                                    ($script:localizedData.PasswordValidationFailed -f $Name),
                                    ($script:localizedData.PasswordValidationFailedMessage -f $_.Exception.message)
                            )

                            # The password was not correct, password validation failed
                            $testPassed = $false
                        }
                        else
                        {
                            # Something else went wrong, rethrow error
                            $errorMessage = $script:localizedData.PasswordValidationError
                            New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
                        }
                    }
                    else
                    {
                        Write-Verbose -Message (
                            $script:localizedData.PasswordValidationFailed -f $Name
                        )

                        $testPassed = $false
                    }
                }
            }
        }
    }

    return $testPassed
}

<#
    .SYNOPSIS
    Alters a login.

    .PARAMETER Login
    The Login object to alter.

    .NOTES
    This function allows us to more easily write mocks.
#>
function Update-SQLServerLogin
{
    param
    (
        [Parameter(Mandatory = $true)]
        [Microsoft.SqlServer.Management.Smo.Login]
        $Login
    )

    try
    {
        $originalErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'

        $Login.Alter()
    }
    catch
    {
        $errorMessage = $script:localizedData.AlterLoginFailed -f $Login.Name
        New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
    }
    finally
    {
        $ErrorActionPreference = $originalErrorActionPreference
    }
}

<#
    .SYNOPSIS
    Creates a login.

    .PARAMETER Login
    The Login object to create.

    .PARAMETER LoginCreateOptions
    The LoginCreateOptions object to use when creating a SQL login.

    .PARAMETER SecureString
    The SecureString object that contains the password for a SQL login.

    .EXAMPLE
    CreateLogin -Login $login -LoginCreateOptions $LoginCreateOptions -SecureString $LoginCredential.Password -ErrorAction Stop

    .EXAMPLE
    CreateLogin -Login $login

    .NOTES
    This function allows us to more easily write mocks.
#>
function New-SQLServerLogin
{
    [CmdletBinding(DefaultParameterSetName = 'WindowsLogin')]
    param
    (
        [Parameter(Mandatory = $true, ParameterSetName = 'WindowsLogin')]
        [Parameter(Mandatory = $true, ParameterSetName = 'SqlLogin')]
        [Microsoft.SqlServer.Management.Smo.Login]
        $Login,

        [Parameter(Mandatory = $true, ParameterSetName = 'SqlLogin')]
        [Microsoft.SqlServer.Management.Smo.LoginCreateOptions]
        $LoginCreateOptions,

        [Parameter(Mandatory = $true, ParameterSetName = 'SqlLogin')]
        [System.Security.SecureString]
        $SecureString
    )

    switch ( $PSCmdlet.ParameterSetName )
    {
        'SqlLogin'
        {
            try
            {
                $originalErrorActionPreference = $ErrorActionPreference
                $ErrorActionPreference = 'Stop'

                $login.Create($SecureString, $LoginCreateOptions)
            }
            catch [Microsoft.SqlServer.Management.Smo.FailedOperationException]
            {
                if ( $_.Exception.InnerException.InnerException.InnerException -match 'Password validation failed' )
                {
                    $errorMessage = $script:localizedData.CreateLoginFailedOnPassword -f $Login.Name
                    New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
                }
                else
                {
                    $errorMessage = $script:localizedData.CreateLoginFailed -f $Login.Name
                    New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
                }
            }
            catch
            {
                $errorMessage = $script:localizedData.CreateLoginFailed -f $Login.Name
                New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
            }
            finally
            {
                $ErrorActionPreference = $originalErrorActionPreference
            }
        }

        'WindowsLogin'
        {
            try
            {
                $originalErrorActionPreference = $ErrorActionPreference
                $ErrorActionPreference = 'Stop'

                $login.Create()
            }
            catch
            {
                $errorMessage = $script:localizedData.CreateLoginFailed -f $Login.Name
                New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
            }
            finally
            {
                $ErrorActionPreference = $originalErrorActionPreference
            }
        }
    }
}

<#
    .SYNOPSIS
    Drops a login.

    .PARAMETER Login
    The Login object to drop.

    .NOTES
    This function allows us to more easily write mocks.
#>
function Remove-SQLServerLogin
{
    param
    (
        [Parameter(Mandatory = $true)]
        [Microsoft.SqlServer.Management.Smo.Login]
        $Login
    )

    try
    {
        $originalErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'

        $Login.Drop()
    }
    catch
    {
        $errorMessage = $script:localizedData.DropLoginFailed -f $Login.Name
        New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
    }
    finally
    {
        $ErrorActionPreference = $originalErrorActionPreference
    }
}

<#
    .SYNOPSIS
    Changes the password of a SQL Login.

    .PARAMETER Login
    The Login object to change the password on.

    .PARAMETER SecureString
    The SecureString object that contains the password for a SQL login.

    .NOTES
    This function allows us to more easily write mocks.
#>
function Set-SQLServerLoginPassword
{
    param
    (
        [Parameter(Mandatory = $true)]
        [Microsoft.SqlServer.Management.Smo.Login]
        $Login,

        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]
        $SecureString
    )

    try
    {
        $originalErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'

        $Login.ChangePassword($SecureString)
    }
    catch [Microsoft.SqlServer.Management.Smo.FailedOperationException]
    {
        if ( $_.Exception.InnerException.InnerException.InnerException -match 'Password validation failed' )
        {
            $errorMessage = $script:localizedData.SetPasswordValidationFailed -f $Login.Name
            New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
        }
        else
        {
            $errorMessage = $script:localizedData.SetPasswordFailed -f $Login.Name
            New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
        }
    }
    catch
    {
        $errorMessage = $script:localizedData.SetPasswordFailed -f $Login.Name
        New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
    }
    finally
    {
        $ErrorActionPreference = $originalErrorActionPreference
    }
}

Export-ModuleMember -Function *-TargetResource
