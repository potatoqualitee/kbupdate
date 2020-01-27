ConvertFrom-StringData @'
    TestingConfiguration = Determines if the Microsoft SQL Server Reporting Service instance is installed.
    FoundInstance = Found Microsoft SQL Server Reporting Service instance named '{0}'.
    InstanceNotFound = Could not find a Microsoft SQL Server Reporting Service instance.
    Install = Install
    Uninstall = Uninstall
    UsingExecutable = Using executable at '{0}'.
    SetupArguments = Starting executable using the arguments: {0}
    SetupExitMessage = Executable exited with code '{0}'.
    SetupSuccessfulRestartRequired = {0} finished successfully, but a restart is required.
    SetupFailed = Please see the log file in the %TEMP% folder.
    SetupFailedWithLog = Please see the log file '{0}'. If not path was provided, the default path for log files is %TEMP%.
    SetupSuccessful = {0} finished successfully.
    Restart = Restarting the target node.
    SuppressRestart = Suppressing restart of target node.
    EditionInvalidParameter = Both the parameters Edition and ProductKey was specified. Only either parameter Edition or ProductKey is allowed.
    EditionMissingParameter = Neither the parameters Edition and ProductKey was specified.
    SourcePathNotFound = The source path '{0}' does not exist, or the path does not specify an executable file.
    VersionFound = The Microsoft SQL Server Reporting Service instance is version '{0}'.
    PackageNotFound = Could not determine the version of the Microsoft SQL Server Reporting Service instance.
    WrongVersionFound = Expected version '{0}', but version '{1}' is installed.
    MissingVersion = Expected version '{0}' to be installed.
'@
