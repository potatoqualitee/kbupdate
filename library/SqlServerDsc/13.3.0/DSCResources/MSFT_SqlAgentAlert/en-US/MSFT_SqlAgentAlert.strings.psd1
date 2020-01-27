# Localized resources for MSFT_SqlServerAgentAlert

ConvertFrom-StringData @'
    GetSqlAlerts = Getting SQL Agent Alerts.
    SqlAlertPresent = SQL Agent Alert '{0}' is present.
    SqlAlertAbsent = SQL Agent Alert '{0}' is absent.
    UpdateSeverity = Updating severity to '{0}' for SQL Agent Alert '{1}'.
    UpdateMessageId = Updating message id to '{0}' for SQL Agent Alert '{1}'.
    UpdateAlertSeverityError = Unable to update the severity for '{2}' to '{3}' on {0}\\{1}.
    UpdateAlertMessageIdError = Unable to update the message id for '{2}' to '{3}' on {0}\\{1}.
    AddSqlAgentAlert = Adding SQL Agent Alert '{0}'.
    CreateAlertSetError = Unable to create the SQL Agent Alert '{0}' on {1}\\{2}.
    DropAlertSetError = Unable to drop the SQL Agent Alert '{0}' on {1}\\{2}.
    DeleteSqlAgentAlert = Deleting SQL Agent Alert '{0}'.
    TestingConfiguration = Determines if the SQL Agent Alert is in the desired state.
    ConnectServerFailed = Unable to connect to {0}\\{1}.
    MultipleParameterError = Only one of Severity or MessageId can be specified, SQL Agent Alert '{0}' contains both.
'@
