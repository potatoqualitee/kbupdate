ConvertFrom-StringData @'
    GetDatabase = Get the state of the database '{0}' on the instance '{1}'.
    DatabasePresent = There is a database '{0}' present, and has the collation '{1}'.
    DatabaseAbsent = It does not exist a database named '{0}'.
    InvalidCollation = The specified collation '{0}' is not a valid collation for the instance '{1}'.
    SetDatabase = Changing properties of the database '{0}' on the instance '{1}'.
    UpdatingCollation = Changing the database collation to '{0}'.
    FailedToUpdateDatabase = Failed to update database {0} with specified changes.
    CreateDatabase = Creating the database '{0}'.
    DropDatabase = Removing the database '{0}'.
    FailedToCreateDatabase = Failed to create the database '{0}'.
    FailedToDropDatabase = Failed to remove the database '{0}'
    TestingConfiguration = Determines the state of the database '{0}' on the instance '{1}'.
    NotInDesiredStateAbsent = Expected the database '{0}' to absent, but it was present.
    NotInDesiredStatePresent = Expected the database '{0}' to present, but it was absent
    CollationWrong = The database '{0}' exist and has the collation '{1}', but expected it to have the collation '{2}'.
'@
