<#
    Localized resources for MSFT_SqlServerDatabaseMail

    Note: The named text strings MailServerProperty* are used in conjunction with
    UpdatingPropertyOfMailServer to build a complete localized string.
#>

ConvertFrom-StringData @'
    ConnectToSqlInstance = Connecting to SQL Server instance '{0}\\{1}'.
    DatabaseMailEnabled = SQL Server Database Mail is enabled. Database Mail XPs are set to {0}.
    GetConfiguration = Account name '{0}' was found, returning the current state of the Database Mail configuration.
    DatabaseMailDisabled = SQL Server Database Mail is disabled. Database Mail XPs are disabled.
    AccountIsMissing = Account name '{0}' was not found.
    ChangingLoggingLevel = Changing the SQL Server Database Mail logging level to '{0}' (value '{1}').
    CurrentLoggingLevel = SQL Server Database Mail logging level is '{0}' (value '{1}').
    CreatingMailAccount = Creating the mail account '{0}'.
    MailAccountExist = Mail account '{0}' already exist.
    UpdatingPropertyOfMailServer = Updating {2} of outgoing mail server. Current value is '{0}', expected '{1}'.
    MailServerPropertyDisplayName = display name
    MailServerPropertyDescription = description
    MailServerPropertyEmailAddress = e-mail address
    MailServerPropertyReplyToEmailAddress = reply to e-mail address
    MailServerPropertyServerName = server name
    MailServerPropertyTcpPort = TCP port
    CreatingMailProfile = Creating a public default profile '{0}'.
    MailProfileExist = The public default profile '{0}' already exist.
    ConfigureSqlAgent = Configure the SQL Agent to use Database Mail.
    SqlAgentAlreadyConfigured = The SQL Agent is already configured to use Database Mail.
    TestingConfiguration = Determines if the Database Mail is in the desired state.
    RemovingSqlAgentConfiguration = Configure the SQL Agent to not use Database Mail (changing it back to SQL Agent Mail).
    RemovingMailProfile = Removing the public default profile '{0}'.
    RemovingMailAccount = Removing the mail account '{0}'.
'@
