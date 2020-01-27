ConvertFrom-StringData @'
    GetConfiguration = Getting the max degree of parallelism server configuration option for instance '{0}'.
    SetConfiguration = Setting the max degree of parallelism server configuration option for instance '{0}'.
    DynamicMaxDop = The dynamically calculated value for max degree of parallelism is '{0}'.
    MaxDopParamMustBeNull = The parameter max degree of parallelism must be set to $null or not assigned if the parameter DynamicAlloc is set to $true.
    MaxDopSetError = Unexpected result when trying to configure the max degree of parallelism server configuration option.
    SettingDefaultValue = Desired state should be absent, so max degree of parallelism will be reset to the default value '{0}'.
    ChangeValue = Changed the value for max degree of parallelism to '{0}'.
    EvaluationConfiguration = Determines the current value for the max degree of parallelism server configuration option.
    NotActiveNode = The node '{0}' is not actively hosting the instance '{1}'. Will always return success for this resource on this node, until this node is actively hosting the instance.
    WrongMaxDop = The current value for max degree of parallelism is '{0}', but expected '{1}'.
'@
