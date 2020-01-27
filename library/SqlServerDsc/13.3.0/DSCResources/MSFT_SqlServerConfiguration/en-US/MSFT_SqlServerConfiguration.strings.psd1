# Localized resources for SqlServerConfiguration

ConvertFrom-StringData @'
    CurrentOptionValue = Configuration option '{0}' has a current value of '{1}'.
    ConfigurationValueUpdated = Configuration option '{0}' has been updated to value '{1}'.
    AutomaticRestart = A restart of SQL Server is required for the change to take effect. Initiating automatic restart of the SQL Server instance {0}//{1}.
    ConfigurationOptionNotFound = Specified option '{0}' could not be found.
    ConfigurationRestartRequired = Configuration option '{0}' has been updated to value '{1}', but a manual restart of SQL Server instance {2}//{3} is required for it to take effect.
    NotInDesiredState = Configuration option '{0}' is not in desired state. Expected '{1}', but was '{2}'.
    InDesiredState = Configuration option '{0}' is in desired state.
    NoRestartNeeded = The option was changed without the need to restart the SQL Server instance.
'@
