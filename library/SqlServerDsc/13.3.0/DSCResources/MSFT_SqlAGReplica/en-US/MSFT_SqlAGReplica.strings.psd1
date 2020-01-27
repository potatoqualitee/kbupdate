ConvertFrom-StringData @'
    GetAvailabilityGroup = Get the current configuration for the availability group replica '{0}' in the availability group '{1}' on the instance '{2}'.
    HadrNotEnabled = Always On Availability Groups is not enabled.
    FailedRemoveAvailabilityGroupReplica = Failed to remove the availability group replica '{0}' from the availability group '{1}' on the instance '{2}'.
    DatabaseMirroringEndpointNotFound = No database mirroring endpoint was found on '{0}'.
    ReplicaNotFound = Unable to find the availability group replica '{0}' in the availability group '{1}' on the instance '{2}'.
    FailedCreateAvailabilityGroupReplica = Failed to creating the availability group replica '{0}' for the availability group '{1}' on the instance '{2}'.
    FailedJoinAvailabilityGroup = Failed to join the availability group replica '{0}' to the availability group '{1}' on the instance '{2}'.
    AvailabilityGroupNotFound = Unable to locate the availability group '{0}' on the instance '{1}'.
    NotActiveNode = The node '{0}' is not actively hosting the instance '{1}'. Will always return success for this resource on this node, until this node is actively hosting the instance.
    TestingConfiguration = Determines if the configuration for the availability group '{0}' on the instance '{1}' is in desired state.
    ParameterNotInDesiredState = Expected the parameter '{0}' to have the value '{1}', but the value is '{2}'.
    RemoveAvailabilityReplica = Removing the availability group replica '{0}' from the availability group '{1}' on the instance '{2}'.
    PrepareAvailabilityReplica = Preparing the availability group replica '{0}' to join the availability group '{1}' on the instance '{2}'.
    JoinAvailabilityGroup = Joining the availability group replica '{0}' to the availability group '{1}' on the instance '{2}'.
'@
