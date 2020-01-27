# Localized resources for MSFT_SqlServerAgentOperator

ConvertFrom-StringData @'
    GetSqlAgents = Getting SQL Agent Operators.
    SqlAgentPresent = SQL Agent Operator '{0}' is present.
    SqlAgentAbsent = SQL Agent Operator '{0}' is absent.
    UpdateOperatorSetError = Unable to update the email address for '{2}' to '{3}' on {0}\\{1}.
    AddSqlAgentOperator = Adding SQL Agent Operator '{0}'.
    UpdateEmailAddress = Updating email address to '{0}' for SQL Agent Operator '{1}'.
    CreateOperatorSetError = Unable to create the SQL Agent Operator '{0}' on {1}\\{2}.
    DeleteSqlAgentOperator = Deleting SQL Agent Operator '{0}'.
    DropOperatorSetError = Unable to drop the SQL Agent Operator '{0}' on {1}\\{2}.
    TestSqlAgentOperator = Checking if SQL Agent Operator '{0}' is present or absent.
    SqlAgentOperatorExistsButShouldNot = SQL Agent Operator exists but ensure is set to Absent. The SQL Agent Operator '{0}' should be deleted.
    SqlAgentOperatorDoesNotExistButShould  = SQL Agent Operator does not exist but Ensure is set to Present. The SQL Agent Operator '{0}' should be created.
    SqlAgentOperatorExistsButEmailWrong  = SQL Agent Operator '{0}' exists but has the wrong email address. Email address is currently '{1}' and should be updated to '{2}'.
    ConnectServerFailed = Unable to connect to {0}\\{1}.
'@
