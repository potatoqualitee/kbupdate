# Localized resources for DscPullServerSetup

ConvertFrom-StringData @'
    StartDeploymentMessage = Start deployment of Pull Server.
    EndDeploymentMessage = End deployment of Pull Server.
    NoAdditionalModulesPackagedMessage = No additional modules are specified to be packaged.
    SkippingModuleOverwriteMessage = Skipping module overwrite. Module with the name '{0}' already exists.`r`nPlease specify -Force to overwrite the module with the local version of the module located in '{1}' or list names of the modules in ModuleNameList parameter to be packaged from PowerShell module path instead and remove them from '{1}' folder.
    CopyingModulesToPullServerMessage = Copying modules to Pull server module repository skipped because the machine is not a server sku or Pull server endpoint is not deployed.
    CopyingConfigurationsToPullServerMessage = Copying configuration(s) to Pull server configuration repository skipped because the machine is not a server sku or Pull server endpoint is not deployed.
    CopyingModulesAndChecksumsMessage = Copying modules and checksums to '{0}'.
    CopyingMOFsAndChecksumsMessage = Copying MOFs and checksums to '{0}'.
    PublishModuleMessage = Publishing module '{0}' version '{1}' to '{2}'.
    InvalidWebConfigPathError = Web.Config of the pullserver does not exist on the default path '{0}'. Please provide the location of your pullserver web configuration using the parameter -PullServerWebConfig or an alternate path where you want to publish the pullserver modules to. This path should exist.
    InvalidFileTypeError = Invalid file '{0}'. Only MOF files can be copied to the Pull Server configuration repository.
'@
