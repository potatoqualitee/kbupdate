ConvertFrom-StringData @'
    AddDatabaseRoleMember = Adding member '{0}' to role '{1}' in database '{2}'.
    AddDatabaseRoleMemberError = Failed to add member '{0}' to role '{1}' in database '{2}'.
    CreateDatabaseRole = Creating role '{0}' in database '{1}'.
    CreateDatabaseRoleError = Failed to create role '{0}' in database '{1}'.
    DatabaseNotFound = The database '{0}' does not exist.
    DatabaseRoleOrUserNotFound = The role or user '{0}' does not exist in database '{1}'.
    DesiredMembersNotPresent = One or more of the desired members are not present in the role '{0}' in database '{1}'.
    DropDatabaseRole = Removing role '{0}' from database '{1}'.
    DropDatabaseRoleError = Failed to drop the role '{0}' in database '{1}'.
    DropDatabaseRoleMember = Removing member '{0}' from role '{1}' in database '{2}'.
    DropDatabaseRoleMemberError = Failed to drop member '{0}' from role '{1}' in database '{2}'.
    EnsureIsAbsent = Ensure is set to Absent. The existing role '{0}' should be removed.
    EnsureIsPresent = Ensure is set to Present. Either the role '{0}' is missing and should be created, or members in the role are not in the desired state.
    EnumDatabaseRoleMemberNamesError = Failed to enumerate members of the role '{0}' in database '{1}'.
    GetDatabaseRoleProperties = Getting properties of the SQL database role '{0}'.
    MemberNotPresent = The user '{0}' is not a member of the role '{1}' in database '{2}'.
    MemberPresent = The user '{0}' should not be a member of the role '{1}' in database '{2}'.
    MembersToIncludeAndExcludeParamMustBeNull = The parameter MembersToInclude and/or MembersToExclude must not be set, or be set to $null, when parameter Members are used.
    SetDatabaseRoleProperties = Setting properties of the SQL database role '{0}'.
    TestDatabaseRoleProperties = Testing the desired state of the SQL database role '{0}'.
'@
