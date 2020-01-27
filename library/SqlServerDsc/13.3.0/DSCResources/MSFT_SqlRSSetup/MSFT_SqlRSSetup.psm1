$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SqlServerDsc.Common'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SqlServerDsc.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_SqlRSSetup'

<#
    .SYNOPSIS
        Returns the current state of the Microsoft SQL Server Reporting Service
        instance.

    .PARAMETER InstanceName
        Name of the Microsoft SQL Server Reporting Service instance to installed.
        This can only be set to 'SSRS'. { 'SSRS' }

    .PARAMETER IAcceptLicenseTerms
        Accept licens terms. This must be set to 'Yes'. { 'Yes' }

    .PARAMETER SourcePath
        The path to the installation media file to be used for installation,
        e.g an UNC path to a shared resource. Environment variables can be used
        in the path.

    .NOTES
        The following properties are always returning $null because it's currently
        unknown how to return that information.
          - ProductKey
          - Edition

        The following properties always return $null on purpose. This could be
        changed in the future.
          - Action
          - SourceCredential
          - ForceRestart
          - EditionUpgrade
          - VersionUpgrade
          - LogPath

#>
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('SSRS')]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [System.String]
        $IAcceptLicenseTerms,

        [Parameter(Mandatory = $true)]
        [System.String]
        $SourcePath
    )

    $returnObject = @{
        InstanceName = $null
        IAcceptLicenseTerms = $IAcceptLicenseTerms
        SourcePath = $SourcePath
        Action = $null
        SourceCredential = $null
        ProductKey = $null
        ForceRestart = $false
        EditionUpgrade = $false
        VersionUpgrade = $false
        Edition = $null
        LogPath = $null
        InstallFolder = $null
        ErrorDumpDirectory = $null
        CurrentVersion = $null
        ServiceName = $null
    }

    $InstanceName = $InstanceName.ToUpper()

    $getRegistryPropertyValueParameters = @{
        Path = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\RS'
        Name = $InstanceName
    }

    $reportingServiceInstanceId = Get-RegistryPropertyValue @getRegistryPropertyValueParameters
    if ($reportingServiceInstanceId)
    {
        Write-Verbose -Message (
            $script:localizedData.FoundInstance -f $InstanceName
        )

        # InstanceName
        $returnObject['InstanceName'] = $InstanceName

        # InstallFolder
        $getRegistryPropertyValueParameters = @{
            Path = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\SSRS\Setup'
            Name = 'InstallRootDirectory'
        }

        $returnObject['InstallFolder'] = Get-RegistryPropertyValue @getRegistryPropertyValueParameters

        # ServiceName
        $getRegistryPropertyValueParameters['Name'] = 'ServiceName'

        $returnObject['ServiceName'] = Get-RegistryPropertyValue @getRegistryPropertyValueParameters

        # ErrorDumpDirectory
        $getRegistryPropertyValueParameters = @{
            Path = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\SSRS\CPE'
            Name = 'ErrorDumpDir'
        }

        $returnObject['ErrorDumpDirectory'] = Get-RegistryPropertyValue @getRegistryPropertyValueParameters

        # CurrentVersion
        $getPackageParameters = @{
            Name = 'Microsoft SQL Server Reporting Services'
            ProviderName = 'Programs'
            ErrorAction = 'SilentlyContinue'
            # Get-Package returns a lot of excessive information that we don't need.
            Verbose = $false
        }

        $reportingServicesPackage = Get-Package @getPackageParameters
        if ($reportingServicesPackage)
        {
            Write-Verbose -Message (
                $script:localizedData.VersionFound -f $reportingServicesPackage.Version
            )

            $returnObject['CurrentVersion'] = $reportingServicesPackage.Version
        }
        else
        {
            Write-Warning -Message $script:localizedData.PackageNotFound
        }
    }
    else
    {
        Write-Verbose -Message (
            $script:localizedData.InstanceNotFound -f $InstanceName
        )
    }

    return $returnObject
}

<#
    .SYNOPSIS
        Installs the the Microsoft SQL Server Reporting Service instance.

    .PARAMETER InstanceName
        Name of the Microsoft SQL Server Reporting Service instance to installed.
        This can only be set to 'SSRS'. { 'SSRS' }

    .PARAMETER IAcceptLicenseTerms
        Accept licens terms. This must be set to 'Yes'. { 'Yes' }

    .PARAMETER SourcePath
        The path to the installation media file to be used for installation,
        e.g an UNC path to a shared resource. Environment variables can be used
        in the path.

    .PARAMETER Action
        The action to be performed. Default value is 'Install' which performs
        either install or upgrade.
        { *Install* | Uninstall }

    .PARAMETER SourceCredential
        Credentials used to access the path set in the parameter 'SourcePath'.

    .PARAMETER SuppressRestart
        Suppresses any attempts to restart.

    .PARAMETER ProductKey
        Sets the custom license key, e.g. '12345-12345-12345-12345-12345'.

    .PARAMETER ForceRestart
        Forces a restart after installation is finished.

    .PARAMETER EditionUpgrade
        Upgrades the edition of the installed product. Requires that either the
        ProductKey or the Edition parameter is also assigned. Default is $false.

    .PARAMETER VersionUpgrade
        Upgrades installed product version, if the major product version of the
        source executable is higher than the major current version. Requires that
        either the ProductKey or the Edition parameter is also assigned. Default
        is $false.

        Not used in Set-TargetResource. The default is that the installation
        does upgrade. This variable is only used in Test-TargetResource to return
        false if the major version is different.

    .PARAMETER Edition
        Sets the custom free edition.
        { 'Development' | 'Evaluation' | 'ExpressAdvanced' }

    .PARAMETER LogPath
        Specifies the setup log file location, e.g. 'log.txt'. By default, log
        files are created under %TEMP%.

    .PARAMETER InstallFolder
        Sets the install folder, e.g. 'C:\Program Files\SSRS'. Default value is
        'C:\Program Files\Microsoft SQL Server Reporting Services'.

    .PARAMETER SetupProcessTimeout
        The timeout, in seconds, to wait for the setup process to finish.
        Default value is 7200 seconds (2 hours). If the setup process does not
        finish before this time, and error will be thrown.
#>
function Set-TargetResource
{
    <#
        Suppressing this rule because $global:DSCMachineStatus is used to trigger
        a Restart, either by force or when there are pending changes.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    <#
        Suppressing this rule because $global:DSCMachineStatus is only set,
        never used (by design of Desired State Configuration).
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('SSRS')]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [System.String]
        $IAcceptLicenseTerms,

        [Parameter(Mandatory = $true)]
        [System.String]
        $SourcePath,

        [Parameter()]
        [ValidateSet('Install','Uninstall')]
        [System.String]
        $Action = 'Install',

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $SourceCredential,

        [Parameter()]
        [System.Boolean]
        $SuppressRestart,

        [Parameter()]
        [System.String]
        $ProductKey,

        [Parameter()]
        [System.Boolean]
        $ForceRestart,

        [Parameter()]
        [System.Boolean]
        $EditionUpgrade,

        [Parameter()]
        [System.Boolean]
        $VersionUpgrade,

        [Parameter()]
        [ValidateSet('Development','Evaluation','ExpressAdvanced')]
        [System.String]
        $Edition,

        [Parameter()]
        [System.String]
        $LogPath,

        [Parameter()]
        [System.String]
        $InstallFolder,

        [Parameter()]
        [System.UInt32]
        $SetupProcessTimeout = 7200
    )

    # Must either choose ProductKey or Edition, not both.
    if ($Action -eq 'Install' -and $PSBoundParameters.ContainsKey('Edition') -and $PSBoundParameters.ContainsKey('ProductKey'))
    {
        $errorMessage = $script:localizedData.EditionInvalidParameter
        New-InvalidArgumentException -ArgumentName 'Edition, ProductKey' -Message $errorMessage
    }

    # Must either choose ProductKey or Edition, not none.
    if ($Action -eq 'Install' -and -not $PSBoundParameters.ContainsKey('Edition') -and -not $PSBoundParameters.ContainsKey('ProductKey'))
    {
        $errorMessage = $script:localizedData.EditionMissingParameter
        New-InvalidArgumentException -ArgumentName 'Edition, ProductKey' -Message $errorMessage
    }

    if (-not (Test-Path -Path $SourcePath) -or (Get-Item -Path $SourcePath).Extension -ne '.exe')
    {
        $errorMessage = $script:localizedData.SourcePathNotFound -f $SourcePath
        New-InvalidArgumentException -ArgumentName 'SourcePath' -Message $errorMessage
    }

    $InstanceName = $InstanceName.ToUpper()

    $SourcePath = [Environment]::ExpandEnvironmentVariables($SourcePath)

    $parametersToEvaluateTrailingSlash = @(
        'SourcePath',
        'InstallFolder'
    )

    # Making sure paths are correct.
    foreach ($parameterName in $parametersToEvaluateTrailingSlash)
    {
        if ($PSBoundParameters.ContainsKey($parameterName))
        {
            $parameterValue = Get-Variable -Name $parameterName -ValueOnly
            $formattedPath = Format-Path -Path $parameterValue -TrailingSlash
            Set-Variable -Name $parameterName -Value $formattedPath
        }
    }

    if ($SourceCredential)
    {
        $executableParentFolder = Split-Path -Path $SourcePath -Parent
        $executableFileName = Split-Path -Path $SourcePath -Leaf

        $invokeInstallationMediaCopyParameters = @{
            SourcePath = $executableParentFolder
            SourceCredential = $SourceCredential
            PassThru = $true
        }

        $newExecutableParentFolder = Invoke-InstallationMediaCopy @invokeInstallationMediaCopyParameters

        # Switch SourcePath to point to the new local location.
        $SourcePath = Join-Path -Path $newExecutableParentFolder -ChildPath $executableFileName
    }

    Write-Verbose -Message ($script:localizedData.UsingExecutable -f $SourcePath)

    $setupArguments = @{
        Quiet = [System.Management.Automation.SwitchParameter] $true
    }

    if ($Action -eq 'Install')
    {
        $setupArguments += @{
            IAcceptLicenseTerms = [System.Management.Automation.SwitchParameter] $true
        }
    }
    else
    {
        $setupArguments += @{
            'uninstall' =  [System.Management.Automation.SwitchParameter] $true
        }
    }

    <#
        This is a list of parameters that are allowed to be translated into
        arguments.
    #>
    $allowedParametersAsArguments = @(
        'ProductKey'
        'SuppressRestart'
        'EditionUpgrade'
        'Edition'
        'LogPath'
        'InstallFolder'
    )

    $argumentParameters = $PSBoundParameters.Keys | Where-Object -FilterScript {
        $_ -in $allowedParametersAsArguments
    }

    <#
        Handle translation between parameter name and argument name.
        Also making sure using the correct casing, e.g. 'log' and not 'Log'.
    #>
    switch ($argumentParameters)
    {
        'ProductKey'
        {
            $setupArguments += @{
                'PID' = $ProductKey
            }
        }

        'SuppressRestart'
        {
            $setupArguments += @{
                'norestart' = [System.Management.Automation.SwitchParameter] $true
            }
        }

        'EditionUpgrade'
        {
            $setupArguments += @{
                'EditionUpgrade' = [System.Management.Automation.SwitchParameter] $true
            }
        }

        'Edition'
        {
            $setupArguments += @{
                'Edition' = Convert-EditionName -Name $Edition
            }
        }

        'LogPath'
        {
            $setupArguments += @{
                'log' = $LogPath
            }
        }

        default
        {
            $setupArguments += @{
                $_ = Get-Variable -Name $_ -ValueOnly
            }
        }
    }

    # Build the argument string to be passed to setup
    $argumentString = ''
    foreach ($currentSetupArgument in $setupArguments.GetEnumerator())
    {
        # Arrays are handled specially
        if ($currentSetupArgument.Value -is [System.Management.Automation.SwitchParameter])
        {
            $argumentString += '/{0}' -f $currentSetupArgument.Key
        }
        else
        {
            $argumentString += '/{0}={1}' -f $currentSetupArgument.Key, $currentSetupArgument.Value
        }

        # Add a space between arguments.
        $argumentString += ' '
    }

    # Trim whitespace at start and end of string.
    $argumentString = $argumentString.Trim()

    # Save the arguments for the log output
    $logOutput = $argumentString

    # Replace sensitive values for verbose output
    if ($PSBoundParameters.ContainsKey('ProductKey'))
    {
        $logOutput = $logOutput -replace $ProductKey, '*****-*****-*****-*****-*****'
    }

    Write-Verbose -Message ($script:localizedData.SetupArguments -f $logOutput)

    <#
        This handles when PsDscRunAsCredential is set, or running
        as the SYSTEM account.
    #>

    $startProcessParameters = @{
        FilePath = $SourcePath
        ArgumentList = $argumentString
        Timeout = $SetupProcessTimeout
    }

    $processExitCode = Start-SqlSetupProcess @startProcessParameters

    Write-Verbose -Message ($script:localizedData.SetupExitMessage -f $processExitCode)

    if ($Action -eq 'Install')
    {
        $localizedAction = $script:localizedData.Install
    }
    else
    {
        $localizedAction = $script:localizedData.Uninstall
    }

    if ($processExitCode -eq 0)
    {
        Write-Verbose -Message ($script:localizedData.SetupSuccessful -f $localizedAction)
    }
    elseif ($processExitCode -eq 3010)
    {
        Write-Warning -Message ($script:localizedData.SetupSuccessfulRestartRequired -f $localizedAction)

        $global:DSCMachineStatus = 1
    }
    else
    {
        if ($PSBoundParameters.ContainsKey('LogPath'))
        {
            $errorMessage = $script:localizedData.SetupFailedWithLog -f $LogPath
        }
        else
        {
            $errorMessage = $script:localizedData.SetupFailed
        }

        New-InvalidResultException -Message $errorMessage
    }

    <#
        If ForceRestart is set it will always restart, and override SuppressRestart.
        If SuppressRestart is set it will always override any pending restart.
    #>
    if ($ForceRestart)
    {
        $global:DSCMachineStatus = 1
    }
    elseif ($global:DSCMachineStatus -eq 1 -and $SuppressRestart)
    {
        # Suppressing restart to make sure the node is not restarted.
        $global:DSCMachineStatus = 0

        Write-Verbose -Message $script:localizedData.SuppressRestart
    }
    elseif (-not $SuppressRestart -and (Test-PendingRestart))
    {
        $global:DSCMachineStatus = 1
    }

    if ($global:DSCMachineStatus -eq 1)
    {
        Write-Verbose -Message $script:localizedData.Restart
    }
}

<#
    .SYNOPSIS
        Tests if the Microsoft SQL Server Reporting Service instance is installed.

    .PARAMETER InstanceName
        Name of the Microsoft SQL Server Reporting Service instance to installed.
        This can only be set to 'SSRS'. { 'SSRS' }

    .PARAMETER IAcceptLicenseTerms
        Accept licens terms. This must be set to 'Yes'. { 'Yes' }

    .PARAMETER SourcePath
        The path to the installation media file to be used for installation,
        e.g an UNC path to a shared resource. Environment variables can be used
        in the path.

    .PARAMETER Action
        The action to be performed. Default value is 'Install' which performs
        either install or upgrade.
        { *Install* | Uninstall }

    .PARAMETER SourceCredential
        Credentials used to access the path set in the parameter 'SourcePath'.

    .PARAMETER SuppressRestart
        Suppresses any attempts to restart.

    .PARAMETER ProductKey
        Sets the custom license key, e.g. '12345-12345-12345-12345-12345'.

    .PARAMETER ForceRestart
        Forces a restart after installation is finished.

    .PARAMETER EditionUpgrade
        Upgrades the edition of the installed product. Requires that either the
        ProductKey or the Edition parameter is also assigned. Default is $false.

    .PARAMETER VersionUpgrade
        Upgrades installed product version, if the major product version of the
        source executable is higher than the major current version. Requires that
        either the ProductKey or the Edition parameter is also assigned. Default
        is $false.

    .PARAMETER Edition
        Sets the custom free edition.
        { 'Development' | 'Evaluation' | 'ExpressAdvanced' }

    .PARAMETER LogPath
        Specifies the setup log file location, e.g. 'log.txt'. By default, log
        files are created under %TEMP%.

    .PARAMETER InstallFolder
        Sets the install folder, e.g. 'C:\Program Files\SSRS'. Default value is
        'C:\Program Files\Microsoft SQL Server Reporting Services'.

    .PARAMETER SetupProcessTimeout
        The timeout, in seconds, to wait for the setup process to finish.
        Default value is 7200 seconds (2 hours). If the setup process does not
        finish before this time, and error will be thrown.
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('SSRS')]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [System.String]
        $IAcceptLicenseTerms,

        [Parameter(Mandatory = $true)]
        [System.String]
        $SourcePath,

        [Parameter()]
        [ValidateSet('Install','Uninstall')]
        [System.String]
        $Action = 'Install',

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $SourceCredential,

        [Parameter()]
        [System.Boolean]
        $SuppressRestart,

        [Parameter()]
        [System.String]
        $ProductKey,

        [Parameter()]
        [System.Boolean]
        $ForceRestart,

        [Parameter()]
        [System.Boolean]
        $EditionUpgrade,

        [Parameter()]
        [System.Boolean]
        $VersionUpgrade,

        [Parameter()]
        [ValidateSet('Development','Evaluation','ExpressAdvanced')]
        [System.String]
        $Edition,

        [Parameter()]
        [System.String]
        $LogPath,

        [Parameter()]
        [System.String]
        $InstallFolder,

        [Parameter()]
        [System.UInt32]
        $SetupProcessTimeout = 7200
    )

    Write-Verbose -Message (
        $script:localizedData.TestingConfiguration
    )

    $getTargetResourceParameters = @{
        InstanceName = $InstanceName
        IAcceptLicenseTerms = $IAcceptLicenseTerms
        SourcePath = $SourcePath
    }

    $getTargetResourceResult = Get-TargetResource @getTargetResourceParameters

    $returnValue = $false

    <#
        We determine if the Microsoft SQL Server Reporting Service instance is
        installed if the instance name is found in the registry.
    #>
    if ($Action -eq 'Install')
    {
        $fileVersion = Get-FileProductVersion -Path $SourcePath

        if ($getTargetResourceResult.InstanceName)
        {
            $installedVersion = [System.Version] $getTargetResourceResult.CurrentVersion

            # The major version is evaluated if VersionUpgrade is set to $true
            if (-not $VersionUpgrade -or ($VersionUpgrade -and $installedVersion -ge $fileVersion))
            {
                $returnValue = $true
            }
            else
            {
                Write-Verbose -Message (
                    $script:localizedData.WrongVersionFound `
                        -f $fileVersion.ToString(), $installedVersion.ToString()
                )
            }
        }
        else
        {
            Write-Verbose -Message (
                $script:localizedData.MissingVersion `
                    -f $fileVersion.ToString()
            )
        }
    }

    if ($Action -eq 'Uninstall' -and $null -eq $getTargetResourceResult.InstanceName)
    {
        $returnValue = $true
    }

    return $returnValue
}

<#
    .SYNOPSIS
        Converts between the edition names used by the resource and the
        installation media.

    .PARAMETER Name
        The edition name to convert.

    .OUTPUTS
        Returns the equivalent name of what was provided in the parameter Name.
        For example, if Name is set to 'Dev', the cmdlet returns 'Development'.
        If Name is set to 'Development', the cmdlet returns 'Dev'.
#>
function Convert-EditionName
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name
    )

    switch ($Name)
    {
        # Resource edition names
        'Development'
        {
            $convertEditionNameResult = 'Dev'
        }

        'Evaluation'
        {
            $convertEditionNameResult = 'Eval'
        }

        'ExpressAdvanced'
        {
            $convertEditionNameResult = 'ExprAdv'
        }

        # Installation media edition names
        'Dev'
        {
            $convertEditionNameResult = 'Development'
        }

        'Eval'
        {
            $convertEditionNameResult = 'Evaluation'
        }

        'ExprAdv'
        {
            $convertEditionNameResult = 'ExpressAdvanced'
        }
    }

    return $convertEditionNameResult
}

<#
    .SYNOPSIS
        Gets the product version of a executable.

    .PARAMETER Path
        The path to the executable to return product version for.

    .OUTPUTS
        Returns the product version as [System.Version] type.
#>
function Get-FileProductVersion
{
    [CmdletBinding()]
    [OutputType([System.Version])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path
    )

    return [System.Version] (Get-Item -Path $Path).VersionInfo.ProductVersion
}
