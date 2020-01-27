ConvertFrom-StringData @'
    EnumeratingFirewallRules = Enumerating firewall rules for instance '{0}'.
    ConnectUsingCredential = Connecting to the path '{0}' using the credential '{1}' through SMB.
    UsingPath = Using the executable at '{0}' to determine the SQL Server major version.
    MajorVersion = The SQL Server major version is '{0}'.
    ModifyFirewallRules = Modifying firewall rules for instance '{0}'.
    TestFailedAfterSet = Test-TargetResource function returned false when Set-TargetResource function verified the desired state. This indicates that the Set-TargetResource did not correctly set set the desired state, or that the function Test-TargetResource does not correctly evaluate the desired state.
    EvaluatingFirewallRules = Determines if the firewall rules are in desired state for the instance '{0}'.
    InDesiredState = The firewall rules are in desired state.
    NotInDesiredState = The firewall rules are not in desired state.
'@
