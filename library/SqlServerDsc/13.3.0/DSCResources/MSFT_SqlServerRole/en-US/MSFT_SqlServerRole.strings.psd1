# Localized resources for SqlServerRole

ConvertFrom-StringData @'
    GetProperties = Getting properties of the SQL Server role '{0}'.
    SetProperties = Setting properties of the SQL Server role '{0}'.
    TestProperties = Testing properties of the SQL Server role '{0}'.
    EnumMemberNamesServerRoleGetError = Failed to enumerate members of the server role named '{2}' on '{0}\\{1}'.
    MembersToIncludeAndExcludeParamMustBeNull = The parameter MembersToInclude and/or MembersToExclude must not be set, or be set to $null, when parameter Members are used.
    DropServerRoleSetError = Failed to drop the server role named '{2}' on '{0}\\{1}'.
    CreateServerRoleSetError = Failed to create the server role named '{2}' on '{0}\\{1}'.
    AddMemberServerRoleSetError = Failed to add member '{3}' to the server role named '{2}' on '{0}\\{1}'.
    DropMemberServerRoleSetError = Failed to drop member '{3}' to the server role named '{2}' on '{0}\\{1}'.
    DesiredMembersNotPresent = One or more of the desired members are not present in the server role '{0}'.
    MemberNotPresent = The login '{1}' is not a member of the server role '{0}'.
    MemberPresent = The login '{1}' should not be a member of the server role '{0}'.
    DropRole = Removing the SQL Server role '{0}'.
    CreateRole = Creating the SQL Server role '{0}'.
    EnsureIsAbsent = Ensure is set to Absent. The existing role '{0}' should be removed.
    EnsureIsPresent = Ensure is set to Present. Either the role '{0}' is missing and should be created, or members in the role is not in desired state.
    SecurityPrincipalNotFound = Security principal '{0}' does not exist on SQL server '{1}'.
    AddMemberToRole = Adding login '{0}' to role '{1}'.
    RemoveMemberFromRole = Removing login '{0}' from role '{1}'.
'@
