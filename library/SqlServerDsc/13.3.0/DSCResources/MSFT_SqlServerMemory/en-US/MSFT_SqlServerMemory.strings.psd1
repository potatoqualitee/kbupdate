ConvertFrom-StringData @'
    GetMemoryValues = Getting the current values for minimum and maximum SQL server memory for instance '{0}'.
    SetNewValues = Setting the minimum and maximum memory that will be used by the instance '{0}'.
    MaxMemoryParamMustBeNull = The parameter MaxMemory must be null when the parameter DynamicAlloc is set to true.
    MaxMemoryParamMustNotBeNull = The parameter MaxMemory must not be null when the parameter DynamicAlloc is set to false.
    DynamicMaxMemoryValue = Dynamic maximum memory has been calculated to {0}MB.
    MaximumMemoryLimited = Maximum memory used by the instance '{0}' has been limited to {1}MB.
    MinimumMemoryLimited = Minimum memory used by the instance '{0}' has been set to {1}MB.
    DefaultValues = Resetting to the default values; MinMemory = {0}, MaxMemory = {1}.
    ResetDefaultValues = Minimum and maximum server memory values used by the instance {0} has been reset to the default values.
    AlterServerMemoryFailed = Failed to alter the server configuration memory for {0}\\{1}.
    ErrorGetDynamicMaxMemory = Failed to calculate dynamically the maximum memory.
    EvaluatingMinAndMaxMemory = Determines the values of the minimum and maximum memory server configuration option for the instance '{0}'.
    NotActiveNode = The node '{0}' is not actively hosting the instance '{1}'. Will always return success for this resource on this node, until this node is actively hosting the instance.
    WrongMaximumMemory = Current maximum server memory used by the instance is {0}MB, but expected {1}MB.
    WrongMinimumMemory = Current minimum server memory used by the instance is {0}MB, but expected {1}MB.
'@
