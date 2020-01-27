ConvertFrom-StringData @'
    GetAvailabilityGroupListener = Get the current state of the Availability Group listener '{0}' for the Availability Group '{1}' on the instance '{2}'.
    AvailabilityGroupListenerIsPresent = The Availability Group listener '{0}' exist.
    AvailabilityGroupListenerIsNotPresent = The Availability Group listener '{0}' does not exist.
    AvailabilityGroupListenerNotFound = Trying to make a change to a listener that does not exist.
    CreateAvailabilityGroupListener = Create Availability Group listener '{0}' for the Availability Group '{1}' on the instance '{2}'.
    SetAvailabilityGroupListenerPort = Availability Group listener port is set to '{0}'.
    SetAvailabilityGroupListenerDhcp = Availability Group listener is using DHCP with the subnet '{0}'.
    SetAvailabilityGroupListenerDhcpDefaultSubnet = Availability Group listener is using DHCP with the server default subnet.
    SetAvailabilityGroupListenerStaticIpAddress = Availability Group listener is using static IP address(es) '{0}'.
    DropAvailabilityGroupListener = Remove the Availability Group listener '{0}' from the Availability Group '{1}' on the instance '{2}'.
    AvailabilityGroupNotFound = Unable to locate the Availability Group '{0}' on the instance '{1}'.
    FoundNewIpAddress = Found at least one new IP-address.
    AvailabilityGroupListenerIPChangeError = IP-address configuration mismatch. Expecting the IP-address(es) '{0}', but found '{1}'. Resource does not support changing IP-address. Listener needs to be removed and then created again.
    AvailabilityGroupListenerDHCPChangeError = DHCP configuration mismatch. Expecting '{0}' found '{1}'. Resource does not support changing between static IP and DHCP. Listener needs to be removed and then created again.
    AvailabilityGroupListenerInDesiredState = Availability Group listener '{0}' is in desired state for the Availability Group '{1}' on the instance '{2}'.
    AvailabilityGroupListenerNotInDesiredState = Availability Group listener '{0}' is not in desired state for the Availability Group '{1}' on the instance '{2}'.
    ChangingAvailabilityGroupListenerPort = Changing Availability Group listener port to '{0}'.
    AddingAvailabilityGroupListenerIpAddress = Adding Availability Group listener IP address '{0}'.
    UnexpectedErrorFromGet = Got unexpected result from Get-TargetResource. No change is made.
    TestingConfiguration = Determines the current state for the Availability Group listener '{0}' for the Availability Group '{1}' on the instance '{2}'..
    DebugConnectingAvailabilityGroup = Connecting to Availability Group listener '{0}' as the user '{1}'.
'@
