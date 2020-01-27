# Localized resources for SqlSetup

ConvertFrom-StringData @'
    GetLogin = Getting the login '{0}' from the instance '{1}\\{2}'.
    LoginCurrentState = The login '{0}' is {1} at the instance '{2}\\{3}'.
    SetPasswordExpirationEnabled = Setting password expiration enabled to '{0}' for the login '{1}' on the instance '{2}\\{3}'.
    SetPasswordPolicyEnforced = Setting password policy enforced to '{0}' for the login '{1}' on the instance '{2}\\{3}'.
    SetPassword = Setting the password for the login '{0}' on the instance '{1}\\{2}'.
    SetDisabled = Disabling the the login '{0}' on the instance '{1}\\{2}'.
    SetEnabled = Enabling the the login '{0}' on the instance '{1}\\{2}'.
    LoginTypeNotImplemented = The login type '{0}' is not implemented in this resource.
    LoginCredentialNotFound = To create the SQL login '{0}', the login credentials must also be provided.
    CreateLogin = Creating the login '{0}', with the login type '{1}', on the instance '{2}\\{3}'.
    IncorrectLoginMode = The instance '{0}\\{1}' is currently in '{2}' authentication mode. To create a SQL Login, it must be set to 'Mixed' authentication mode.
    DropLogin = Removing the login '{0}' from the instance '{1}\\{2}'.
    TestingConfiguration = Determines if the login '{0}' at the instance '{1}\\{2}' has the correct state.
    WrongEnsureState = The login '{0}' is {1}, but expected it to be {2}.
    WrongLoginType = The login '{0}' has the login type '{1}', but expected it to have the login type '{2}'.
    ExpectedDisabled = Expected the login '{0}' to be disabled, but it is enabled.
    ExpectedEnabled = Expected the login '{0}' to be enabled, but it is disabled.
    ExpectedLoginPasswordExpirationDisabled = The login '{0}' has the password expiration enabled, but expected it to be disabled.
    ExpectedLoginPasswordExpirationEnabled = The login '{0}' has the password expiration disabled, but expected it to be enabled.
    ExpectedLoginPasswordPolicyEnforcedDisabled = The login '{0}' has the password policy enforced enabled, but expected it to be disabled.
    ExpectedLoginPasswordPolicyEnforcedEnabled = The login '{0}' has the password policy enforced disabled, but expected it to be enabled.
    PasswordValidButLoginDisabled = The password for the login '{0}' is valid, but the login is disabled.
    PasswordValidationFailed = The password was not correct, password validation failed for the login '{0}'.
    PasswordValidationFailedMessage = The returned error message was: {0}
    PasswordValidationError = Password validation failed with an error.
    AlterLoginFailed = Altering the login '{0}' failed.
    CreateLoginFailedOnPassword = Creation of the login '{0}' failed due to a problem with the password.
    CreateLoginFailed = Creation of the login '{0}' failed.
    DropLoginFailed = Removal of the login '{0}' failed.
    SetPasswordValidationFailed = Setting the password failed for the login '{0}' because of password validation error.
    SetPasswordFailed = Setting the password failed for the login '{0}'.
'@
