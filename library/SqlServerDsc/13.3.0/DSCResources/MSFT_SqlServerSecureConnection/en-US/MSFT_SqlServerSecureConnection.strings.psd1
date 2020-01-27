<#
    Localized resources for MSFT_SqlServerSecureConnection
#>

ConvertFrom-StringData @'
    GetEncryptionSettings = Getting encryption settings for instance '{0}'.
    CertificateSettings = Certificate permissions are {0}.
    EncryptedSettings = Found thumbprint of '{0}', with Force Encryption set to '{1}'.
    SetEncryptionSetting = Securing instance '{0}' with Thumbprint: '{1}' and Force Encryption: '{2}'.
    RemoveEncryptionSetting = Removing SQL Server secure connection from instance '{0}'.
    SetCertificatePermission = Adding read permissions to certificate '{0}' for account '{1}'.
    RestartingService = Restarting SQL Server service for instance '{0}'.
    TestingConfiguration = Determine if the Secure Connection is in the desired state.
    ThumbprintResult = Thumbprint was '{0}' but expected '{1}'.
    ForceEncryptionResult = ForceEncryption was '{0}' but expected '{1}'.
    EncryptionOff = SQL Secure Connection is Disabled.
    InstanceNotFound = SQL instance '{0}' not found on SQL Server.
    PrivateKeyPath = Certificate private key is located at '{0}'.
    CouldNotFindEncryptionValues = Could not find encryption values in registry for instance '{0}'.
    SuppressRequiredRestart = Service '{0}' restart has been suppressed. Changes will not take effect until the service is restarted.
'@
