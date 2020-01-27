ConvertFrom-StringData @'
    GetAvailabilityGroup = Get the current configuration for the availability group '{0}' on the instance '{1}'.
    RemoveAvailabilityGroup = Removing the availability group '{0}' on the instance '{1}'.
    HadrNotEnabled = Always On Availability Groups is not enabled.
    FailedRemoveAvailabilityGroup = Failed to remove the availability group '{0}' from the instance '{1}'.
    NotPrimaryReplica = The node '{0}' is not the primary replica for the availability group '{1}'. The primary replica node is '{2}'.
    FailedCreateAvailabilityGroup = Failed to create the availability group '{0}' on the instance '{1}'.
    FailedCreateAvailabilityGroupReplica = Failed to creating the availability group replica '{0}' on the instance '{1}'.
    DatabaseMirroringEndpointNotFound = No database mirroring endpoint was found on '{0}'.
    CreateAvailabilityGroupReplica = Creating the availability group replica '{0}' for availability group '{1}' on the instance '{2}'.
    CreateAvailabilityGroup = Creating the availability group '{0}' on the instance '{1}'.
    UpdateAvailabilityGroup = The availability group '{0}' exist on the instance '{1}'. Updating availability group and availability group replica properties.
    NotActiveNode = The node '{0}' is not actively hosting the instance '{1}'. Will always return success for this resource on this node, until this node is actively hosting the instance.
    TestingConfiguration = Determines if the configuration for the availability group '{0}' on the instance '{1}' is in desired state.
    ParameterNotInDesiredState = Expected the parameter '{0}' to have the value '{1}', but the value is '{2}'.
    FailedAlterAvailabilityGroup = Failed to change a property for the availability group '{0}'.
'@
