ConvertFrom-StringData @'
    GetCurrentState = Get the current state of the server replication configuration for the instance '{0}'.
    DistributorMode = The distributor mode is currently '{0}' for the instance '{1}'.
    NoDistributorMode = There are currently no distributor mode set for the instance '{0}'.
    NoRemoteDistributor = The parameter RemoteDistributor cannot be empty when DistributorMode is set to 'Remote'.
    ConfigureLocalDistributor = The local distribution will be configured.
    ConfigureRemoteDistributor = The remote distribution will be configured.
    RemoveDistributor = The distribution will be removed.
    TestingConfiguration = Determines if the distribution is configured in desired state.
    CreateDistributionDatabase = Creating the distribution database object '{0}'.
    InstallRemoteDistributor = Installing the remote distributor '{0}'.
    InstallLocalDistributor = Installing the local distributor.
    UninstallDistributor = Uninstalling the distributor.
    CreateDistributorPublisher = Creating the distributor publisher '{0}' on the instance '{1}'.
    LoadAssembly = Loaded assembly: {0}
    FailedToDetectSqlVersion = Unable to detect version for the SQL Server instance '{0}'.
'@
