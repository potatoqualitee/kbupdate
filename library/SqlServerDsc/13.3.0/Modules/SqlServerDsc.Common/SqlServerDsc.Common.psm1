$script:modulesFolderPath = Split-Path -Path $PSScriptRoot -Parent

<#
    .SYNOPSIS
        Retrieves the localized string data based on the machine's culture.
        Falls back to en-US strings if the machine's culture is not supported.

    .PARAMETER ResourceName
        The name of the resource as it appears before '.strings.psd1' of the localized string file.
        For example:
            For WindowsOptionalFeature: MSFT_WindowsOptionalFeature
            For Service: MSFT_ServiceResource
            For Registry: MSFT_RegistryResource
            For Helper: SqlServerDscHelper

    .PARAMETER ScriptRoot
        Optional. The root path where to expect to find the culture folder. This is only needed
        for localization in helper modules. This should not normally be used for resources.

    .NOTES
        To be able to use localization in the helper function, this function must
        be first in the file, before Get-LocalizedData is used by itself to load
        localized data for this helper module (see directly after this function).
#>
function Get-LocalizedData
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ResourceName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ScriptRoot
    )

    if (-not $ScriptRoot)
    {
        $dscResourcesFolder = Join-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -ChildPath 'DSCResources'
        $resourceDirectory = Join-Path -Path $dscResourcesFolder -ChildPath $ResourceName
    }
    else
    {
        $resourceDirectory = $ScriptRoot
    }

    $localizedStringFileLocation = Join-Path -Path $resourceDirectory -ChildPath $PSUICulture

    if (-not (Test-Path -Path $localizedStringFileLocation))
    {
        # Fallback to en-US
        $localizedStringFileLocation = Join-Path -Path $resourceDirectory -ChildPath 'en-US'
    }

    Import-LocalizedData `
        -BindingVariable 'localizedData' `
        -FileName "$ResourceName.strings.psd1" `
        -BaseDirectory $localizedStringFileLocation

    return $localizedData
}

<#
    .SYNOPSIS
        Creates and throws an invalid argument exception.

    .PARAMETER Message
        The message explaining why this error is being thrown.

    .PARAMETER ArgumentName
        The name of the invalid argument that is causing this error to be thrown.
#>
function New-InvalidArgumentException
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ArgumentName
    )

    $argumentException = New-Object -TypeName 'ArgumentException' `
        -ArgumentList @($Message, $ArgumentName)

    $newObjectParameters = @{
        TypeName     = 'System.Management.Automation.ErrorRecord'
        ArgumentList = @($argumentException, $ArgumentName, 'InvalidArgument', $null)
    }

    $errorRecord = New-Object @newObjectParameters

    throw $errorRecord
}

<#
    .SYNOPSIS
        Creates and throws an invalid operation exception.

    .PARAMETER Message
        The message explaining why this error is being thrown.

    .PARAMETER ErrorRecord
        The error record containing the exception that is causing this terminating error.
#>
function New-InvalidOperationException
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    if ($null -eq $ErrorRecord)
    {
        $invalidOperationException = New-Object -TypeName 'InvalidOperationException' `
            -ArgumentList @($Message)
    }
    else
    {
        $invalidOperationException = New-Object -TypeName 'InvalidOperationException' `
            -ArgumentList @($Message, $ErrorRecord.Exception)
    }

    $newObjectParameters = @{
        TypeName     = 'System.Management.Automation.ErrorRecord'
        ArgumentList = @(
            $invalidOperationException.ToString(),
            'MachineStateIncorrect',
            'InvalidOperation',
            $null
        )
    }

    $errorRecordToThrow = New-Object @newObjectParameters

    throw $errorRecordToThrow
}

<#
    .SYNOPSIS
        Creates and throws an object not found exception.

    .PARAMETER Message
        The message explaining why this error is being thrown.

    .PARAMETER ErrorRecord
        The error record containing the exception that is causing this terminating error.
#>
function New-ObjectNotFoundException
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    if ($null -eq $ErrorRecord)
    {
        $exception = New-Object -TypeName 'System.Exception' `
            -ArgumentList @($Message)
    }
    else
    {
        $exception = New-Object -TypeName 'System.Exception' `
            -ArgumentList @($Message, $ErrorRecord.Exception)
    }

    $newObjectParameters = @{
        TypeName     = 'System.Management.Automation.ErrorRecord'
        ArgumentList = @(
            $exception.ToString(),
            'MachineStateIncorrect',
            'ObjectNotFound',
            $null
        )
    }

    $errorRecordToThrow = New-Object @newObjectParameters

    throw $errorRecordToThrow
}

<#
    .SYNOPSIS
        Creates and throws an invalid result exception.

    .PARAMETER Message
        The message explaining why this error is being thrown.

    .PARAMETER ErrorRecord
        The error record containing the exception that is causing this terminating error.
#>
function New-InvalidResultException
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    if ($null -eq $ErrorRecord)
    {
        $exception = New-Object -TypeName 'System.Exception' `
            -ArgumentList @($Message)
    }
    else
    {
        $exception = New-Object -TypeName 'System.Exception' `
            -ArgumentList @($Message, $ErrorRecord.Exception)
    }

    $newObjectParameters = @{
        TypeName     = 'System.Management.Automation.ErrorRecord'
        ArgumentList = @(
            $exception.ToString(),
            'MachineStateIncorrect',
            'InvalidResult',
            $null
        )
    }

    $errorRecordToThrow = New-Object @newObjectParameters

    throw $errorRecordToThrow
}

<#
    .SYNOPSIS
        Creates and throws an not implemented exception.

    .PARAMETER Message
        The message explaining why this error is being thrown.

    .PARAMETER ErrorRecord
        The error record containing the exception that is causing this terminating error.
        '
    .NOTES
        The error categories can be found here:
        https://docs.microsoft.com/en-us/dotnet/api/system.management.automation.errorcategory
#>
function New-NotImplementedException
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    if ($null -eq $ErrorRecord)
    {
        $invalidOperationException = New-Object -TypeName 'NotImplementedException' `
            -ArgumentList @($Message)
    }
    else
    {
        $invalidOperationException = New-Object -TypeName 'NotImplementedException' `
            -ArgumentList @($Message, $ErrorRecord.Exception)
    }

    $newObjectParameters = @{
        TypeName     = 'System.Management.Automation.ErrorRecord'
        ArgumentList = @(
            $invalidOperationException.ToString(),
            'MachineStateIncorrect',
            'NotImplemented',
            $null
        )
    }

    $errorRecordToThrow = New-Object @newObjectParameters

    throw $errorRecordToThrow
}

<#
    .SYNOPSIS
        This method is used to compare current and desired values for any DSC resource.

    .PARAMETER CurrentValues
        This is hash table of the current values that are applied to the resource.

    .PARAMETER DesiredValues
        This is a PSBoundParametersDictionary of the desired values for the resource.

    .PARAMETER ValuesToCheck
        This is a list of which properties in the desired values list should be checked.
        If this is empty then all values in DesiredValues are checked.
#>
function Test-DscParameterState
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $CurrentValues,

        [Parameter(Mandatory = $true)]
        [System.Object]
        $DesiredValues,

        [Parameter()]
        [System.Array]
        $ValuesToCheck
    )

    $returnValue = $true

    if (($DesiredValues.GetType().Name -ne 'HashTable') `
        -and ($DesiredValues.GetType().Name -ne 'CimInstance') `
        -and ($DesiredValues.GetType().Name -ne 'PSBoundParametersDictionary'))
    {
        $errorMessage = $script:localizedData.PropertyTypeInvalidForDesiredValues -f $($DesiredValues.GetType().Name)
        New-InvalidArgumentException -ArgumentName 'DesiredValues' -Message $errorMessage
    }

    if (($DesiredValues.GetType().Name -eq 'CimInstance') -and ($null -eq $ValuesToCheck))
    {
        $errorMessage = $script:localizedData.PropertyTypeInvalidForValuesToCheck
        New-InvalidArgumentException -ArgumentName 'ValuesToCheck' -Message $errorMessage
    }

    if (($null -eq $ValuesToCheck) -or ($ValuesToCheck.Count -lt 1))
    {
        $keyList = $DesiredValues.Keys
    }
    else
    {
        $keyList = $ValuesToCheck
    }

    $keyList | ForEach-Object -Process {
        if (($_ -ne 'Verbose'))
        {
            if (($CurrentValues.ContainsKey($_) -eq $false) `
            -or ($CurrentValues.$_ -ne $DesiredValues.$_) `
            -or (($DesiredValues.GetType().Name -ne 'CimInstance' -and $DesiredValues.ContainsKey($_) -eq $true) -and ($null -ne $DesiredValues.$_ -and $DesiredValues.$_.GetType().IsArray)))
            {
                if ($DesiredValues.GetType().Name -eq 'HashTable' -or `
                    $DesiredValues.GetType().Name -eq 'PSBoundParametersDictionary')
                {
                    $checkDesiredValue = $DesiredValues.ContainsKey($_)
                }
                else
                {
                    # If DesiredValue is a CimInstance.
                    $checkDesiredValue = $false
                    if (([System.Boolean]($DesiredValues.PSObject.Properties.Name -contains $_)) -eq $true)
                    {
                        if ($null -ne $DesiredValues.$_)
                        {
                            $checkDesiredValue = $true
                        }
                    }
                }

                if ($checkDesiredValue)
                {
                    $desiredType = $DesiredValues.$_.GetType()
                    $fieldName = $_
                    if ($desiredType.IsArray -eq $true)
                    {
                        if (($CurrentValues.ContainsKey($fieldName) -eq $false) `
                        -or ($null -eq $CurrentValues.$fieldName))
                        {
                            Write-Verbose -Message ($script:localizedData.PropertyValidationError -f $fieldName) -Verbose

                            $returnValue = $false
                        }
                        else
                        {
                            $arrayCompare = Compare-Object -ReferenceObject $CurrentValues.$fieldName `
                                                           -DifferenceObject $DesiredValues.$fieldName
                            if ($null -ne $arrayCompare)
                            {
                                Write-Verbose -Message ($script:localizedData.PropertiesDoesNotMatch -f $fieldName) -Verbose

                                $arrayCompare | ForEach-Object -Process {
                                    Write-Verbose -Message ($script:localizedData.PropertyThatDoesNotMatch -f $_.InputObject, $_.SideIndicator) -Verbose
                                }

                                $returnValue = $false
                            }
                        }
                    }
                    else
                    {
                        switch ($desiredType.Name)
                        {
                            'String'
                            {
                                if (-not [System.String]::IsNullOrEmpty($CurrentValues.$fieldName) -or `
                                    -not [System.String]::IsNullOrEmpty($DesiredValues.$fieldName))
                                {
                                    Write-Verbose -Message ($script:localizedData.ValueOfTypeDoesNotMatch `
                                        -f $desiredType.Name, $fieldName, $($CurrentValues.$fieldName), $($DesiredValues.$fieldName)) -Verbose

                                    $returnValue = $false
                                }
                            }

                            'Int32'
                            {
                                if (-not ($DesiredValues.$fieldName -eq 0) -or `
                                    -not ($null -eq $CurrentValues.$fieldName))
                                {
                                    Write-Verbose -Message ($script:localizedData.ValueOfTypeDoesNotMatch `
                                        -f $desiredType.Name, $fieldName, $($CurrentValues.$fieldName), $($DesiredValues.$fieldName)) -Verbose

                                    $returnValue = $false
                                }
                            }

                            { $_ -eq 'Int16' -or $_ -eq 'UInt16' -or $_ -eq 'Single' }
                            {
                                if (-not ($DesiredValues.$fieldName -eq 0) -or `
                                    -not ($null -eq $CurrentValues.$fieldName))
                                {
                                    Write-Verbose -Message ($script:localizedData.ValueOfTypeDoesNotMatch `
                                        -f $desiredType.Name, $fieldName, $($CurrentValues.$fieldName), $($DesiredValues.$fieldName)) -Verbose

                                    $returnValue = $false
                                }
                            }

                            'Boolean'
                            {
                                if ($CurrentValues.$fieldName -ne $DesiredValues.$fieldName)
                                {
                                    Write-Verbose -Message ($script:localizedData.ValueOfTypeDoesNotMatch `
                                        -f $desiredType.Name, $fieldName, $($CurrentValues.$fieldName), $($DesiredValues.$fieldName)) -Verbose

                                    $returnValue = $false
                                }
                            }

                            default
                            {
                                Write-Warning -Message ($script:localizedData.UnableToCompareProperty `
                                    -f $fieldName, $desiredType.Name)

                                $returnValue = $false
                            }
                        }
                    }
                }
            }
        }
    }

    return $returnValue
}

<#
    .SYNOPSIS
        Returns the value of the provided in the Name parameter, at the registry
        location provided in the Path parameter.

    .PARAMETER Path
        String containing the path in the registry to the property name.

    .PARAMETER PropertyName
        String containing the name of the property for which the value is returned.
#>
function Get-RegistryPropertyValue
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Name
    )

    $getItemPropertyParameters = @{
        Path = $Path
        Name = $Name
    }

    <#
        Using a try/catch block instead of 'SilentlyContinue' to be
        able to unit test a failing registry path.
    #>
    try
    {
        $getItemPropertyResult = (Get-ItemProperty @getItemPropertyParameters -ErrorAction Stop).$Name
    }
    catch
    {
         $getItemPropertyResult = $null
    }

    return $getItemPropertyResult
}

<#
    .SYNOPSIS
        Returns the value of the provided in the Name parameter, at the registry
        location provided in the Path parameter.

    .PARAMETER Path
        String containing the path in the registry to the property name.

    .PARAMETER PropertyName
        String containing the name of the property for which the value is returned.
#>
function Format-Path
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $TrailingSlash
    )

    # Remove trailing slash ('\') from path.
    if ($TrailingSlash.IsPresent)
    {
        <#
            Trim backslash, but only if the path contains a full path and
            not just a qualifier.
        #>
        if ($Path -notmatch '^[a-zA-Z]:\\$')
        {
            $Path = $Path.TrimEnd('\')
        }

        <#
            If the path only contains a qualifier but no backslash ('M:'),
            then a backslash is added ('M:\').
        #>
        if ($Path -match '^[a-zA-Z]:$')
        {
            $Path = '{0}\' -f $Path
        }
    }

    return $Path
}

<#
    .SYNOPSIS
        Copy folder structure using Robocopy. Every file and folder, including empty ones are copied.

    .PARAMETER Path
        Source path to be copied.

    .PARAMETER DestinationPath
        The path to the destination.
#>
function Copy-ItemWithRobocopy
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DestinationPath
    )

    $quotedPath = '"{0}"' -f $Path
    $quotedDestinationPath = '"{0}"' -f $DestinationPath
    $robocopyExecutable = Get-Command -Name "Robocopy.exe" -ErrorAction Stop

    $robocopyArgumentSilent = '/njh /njs /ndl /nc /ns /nfl'
    $robocopyArgumentCopySubDirectoriesIncludingEmpty = '/e'
    $robocopyArgumentDeletesDestinationFilesAndDirectoriesNotExistAtSource = '/purge'

    if ([System.Version]$robocopyExecutable.FileVersionInfo.ProductVersion -ge [System.Version]'6.3.9600.16384')
    {
        Write-Verbose -Message $script:localizedData.RobocopyUsingUnbufferedIo -Verbose

        $robocopyArgumentUseUnbufferedIO = '/J'
    }
    else
    {
        Write-Verbose -Message $script:localizedData.RobocopyNotUsingUnbufferedIo -Verbose
    }

    $robocopyArgumentList = '{0} {1} {2} {3} {4} {5}' -f $quotedPath,
                                                         $quotedDestinationPath,
                                                         $robocopyArgumentCopySubDirectoriesIncludingEmpty,
                                                         $robocopyArgumentDeletesDestinationFilesAndDirectoriesNotExistAtSource,
                                                         $robocopyArgumentUseUnbufferedIO,
                                                         $robocopyArgumentSilent

    $robocopyStartProcessParameters = @{
        FilePath = $robocopyExecutable.Name
        ArgumentList = $robocopyArgumentList
    }

    Write-Verbose -Message ($script:localizedData.RobocopyArguments -f $robocopyArgumentList) -Verbose
    $robocopyProcess = Start-Process @robocopyStartProcessParameters -Wait -NoNewWindow -PassThru

    switch ($($robocopyProcess.ExitCode))
    {
        {$_ -in 8, 16}
        {
            $errorMessage = $script:localizedData.RobocopyErrorCopying -f $_
            New-InvalidOperationException -Message $errorMessage
        }

        {$_ -gt 7 }
        {
            $errorMessage = $script:localizedData.RobocopyFailuresCopying -f $_
            New-InvalidResultException -Message $errorMessage
        }

        1
        {
            Write-Verbose -Message $script:localizedData.RobocopySuccessful -Verbose
        }

        2
        {
            Write-Verbose -Message $script:localizedData.RobocopyRemovedExtraFilesAtDestination -Verbose
        }

        3
        {
            Write-Verbose -Message (
                '{0} {1}' -f $script:localizedData.RobocopySuccessful, $script:localizedData.RobocopyRemovedExtraFilesAtDestination
            ) -Verbose
        }

        {$_ -eq 0 -or $null -eq $_ }
        {
            Write-Verbose -Message $script:localizedData.RobocopyAllFilesPresent -Verbose
        }
    }
}

<#
    .SYNOPSIS
        Returns the path of the current user's temporary folder.
#>
function Get-TemporaryFolder
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param ()

    return [IO.Path]::GetTempPath()
}

<#
    .SYNOPSIS
        Connects to the source using the provided credentials and then uses
        robocopy to download the installation media to a local temporary folder.

    .PARAMETER SourcePath
        Source path to be copied.

    .PARAMETER SourceCredential
        The credentials to access the SourcePath.

    .PARAMETER PassThru
        If used, returns the destination path as string.

    .OUTPUTS
        Returns the destination path (when used with the parameter PassThru).
#>
function Invoke-InstallationMediaCopy
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $SourcePath,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $SourceCredential,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $PassThru
    )

    Connect-UncPath -RemotePath $SourcePath -SourceCredential $SourceCredential

    <#
        Create a destination folder so the media files aren't written
        to the root of the Temp folder.
    #>
    $mediaDestinationFolder = Split-Path -Path $SourcePath -Leaf
    if (-not $mediaDestinationFolder )
    {
        $mediaDestinationFolder = New-Guid | Select-Object -ExpandProperty Guid
    }

    $mediaDestinationPath = Join-Path -Path (Get-TemporaryFolder) -ChildPath $mediaDestinationFolder

    Write-Verbose -Message ($script:localizedData.RobocopyIsCopying -f $SourcePath, $mediaDestinationPath) -Verbose
    Copy-ItemWithRobocopy -Path $SourcePath -DestinationPath $mediaDestinationPath

    Disconnect-UncPath -RemotePath $SourcePath

    if ($PassThru.IsPresent)
    {
        return $mediaDestinationPath
    }
}

<#
    .SYNOPSIS
        Connects to the UNC path provided in the parameter SourcePath.
        Optionally connects using the provided credentials.

    .PARAMETER SourcePath
        Source path to connect to.

    .PARAMETER SourceCredential
        The credentials to access the path provided in SourcePath.

    .PARAMETER PassThru
        If used, returns a MSFT_SmbMapping object that represents the newly
        created SMB mapping.

    .OUTPUTS
        Returns a MSFT_SmbMapping object that represents the newly created
        SMB mapping (ony when used with parameter PassThru).
#>
function Connect-UncPath
{
    [CmdletBinding()]
    [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $RemotePath,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $SourceCredential,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $PassThru
    )

    $newSmbMappingParameters = @{
        RemotePath = $RemotePath
    }

    if ($PSBoundParameters.ContainsKey('SourceCredential'))
    {
        $newSmbMappingParameters['UserName'] = "$($SourceCredential.GetNetworkCredential().Domain)\$($SourceCredential.GetNetworkCredential().UserName)"
        $newSmbMappingParameters['Password'] = $SourceCredential.GetNetworkCredential().Password
    }

    $newSmbMappingResult = New-SmbMapping @newSmbMappingParameters

    if ($PassThru.IsPresent)
    {
        return $newSmbMappingResult
    }
}

<#
    .SYNOPSIS
        Disconnects from the UNC path provided in the parameter SourcePath.

    .PARAMETER SourcePath
        Source path to disconnect from.
#>
function Disconnect-UncPath
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $RemotePath
    )

    Remove-SmbMapping -RemotePath $RemotePath -Force
}

<#
    .SYNOPSIS
        Queries the registry and returns $true if there is a pending reboot.

    .OUTPUTS
        Returns $true if there is a pending reboot, otherwise it returns $false.
#>
function Test-PendingRestart
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
    )

    $getRegistryPropertyValueParameters = @{
        Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
        Name = 'PendingFileRenameOperations'
    }

    <#
        If the key 'PendingFileRenameOperations' does not exist then if should
        return $false, otherwise it should return $true.
    #>
    return $null -ne (Get-RegistryPropertyValue @getRegistryPropertyValueParameters)
}

<#
    .SYNOPSIS
        Starts the SQL setup process.

    .PARAMETER FilePath
        String containing the path to setup.exe.

    .PARAMETER ArgumentList
        The arguments that should be passed to setup.exe.

    .PARAMETER Timeout
        The timeout in seconds to wait for the process to finish.
#>
function Start-SqlSetupProcess
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $FilePath,

        [Parameter()]
        [System.String]
        $ArgumentList,

        [Parameter(Mandatory = $true)]
        [System.UInt32]
        $Timeout
    )

    $startProcessParameters = @{
        FilePath = $FilePath
        ArgumentList = $ArgumentList
    }

    $sqlSetupProcess = Start-Process @startProcessParameters -PassThru -NoNewWindow -ErrorAction Stop

    Write-Verbose -Message ($script:localizedData.StartSetupProcess -f $sqlSetupProcess.Id, $startProcessParameters.FilePath, $Timeout) -Verbose

    Wait-Process -InputObject $sqlSetupProcess -Timeout $Timeout -ErrorAction Stop

    return $sqlSetupProcess.ExitCode
}

<#
    .SYNOPSIS
        Connect to a SQL Server Database Engine and return the server object.

    .PARAMETER ServerName
        String containing the host name of the SQL Server to connect to.
        Defaults to $env:COMPUTERNAME.

    .PARAMETER InstanceName
        String containing the SQL Server Database Engine instance to connect to.
        Defaults to 'MSSQLSERVER'.

    .PARAMETER SetupCredential
        The credentials to use to impersonate a user when connecting to the
        SQL Server Database Engine instance. If this parameter is left out, then
        the current user will be used to connect to the SQL Server Database Engine
        instance using Windows Integrated authentication.

    .PARAMETER LoginType
        Specifies which type of logon credential should be used. The valid types
        are 'WindowsUser' or 'SqlLogin'. Defaults to 'WindowsUser'
        If set to 'WindowsUser' then the it will impersonate using the Windows
        login specified in the parameter SetupCredential.
        If set to 'WindowsUser' then the it will impersonate using the native SQL
        login specified in the parameter SetupCredential.

    .PARAMETER StatementTimeout
        Set the query StatementTimeout in seconds. Default 600 seconds (10 minutes).

    .EXAMPLE
        Connect-SQL

        Connects to the default instance on the local server.

    .EXAMPLE
        Connect-SQL -InstanceName 'MyInstance'

        Connects to the instance 'MyInstance' on the local server.

    .EXAMPLE
        Connect-SQL ServerName 'sql.company.local' -InstanceName 'MyInstance'

        Connects to the instance 'MyInstance' on the server 'sql.company.local'.
#>
function Connect-SQL
{
    [CmdletBinding(DefaultParameterSetName='SqlServer')]
    param
    (
        [Parameter(ParameterSetName='SqlServer')]
        [Parameter(ParameterSetName='SqlServerWithCredential')]
        [ValidateNotNull()]
        [System.String]
        $ServerName = $env:COMPUTERNAME,

        [Parameter(ParameterSetName='SqlServer')]
        [Parameter(ParameterSetName='SqlServerWithCredential')]
        [ValidateNotNull()]
        [System.String]
        $InstanceName = 'MSSQLSERVER',

        [Parameter(ParameterSetName='SqlServerWithCredential', Mandatory = $true)]
        [ValidateNotNull()]
        [Alias('DatabaseCredential')]
        [System.Management.Automation.PSCredential]
        $SetupCredential,

        [Parameter(ParameterSetName='SqlServerWithCredential')]
        [ValidateSet('WindowsUser', 'SqlLogin')]
        [System.String]
        $LoginType = 'WindowsUser',

        [Parameter()]
        [ValidateNotNull()]
        [System.Int32]
        $StatementTimeout = 600
    )

    Import-SQLPSModule

    if ($InstanceName -eq 'MSSQLSERVER')
    {
        $databaseEngineInstance = $ServerName
    }
    else
    {
        $databaseEngineInstance = '{0}\{1}' -f $ServerName, $InstanceName
    }

    $sqlServerObject  = New-Object -TypeName 'Microsoft.SqlServer.Management.Smo.Server'
    $sqlConnectionContext = $sqlServerObject.ConnectionContext
    $sqlConnectionContext.ServerInstance = $databaseEngineInstance
    $sqlConnectionContext.StatementTimeout = $StatementTimeout
    $sqlConnectionContext.ApplicationName = 'SqlServerDsc'

    if ($PSCmdlet.ParameterSetName -eq 'SqlServer')
    {
        <#
            This is only used for verbose messaging and not for the connection
            string since this is using Integrated Security=true (SSPI).
        #>
        $connectUserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

        Write-Verbose -Message (
            $script:localizedData.ConnectingUsingIntegrated -f $connectUsername
        ) -Verbose
    }
    else
    {
        $connectUserName = $SetupCredential.GetNetworkCredential().UserName

        Write-Verbose -Message (
            $script:localizedData.ConnectingUsingImpersonation -f $connectUsername, $LoginType
        ) -Verbose

        if ($LoginType -eq 'SqlLogin')
        {
            $sqlConnectionContext.LoginSecure = $false
            $sqlConnectionContext.Login = $connectUserName
            $sqlConnectionContext.SecurePassword = $SetupCredential.Password
        }

        if ($LoginType -eq 'WindowsUser')
        {
            $sqlConnectionContext.LoginSecure = $true
            $sqlConnectionContext.ConnectAsUser = $true
            $sqlConnectionContext.ConnectAsUserName = $connectUserName
            $sqlConnectionContext.ConnectAsUserPassword = $SetupCredential.GetNetworkCredential().Password
        }
    }

    try
    {
        $sqlConnectionContext.Connect()

        if ($sqlServerObject.Status -match '^Online$')
        {
            Write-Verbose -Message (
                $script:localizedData.ConnectedToDatabaseEngineInstance -f $databaseEngineInstance
            ) -Verbose

            return $sqlServerObject
        }
        else
        {
            throw
        }
    }
    catch
    {
        $errorMessage = $script:localizedData.FailedToConnectToDatabaseEngineInstance -f $databaseEngineInstance
        New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
    }
    finally
    {
        <#
            Connect will ensure we actually can connect, but we need to disconnect
            from the session so we don't have anything hanging. If we need run a
            method on the returned $sqlServerObject it will automatically open a
            new session and then close, therefore we don't need to keep this
            session open.
        #>
        $sqlConnectionContext.Disconnect()
    }
}

<#
    .SYNOPSIS
        Connect to a SQL Server Analysis Service and return the server object.

    .PARAMETER ServerName
        String containing the host name of the SQL Server to connect to.

    .PARAMETER InstanceName
        String containing the SQL Server Analysis Service instance to connect to.

    .PARAMETER SetupCredential
        PSCredential object with the credentials to use to impersonate a user when connecting.
        If this is not provided then the current user will be used to connect to the SQL Server Analysis Service instance.
#>
function Connect-SQLAnalysis
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName = $env:COMPUTERNAME,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $InstanceName = 'MSSQLSERVER',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $SetupCredential
    )

    $null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.AnalysisServices')

    if ($InstanceName -eq 'MSSQLSERVER')
    {
        $analysisServiceInstance = $ServerName
    }
    else
    {
        $analysisServiceInstance = "$ServerName\$InstanceName"
    }

    if ($SetupCredential)
    {
        $userName = $SetupCredential.GetNetworkCredential().UserName
        $password = $SetupCredential.GetNetworkCredential().Password

        $analysisServicesDataSource = "Data Source=$analysisServiceInstance;User ID=$userName;Password=$password"
    }
    else
    {
        $analysisServicesDataSource = "Data Source=$analysisServiceInstance"
    }

    try
    {
        $analysisServicesObject = New-Object -TypeName Microsoft.AnalysisServices.Server
        if ($analysisServicesObject)
        {
            $analysisServicesObject.Connect($analysisServicesDataSource)
        }
        else
        {
            $errorMessage = $script:localizedData.FailedToConnectToAnalysisServicesInstance -f $analysisServiceInstance
            New-InvalidOperationException -Message $errorMessage
        }

        Write-Verbose -Message ($script:localizedData.ConnectedToAnalysisServicesInstance -f $analysisServiceInstance) -Verbose
    }
    catch
    {
        $errorMessage = $script:localizedData.FailedToConnectToAnalysisServicesInstance -f $analysisServiceInstance
        New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
    }

    return $analysisServicesObject
}

<#
    .SYNOPSIS
        Returns the major SQL version for the specific instance.

    .PARAMETER InstanceName
        String containing the name of the SQL instance to be configured. Default value is 'MSSQLSERVER'.

    .OUTPUTS
        System.UInt16. Returns the SQL Server major version number.
#>
function Get-SqlInstanceMajorVersion
{
    [CmdletBinding()]
    [OutputType([System.UInt16])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName = 'MSSQLSERVER'
    )

    $sqlInstanceId = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL').$InstanceName
    $sqlVersion = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$sqlInstanceId\Setup").Version

    if (-not $sqlVersion)
    {
        $errorMessage = $script:localizedData.SqlServerVersionIsInvalid -f $InstanceName
        New-InvalidResultException -Message $errorMessage
    }

    [System.UInt16] $sqlMajorVersionNumber = $sqlVersion.Split('.')[0]

    return $sqlMajorVersionNumber
}

<#
    .SYNOPSIS
        Imports the module SQLPS in a standardized way.

    .PARAMETER Force
        Forces the removal of the previous SQL module, to load the same or newer
        version fresh.
        This is meant to make sure the newest version is used, with the latest
        assemblies.

#>
function Import-SQLPSModule
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [Switch]
        $Force
    )

    if ($Force.IsPresent)
    {
        Write-Verbose -Message $script:localizedData.ModuleForceRemoval -Verbose
        Remove-Module -Name @('SqlServer','SQLPS','SQLASCmdlets') -Force -ErrorAction SilentlyContinue
    }

    <#
        Check if either of the modules are already loaded into the session.
        Prefer to use the first one (in order found).
        NOTE: There should actually only be either SqlServer or SQLPS loaded,
        otherwise there can be problems with wrong assemblies being loaded.
    #>
    $loadedModuleName = (Get-Module -Name @('SqlServer', 'SQLPS') | Select-Object -First 1).Name
    if ($loadedModuleName)
    {
        Write-Verbose -Message ($script:localizedData.PowerShellModuleAlreadyImported -f $loadedModuleName) -Verbose
        return
    }

    $availableModuleName = $null

    # Get the newest SqlServer module if more than one exist
    $availableModule = Get-Module -FullyQualifiedName 'SqlServer' -ListAvailable |
        Sort-Object -Property 'Version' -Descending |
        Select-Object -First 1 -Property Name, Path, Version

    if ($availableModule)
    {
        $availableModuleName = $availableModule.Name
        Write-Verbose -Message ($script:localizedData.PreferredModuleFound) -Verbose
    }
    else
    {
        Write-Verbose -Message ($script:localizedData.PreferredModuleNotFound) -Verbose

        <#
            After installing SQL Server the current PowerShell session doesn't know about the new path
            that was added for the SQLPS module.
            This reloads PowerShell session environment variable PSModulePath to make sure it contains
            all paths.
        #>
        $env:PSModulePath = [System.Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')

        <#
            Get the newest SQLPS module if more than one exist.
        #>
        $availableModule = Get-Module -FullyQualifiedName 'SQLPS' -ListAvailable |
            Select-Object -Property Name, Path, @{
                Name = 'Version'
                Expression = {
                    # Parse the build version number '120', '130' from the Path.
                    (Select-String -InputObject $_.Path -Pattern '\\([0-9]{3})\\' -List).Matches.Groups[1].Value
                }
            } |
            Sort-Object -Property 'Version' -Descending |
            Select-Object -First 1

        if ($availableModule)
        {
            # This sets $availableModuleName to the Path of the module to be loaded.
            $availableModuleName = Split-Path -Path $availableModule.Path -Parent
        }
    }

    if ($availableModuleName)
    {
        try
        {
            Write-Debug -Message ($script:localizedData.DebugMessagePushingLocation)
            Push-Location

            <#
                SQLPS has unapproved verbs, disable checking to ignore Warnings.
                Suppressing verbose so all cmdlet is not listed.
            #>
            $importedModule = Import-Module -Name $availableModuleName -DisableNameChecking -Verbose:$false -Force:$Force -PassThru -ErrorAction Stop

            <#
                SQLPS returns two entries, one with module type 'Script' and another with module type 'Manifest'.
                Only return the object with module type 'Manifest'.
                SqlServer only returns one object (of module type 'Script'), so no need to do anything for SqlServer module.
            #>
            if ($availableModuleName -ne 'SqlServer')
            {
                $importedModule = $importedModule | Where-Object -Property 'ModuleType' -EQ -Value 'Manifest'
            }

            Write-Verbose -Message ($script:localizedData.ImportedPowerShellModule -f $importedModule.Name, $importedModule.Version, $importedModule.Path) -Verbose
        }
        catch
        {
            $errorMessage = $script:localizedData.FailedToImportPowerShellSqlModule -f $availableModuleName
            New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
        }
        finally
        {
            Write-Debug -Message ($script:localizedData.DebugMessagePoppingLocation)
            Pop-Location
        }
    }
    else
    {
        $errorMessage = $script:localizedData.PowerShellSqlModuleNotFound
        New-InvalidOperationException -Message $errorMessage
    }
}

<#
    .SYNOPSIS
        Restarts a SQL Server instance and associated services

    .PARAMETER ServerName
        Hostname of the SQL Server to be configured

    .PARAMETER InstanceName
        Name of the SQL instance to be configured. Default is 'MSSQLSERVER'

    .PARAMETER Timeout
        Timeout value for restarting the SQL services. The default value is 120 seconds.

    .PARAMETER SkipClusterCheck
        If cluster check should be skipped. If this is present no connection
        is made to the instance to check if the instance is on a cluster.

        This need to be used for some resource, for example for the SqlServerNetwork
        resource when it's used to enable a disable protocol.

    .PARAMETER SkipWaitForOnline
        If this is present no connection is made to the instance to check if the
        instance is online.

        This need to be used for some resource, for example for the SqlServerNetwork
        resource when it's used to disable protocol.

    .EXAMPLE
        Restart-SqlService -ServerName localhost

    .EXAMPLE
        Restart-SqlService -ServerName localhost -InstanceName 'NamedInstance'

    .EXAMPLE
        Restart-SqlService -ServerName localhost -InstanceName 'NamedInstance' -SkipClusterCheck -SkipWaitForOnline

    .EXAMPLE
        Restart-SqlService -ServerName CLU01 -Timeout 300
#>
function Restart-SqlService
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [Parameter()]
        [System.String]
        $InstanceName = 'MSSQLSERVER',

        [Parameter()]
        [System.UInt32]
        $Timeout = 120,

        [Parameter()]
        [Switch]
        $SkipClusterCheck,

        [Parameter()]
        [Switch]
        $SkipWaitForOnline
    )

    if (-not $SkipClusterCheck.IsPresent)
    {
        ## Connect to the instance
        $serverObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

        if ($serverObject.IsClustered)
        {
            # Get the cluster resources
            Write-Verbose -Message ($script:localizedData.GetSqlServerClusterResources) -Verbose
            $sqlService = Get-CimInstance -Namespace root/MSCluster -ClassName MSCluster_Resource -Filter "Type = 'SQL Server'" |
                Where-Object -FilterScript { $_.PrivateProperties.InstanceName -eq $serverObject.ServiceName }

            Write-Verbose -Message ($script:localizedData.GetSqlAgentClusterResource) -Verbose
            $agentService = $sqlService | Get-CimAssociatedInstance -ResultClassName MSCluster_Resource |
                Where-Object -FilterScript { ($_.Type -eq 'SQL Server Agent') -and ($_.State -eq 2) }

            # Build a listing of resources being acted upon
            $resourceNames = @($sqlService.Name, ($agentService | Select-Object -ExpandProperty Name)) -join ","

            # Stop the SQL Server and dependent resources
            Write-Verbose -Message ($script:localizedData.BringClusterResourcesOffline -f $resourceNames) -Verbose
            $sqlService | Invoke-CimMethod -MethodName TakeOffline -Arguments @{
                Timeout = $Timeout
            }

            # Start the SQL server resource
            Write-Verbose -Message ($script:localizedData.BringSqlServerClusterResourcesOnline) -Verbose
            $sqlService | Invoke-CimMethod -MethodName BringOnline -Arguments @{
                Timeout = $Timeout
            }

            # Start the SQL Agent resource
            if ($agentService)
            {
                Write-Verbose -Message ($script:localizedData.BringSqlServerAgentClusterResourcesOnline) -Verbose
                $agentService | Invoke-CimMethod -MethodName BringOnline -Arguments @{
                    Timeout = $Timeout
                }
            }
        }
        else
        {
            # Not a cluster, restart the Windows service.
            $restartWindowsService = $true
        }
    }
    else
    {
        # Should not check if a cluster, assume that a Windows service should be restarted.
        $restartWindowsService = $true
    }

    if ($restartWindowsService)
    {
        if ($InstanceName -eq 'MSSQLSERVER')
        {
            $serviceName = 'MSSQLSERVER'
        }
        else
        {
            $serviceName = 'MSSQL${0}' -f $InstanceName
        }

        Write-Verbose -Message ($script:localizedData.GetServiceInformation -f 'SQL Server') -Verbose
        $sqlService = Get-Service -Name $serviceName

        <#
            Get all dependent services that are running.
            There are scenarios where an automatic service is stopped and should not be restarted automatically.
        #>
        $agentService = $sqlService.DependentServices | Where-Object -FilterScript { $_.Status -eq 'Running' }

        # Restart the SQL Server service
        Write-Verbose -Message ($script:localizedData.RestartService -f 'SQL Server') -Verbose
        $sqlService | Restart-Service -Force

        # Start dependent services
        $agentService | ForEach-Object {
            Write-Verbose -Message ($script:localizedData.StartingDependentService -f $_.DisplayName) -Verbose
            $_ | Start-Service
        }
    }

    Write-Verbose -Message ($script:localizedData.WaitingInstanceTimeout -f $ServerName, $InstanceName, $Timeout) -Verbose

    if (-not $SkipWaitForOnline.IsPresent)
    {
        $connectTimer = [System.Diagnostics.StopWatch]::StartNew()

        do
        {
            # This call, if it fails, will take between ~9-10 seconds to return.
            $testConnectionServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName -ErrorAction SilentlyContinue

            # Make sure we have an SMO object to test Status
            if ($testConnectionServerObject)
            {
                if ($testConnectionServerObject.Status -eq 'Online')
                {
                    break
                }
            }

            # Waiting 2 seconds to not hammer the SQL Server instance.
            Start-Sleep -Seconds 2
        } until ($connectTimer.Elapsed.Seconds -ge $Timeout)

        $connectTimer.Stop()

        # Was the timeout period reach before able to connect to the SQL Server instance?
        if (-not $testConnectionServerObject -or $testConnectionServerObject.Status -ne 'Online')
        {
            $errorMessage = $script:localizedData.FailedToConnectToInstanceTimeout -f $ServerName, $InstanceName, $Timeout
            New-InvalidOperationException -Message $errorMessage
        }
    }
}

<#
    .SYNOPSIS
        Restarts a Reporting Services instance and associated services

    .PARAMETER InstanceName
        Name of the instance to be restarted. Default is 'MSSQLSERVER'
        (the default instance).

    .PARAMETER WaitTime
        Number of seconds to wait between service stop and service start.
        Defaults to 0 seconds.
#>
function Restart-ReportingServicesService
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.String]
        $InstanceName = 'MSSQLSERVER',

        [Parameter()]
        [System.UInt16]
        $WaitTime = 0
    )

    if ($InstanceName -eq 'SSRS')
    {
        # Check if we're dealing with SSRS 2017
        $ServiceName = 'SQLServerReportingServices'

        Write-Verbose -Message ($script:localizedData.GetServiceInformation -f $ServiceName) -Verbose
        $reportingServicesService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    }

    if ($null -eq $reportingServicesService)
    {
        $ServiceName = 'ReportServer'

        <#
            Pre-2017 SSRS support multiple instances, check if we're dealing
            with a named instance.
        #>
        if (-not ($InstanceName -eq 'MSSQLSERVER'))
        {
            $ServiceName += '${0}' -f $InstanceName
        }

        Write-Verbose -Message ($script:localizedData.GetServiceInformation -f $ServiceName) -Verbose
        $reportingServicesService = Get-Service -Name $ServiceName
    }

    <#
        Get all dependent services that are running.
        There are scenarios where an automatic service is stopped and should
        not be restarted automatically.
    #>
    $dependentService = $reportingServicesService.DependentServices | Where-Object -FilterScript {
        $_.Status -eq 'Running'
    }

    Write-Verbose -Message ($script:localizedData.RestartService -f $reportingServicesService.DisplayName) -Verbose

    Write-Verbose -Message ($script:localizedData.StoppingService -f $reportingServicesService.DisplayName) -Verbose
    $reportingServicesService | Stop-Service -Force

    if ($WaitTime -ne 0)
    {
        Write-Verbose -Message ($script:localizedData.WaitServiceRestart -f $WaitTime, $reportingServicesService.DisplayName) -Verbose
        Start-Sleep -Seconds $WaitTime
    }

    Write-Verbose -Message ($script:localizedData.StartingService -f $reportingServicesService.DisplayName) -Verbose
    $reportingServicesService | Start-Service

    # Start dependent services
    $dependentService | ForEach-Object {
        Write-Verbose -Message ($script:localizedData.StartingDependentService -f $_.DisplayName) -Verbose
        $_ | Start-Service
    }
}


<#
    .SYNOPSIS
        Executes a query on the specified database.

    .PARAMETER ServerName
        The hostname of the server that hosts the SQL instance.

    .PARAMETER InstanceName
        The name of the SQL instance that hosts the database.

    .PARAMETER Database
        Specify the name of the database to execute the query on.

    .PARAMETER Query
        The query string to execute.

    .PARAMETER DatabaseCredential
        PSCredential object with the credentials to use to impersonate a user
        when connecting. If this is not provided then the current user will be
        used to connect to the SQL Server Database Engine instance.

    .PARAMETER LoginType
        Specifies which type of logon credential should be used. The valid types are
        Integrated, WindowsUser, and SqlLogin. If WindowsUser or SqlLogin are specified
        then the SetupCredential needs to be specified as well.

    .PARAMETER SqlServerObject
        You can pass in an object type of 'Microsoft.SqlServer.Management.Smo.Server'.
        This can also be passed in through the pipeline. See examples.

    .PARAMETER WithResults
        Specifies if the query should return results.

    .PARAMETER StatementTimeout
        Set the query StatementTimeout in seconds. Default 600 seconds (10mins).

    .PARAMETER RedactText
        One or more strings to redact from the query when verbose messages are
        written to the console. Strings here will be escaped so they will not
        be interpreted as regular expressions (RegEx).

    .EXAMPLE
        Invoke-Query -ServerName Server1 -InstanceName MSSQLSERVER -Database master `
            -Query 'SELECT name FROM sys.databases' -WithResults

    .EXAMPLE
        Invoke-Query -ServerName Server1 -InstanceName MSSQLSERVER -Database master `
            -Query 'RESTORE DATABASE [NorthWinds] WITH RECOVERY'

    .EXAMPLE
        Connect-SQL @sqlConnectionParameters | Invoke-Query -Database master `
            -Query 'SELECT name FROM sys.databases' -WithResults

    .EXAMPLE
        Invoke-Query -SQLServer Server1 -SQLInstanceName MSSQLSERVER -Database MyDatabase `
            -Query "select * from MyTable where password = 'Pa\ssw0rd1' and password = 'secret passphrase'" `
            -WithResults -RedactText @('Pa\sSw0rd1','Secret PassPhrase') -Verbose

#>
function Invoke-Query
{
    [CmdletBinding(DefaultParameterSetName='SqlServer')]
    param
    (
        [Parameter(ParameterSetName='SqlServer')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName = $env:COMPUTERNAME,

        [Parameter(ParameterSetName='SqlServer')]
        [System.String]
        $InstanceName = 'MSSQLSERVER',

        [Parameter(Mandatory = $true)]
        [System.String]
        $Database,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Query,

        [Parameter()]
        [Alias('SetupCredential')]
        [System.Management.Automation.PSCredential]
        $DatabaseCredential,

        [Parameter()]
        [ValidateSet('Integrated', 'WindowsUser', 'SqlLogin')]
        [System.String]
        $LoginType = 'Integrated',

        [Parameter(ValueFromPipeline, ParameterSetName='SqlObject', Mandatory = $true)]
        [ValidateNotNull()]
        [Microsoft.SqlServer.Management.Smo.Server]
        $SqlServerObject,

        [Parameter()]
        [Switch]
        $WithResults,

        [Parameter()]
        [ValidateNotNull()]
        [System.Int32]
        $StatementTimeout = 600,

        [Parameter()]
        [System.String[]]
        $RedactText
    )

    if ($PSCmdlet.ParameterSetName -eq 'SqlObject')
    {
        $serverObject = $SqlServerObject
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'SqlServer')
    {
        $connectSQLParameters = @{
            ServerName       = $ServerName
            InstanceName     = $InstanceName
            StatementTimeout = $StatementTimeout
        }

        if ($LoginType -ne 'Integrated')
        {
            $connectSQLParameters['LoginType'] = $LoginType
        }

        if ($PSBoundParameters.ContainsKey('DatabaseCredential'))
        {
            $connectSQLParameters.SetupCredential = $DatabaseCredential
        }

        $serverObject = Connect-SQL @connectSQLParameters
    }

    $redactedQuery = $Query

    foreach ($redactString in $RedactText)
    {
        <#
            Escaping the string to handle strings which could look like
            regular expressions, like passwords.
        #>
        $escapedRedactedString = [System.Text.RegularExpressions.Regex]::Escape($redactString)

        $redactedQuery = $redactedQuery -ireplace $escapedRedactedString,'*******'
    }

    if ($WithResults)
    {
        try
        {
            Write-Verbose -Message (
                $script:localizedData.ExecuteQueryWithResults -f $redactedQuery
            ) -Verbose

            $result = $serverObject.Databases[$Database].ExecuteWithResults($Query)
        }
        catch
        {
            $errorMessage = $script:localizedData.ExecuteQueryWithResultsFailed -f $Database
            New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
        }
    }
    else
    {
        try
        {
            Write-Verbose -Message (
                $script:localizedData.ExecuteNonQuery -f $redactedQuery
            ) -Verbose

            $serverObject.Databases[$Database].ExecuteNonQuery($Query)
        }
        catch
        {
            $errorMessage = $script:localizedData.ExecuteNonQueryFailed -f $Database
            New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
        }
    }

    return $result
}

<#
    .SYNOPSIS
        Executes the alter method on an Availability Group Replica object.

    .PARAMETER AvailabilityGroupReplica
        The Availability Group Replica object that must be altered.
#>
function Update-AvailabilityGroupReplica
{
    param
    (
        [Parameter(Mandatory = $true)]
        [Microsoft.SqlServer.Management.Smo.AvailabilityReplica]
        $AvailabilityGroupReplica
    )

    try
    {
        $originalErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'
        $AvailabilityGroupReplica.Alter()
    }
    catch
    {
        $errorMessage = $script:localizedData.AlterAvailabilityGroupReplicaFailed -f $AvailabilityGroupReplica.Name
        New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
    }
    finally
    {
        $ErrorActionPreference = $originalErrorActionPreference
    }
}

<#
    .SYNOPSIS
        Impersonates a login and determines whether required permissions are present.

    .PARAMETER ServerName
        String containing the host name of the SQL Server to connect to.

    .PARAMETER InstanceName
        String containing the SQL Server Database Engine instance to connect to.

    .PARAMETER LoginName
        String containing the login (user) which should be checked for a permission.

    .PARAMETER Permissions
        This is a list that represents a SQL Server set of database permissions.

    .PARAMETER SecurableClass
        String containing the class of permissions to test. It can be:
            SERVER: A permission that is applicable against server objects.
            LOGIN: A permission that is applicable against login objects.

        Default is 'SERVER'.

    .PARAMETER SecurableName
        String containing the name of the object against which permissions exist, e.g. if SecurableClass is LOGIN this is the name of a login permissions may exist against.

        Default is $null.

    .NOTES
        These SecurableClass are not yet in this module yet and so are not implemented:
            'APPLICATION ROLE', 'ASSEMBLY', 'ASYMMETRIC KEY', 'CERTIFICATE',
            'CONTRACT', 'DATABASE', 'ENDPOINT', 'FULLTEXT CATALOG',
            'MESSAGE TYPE', 'OBJECT', 'REMOTE SERVICE BINDING', 'ROLE',
            'ROUTE', 'SCHEMA', 'SERVICE', 'SYMMETRIC KEY', 'TYPE', 'USER',
            'XML SCHEMA COLLECTION'

#>
function Test-LoginEffectivePermissions
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $LoginName,

        [Parameter(Mandatory = $true)]
        [System.String[]]
        $Permissions,

        [Parameter()]
        [ValidateSet('SERVER', 'LOGIN')]
        [System.String]
        $SecurableClass = 'SERVER',

        [Parameter()]
        [System.String]
        $SecurableName
    )

    # Assume the permissions are not present
    $permissionsPresent = $false

    $invokeQueryParameters = @{
        ServerName   = $ServerName
        InstanceName = $InstanceName
        Database     = 'master'
        WithResults  = $true
    }

    if ( [System.String]::IsNullOrEmpty($SecurableName) )
    {
        $queryToGetEffectivePermissionsForLogin = "
            EXECUTE AS LOGIN = '$LoginName'
            SELECT DISTINCT permission_name
            FROM fn_my_permissions(null,'$SecurableClass')
            REVERT
        "
    }
    else
    {
        $queryToGetEffectivePermissionsForLogin = "
            EXECUTE AS LOGIN = '$LoginName'
            SELECT DISTINCT permission_name
            FROM fn_my_permissions('$SecurableName','$SecurableClass')
            REVERT
        "
    }

    Write-Verbose -Message ($script:localizedData.GetEffectivePermissionForLogin -f $LoginName, $InstanceName) -Verbose

    $loginEffectivePermissionsResult = Invoke-Query @invokeQueryParameters -Query $queryToGetEffectivePermissionsForLogin
    $loginEffectivePermissions = $loginEffectivePermissionsResult.Tables.Rows.permission_name

    if ( $null -ne $loginEffectivePermissions )
    {
        $loginMissingPermissions = Compare-Object -ReferenceObject $Permissions -DifferenceObject $loginEffectivePermissions |
            Where-Object -FilterScript { $_.SideIndicator -ne '=>' } |
            Select-Object -ExpandProperty InputObject

        if ( $loginMissingPermissions.Count -eq 0 )
        {
            $permissionsPresent = $true
        }
    }

    return $permissionsPresent
}

<#
    .SYNOPSIS
        Determine if the seeding mode of the specified availability group is automatic.

    .PARAMETER ServerName
        The hostname of the server that hosts the SQL instance.

    .PARAMETER InstanceName
        The name of the SQL instance that hosts the availability group.

    .PARAMETER AvailabilityGroupName
        The name of the availability group to check.

    .PARAMETER AvailabilityReplicaName
        The name of the availability replica to check.
#>
function Test-AvailabilityReplicaSeedingModeAutomatic
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $AvailabilityGroupName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $AvailabilityReplicaName
    )

    # Assume automatic seeding is disabled by default
    $availabilityReplicaSeedingModeAutomatic = $false

    $serverObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName

    # Only check the seeding mode if this is SQL 2016 or newer
    if ( $serverObject.Version -ge 13 )
    {
        $invokeQueryParams = @{
            ServerName   = $ServerName
            InstanceName = $InstanceName
            Database     = 'master'
            WithResults  = $true
        }

        $queryToGetSeedingMode = "
            SELECT seeding_mode_desc
            FROM sys.availability_replicas ar
            INNER JOIN sys.availability_groups ag ON ar.group_id = ag.group_id
            WHERE ag.name = '$AvailabilityGroupName'
                AND ar.replica_server_name = '$AvailabilityReplicaName'
        "
        $seedingModeResults = Invoke-Query @invokeQueryParams -Query $queryToGetSeedingMode
        $seedingMode = $seedingModeResults.Tables.Rows.seeding_mode_desc

        if ( $seedingMode -eq 'Automatic' )
        {
            $availabilityReplicaSeedingModeAutomatic = $true
        }
    }

    return $availabilityReplicaSeedingModeAutomatic
}

<#
    .SYNOPSIS
        Get the server object of the primary replica of the specified availability group.

    .PARAMETER ServerObject
        The current server object connection.

    .PARAMETER AvailabilityGroup
        The availability group object used to find the primary replica server name.
#>
function Get-PrimaryReplicaServerObject
{
    param
    (
        [Parameter(Mandatory = $true)]
        [Microsoft.SqlServer.Management.Smo.Server]
        $ServerObject,

        [Parameter(Mandatory = $true)]
        [Microsoft.SqlServer.Management.Smo.AvailabilityGroup]
        $AvailabilityGroup
    )

    $primaryReplicaServerObject = $serverObject

    # Determine if we're connected to the primary replica
    if ( ( $AvailabilityGroup.PrimaryReplicaServerName -ne $serverObject.DomainInstanceName ) -and ( -not [System.String]::IsNullOrEmpty($AvailabilityGroup.PrimaryReplicaServerName) ) )
    {
        $primaryReplicaServerObject = Connect-SQL -ServerName $AvailabilityGroup.PrimaryReplicaServerName
    }

    return $primaryReplicaServerObject
}

<#
    .SYNOPSIS
        Determine if the current login has impersonate permissions

    .PARAMETER ServerObject
        The server object on which to perform the test.

    .PARAMETER SecurableName
        If set then impersonate permission on this specific securable (e.g. login) is also checked.

#>
function Test-ImpersonatePermissions
{
    param
    (
        [Parameter(Mandatory = $true)]
        [Microsoft.SqlServer.Management.Smo.Server]
        $ServerObject,

        [Parameter()]
        [System.String]
        $SecurableName
    )

    # The impersonate any login permission only exists in SQL 2014 and above
    $testLoginEffectivePermissionsParams = @{
        ServerName   = $ServerObject.ComputerNamePhysicalNetBIOS
        InstanceName = $ServerObject.ServiceName
        LoginName    = $ServerObject.ConnectionContext.TrueLogin
        Permissions  = @('IMPERSONATE ANY LOGIN')
    }

    $impersonatePermissionsPresent = Test-LoginEffectivePermissions @testLoginEffectivePermissionsParams

    if ($impersonatePermissionsPresent)
    {
        Write-Verbose -Message ( 'The login "{0}" has impersonate any login permissions on the instance "{1}\{2}".' -f $testLoginEffectivePermissionsParams.LoginName, $testLoginEffectivePermissionsParams.ServerName, $testLoginEffectivePermissionsParams.SInstanceName ) -Verbose
        return $impersonatePermissionsPresent
    }
    else
    {
        Write-Verbose -Message ( 'The login "{0}" does not have impersonate any login permissions on the instance "{1}\{2}".' -f $testLoginEffectivePermissionsParams.LoginName, $testLoginEffectivePermissionsParams.ServerName, $testLoginEffectivePermissionsParams.InstanceName ) -Verbose
    }

    # Check for sysadmin / control server permission which allows impersonation
    $testLoginEffectivePermissionsParams = @{
        ServerName   = $ServerObject.ComputerNamePhysicalNetBIOS
        InstanceName = $ServerObject.ServiceName
        LoginName    = $ServerObject.ConnectionContext.TrueLogin
        Permissions  = @('CONTROL SERVER')
    }

    $impersonatePermissionsPresent = Test-LoginEffectivePermissions @testLoginEffectivePermissionsParams

    if ($impersonatePermissionsPresent)
    {
        Write-Verbose -Message ( 'The login "{0}" has control server permissions on the instance "{1}\{2}".' -f $testLoginEffectivePermissionsParams.LoginName, $testLoginEffectivePermissionsParams.ServerName, $testLoginEffectivePermissionsParams.InstanceName ) -Verbose
        return $impersonatePermissionsPresent
    }
    else
    {
        Write-Verbose -Message ( 'The login "{0}" does not have control server permissions on the instance "{1}\{2}".' -f $testLoginEffectivePermissionsParams.LoginName, $testLoginEffectivePermissionsParams.ServerName, $testLoginEffectivePermissionsParams.InstanceName ) -Verbose
    }

    if (-not [System.String]::IsNullOrEmpty($SecurableName))
    {
        # Check for login-specific impersonation permissions
        $testLoginEffectivePermissionsParams = @{
            ServerName     = $ServerObject.ComputerNamePhysicalNetBIOS
            InstanceName   = $ServerObject.ServiceName
            LoginName      = $ServerObject.ConnectionContext.TrueLogin
            Permissions    = @('IMPERSONATE')
            SecurableClass = 'LOGIN'
            SecurableName  = $SecurableName
        }

        $impersonatePermissionsPresent = Test-LoginEffectivePermissions @testLoginEffectivePermissionsParams

        if ($impersonatePermissionsPresent)
        {
            Write-Verbose -Message ( 'The login "{0}" has impersonate permissions on the instance "{1}\{2}" for the login "{3}".' -f $testLoginEffectivePermissionsParams.LoginName, $testLoginEffectivePermissionsParams.ServerName, $testLoginEffectivePermissionsParams.InstanceName, $SecurableName ) -Verbose
            return $impersonatePermissionsPresent
        }
        else
        {
            Write-Verbose -Message ( 'The login "{0}" does not have impersonate permissions on the instance "{1}\{2}" for the login "{3}".' -f $testLoginEffectivePermissionsParams.LoginName, $testLoginEffectivePermissionsParams.ServerName, $testLoginEffectivePermissionsParams.InstanceName, $SecurableName ) -Verbose
        }

        # Check for login-specific control permissions
        $testLoginEffectivePermissionsParams = @{
            ServerName     = $ServerObject.ComputerNamePhysicalNetBIOS
            InstanceName   = $ServerObject.ServiceName
            LoginName      = $ServerObject.ConnectionContext.TrueLogin
            Permissions    = @('CONTROL')
            SecurableClass = 'LOGIN'
            SecurableName  = $SecurableName
        }

        $impersonatePermissionsPresent = Test-LoginEffectivePermissions @testLoginEffectivePermissionsParams

        if ($impersonatePermissionsPresent)
        {
            Write-Verbose -Message ( 'The login "{0}" has control permissions on the instance "{1}\{2}" for the login "{3}".' -f $testLoginEffectivePermissionsParams.LoginName, $testLoginEffectivePermissionsParams.ServerName, $testLoginEffectivePermissionsParams.InstanceName, $SecurableName ) -Verbose
            return $impersonatePermissionsPresent
        }
        else
        {
            Write-Verbose -Message ( 'The login "{0}" does not have control permissions on the instance "{1}\{2}" for the login "{3}".' -f $testLoginEffectivePermissionsParams.LoginName, $testLoginEffectivePermissionsParams.ServerName, $testLoginEffectivePermissionsParams.InstanceName, $SecurableName ) -Verbose
        }
    }

    Write-Verbose -Message ( 'The login "{0}" does not have any impersonate permissions required on the instance "{1}\{2}".' -f $testLoginEffectivePermissionsParams.LoginName, $testLoginEffectivePermissionsParams.ServerName, $testLoginEffectivePermissionsParams.InstanceName ) -Verbose

    return $impersonatePermissionsPresent
}

<#
    .SYNOPSIS
        Takes a SQL Instance name in the format of 'Server\Instance' and splits it into a hash table prepared to be passed into Connect-SQL.

    .PARAMETER FullSqlInstanceName
        The full SQL instance name string to be split.

    .OUTPUTS
        Hash table with the properties ServerName and InstanceName.
#>
function Split-FullSqlInstanceName
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $FullSqlInstanceName
    )

    $sqlServer, $sqlInstanceName = $FullSqlInstanceName.Split('\')

    if ( [System.String]::IsNullOrEmpty($sqlInstanceName) )
    {
        $sqlInstanceName = 'MSSQLSERVER'
    }

    return @{
        ServerName   = $sqlServer
        InstanceName = $sqlInstanceName
    }
}

<#
    .SYNOPSIS
        Determine if the cluster has the required permissions to the supplied server.

    .PARAMETER ServerObject
        The server object on which to perform the test.
#>
function Test-ClusterPermissions
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [Microsoft.SqlServer.Management.Smo.Server]
        $ServerObject
    )

    $clusterServiceName = 'NT SERVICE\ClusSvc'
    $ntAuthoritySystemName = 'NT AUTHORITY\SYSTEM'
    $availabilityGroupManagementPerms = @('Connect SQL', 'Alter Any Availability Group', 'View Server State')
    $clusterPermissionsPresent = $false

    # Retrieve the SQL Server and Instance name from the server object
    $sqlServer = $ServerObject.NetName
    $sqlInstanceName = $ServerObject.ServiceName

    foreach ( $loginName in @( $clusterServiceName, $ntAuthoritySystemName ) )
    {
        if ( $ServerObject.Logins[$loginName] -and -not $clusterPermissionsPresent )
        {
            $testLoginEffectivePermissionsParams = @{
                ServerName   = $sqlServer
                InstanceName = $sqlInstanceName
                LoginName    = $loginName
                Permissions  = $availabilityGroupManagementPerms
            }

            $clusterPermissionsPresent = Test-LoginEffectivePermissions @testLoginEffectivePermissionsParams

            if ( -not $clusterPermissionsPresent )
            {
                switch ( $loginName )
                {
                    $clusterServiceName
                    {
                        Write-Verbose -Message ( $script:localizedData.ClusterLoginMissingRecommendedPermissions -f $loginName, ( $availabilityGroupManagementPerms -join ', ' ) ) -Verbose
                    }

                    $ntAuthoritySystemName
                    {
                        Write-Verbose -Message ( $script:localizedData.ClusterLoginMissingPermissions -f $loginName, ( $availabilityGroupManagementPerms -join ', ' ) ) -Verbose
                    }
                }
            }
            else
            {
                Write-Verbose -Message ( $script:localizedData.ClusterLoginPermissionsPresent -f $loginName ) -Verbose
            }
        }
        elseif ( -not $clusterPermissionsPresent )
        {
            switch ( $loginName )
            {
                $clusterServiceName
                {
                    Write-Verbose -Message ($script:localizedData.ClusterLoginMissingRecommendedPermissions -f $loginName, "Trying with '$ntAuthoritySystemName'.") -Verbose
                }

                $ntAuthoritySystemName
                {
                    Write-Verbose -Message ( $script:localizedData.ClusterLoginMissing -f $loginName, '' ) -Verbose
                }
            }
        }
    }

    # If neither 'NT SERVICE\ClusSvc' or 'NT AUTHORITY\SYSTEM' have the required permissions, throw an error.
    if ( -not $clusterPermissionsPresent )
    {
        throw ($script:localizedData.ClusterPermissionsMissing -f $sqlServer, $sqlInstanceName )
    }

    return $clusterPermissionsPresent
}

<#
    .SYNOPSIS
        Determine if the current node is hosting the instance.

    .PARAMETER ServerObject
        The server object on which to perform the test.
#>
function Test-ActiveNode
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [Microsoft.SqlServer.Management.Smo.Server]
        $ServerObject
    )

    $result = $false

    # Determine if this is a failover cluster instance (FCI)
    if ( $ServerObject.IsMemberOfWsfcCluster )
    {
        <#
            If the current node name is the same as the name the instances is
            running on, then this is the active node
        #>
        $result = $ServerObject.ComputerNamePhysicalNetBIOS -eq $env:COMPUTERNAME
    }
    else
    {
        <#
            This is a standalone instance, therefore the node will always host
            the instance.
        #>
        $result = $true
    }

    return $result
}

<#
    .SYNOPSIS
        Execute an SQL script located in a file on disk.

    .PARAMETER ServerInstance
        The name of an instance of the Database Engine.
        For default instances, only specify the computer name. For named instances, use the format ComputerName\InstanceName.

    .PARAMETER InputFile
        Path to SQL script file that will be executed.

    .PARAMETER Query
        The full query that will be executed.

    .PARAMETER Credential
        The credentials to use to authenticate using SQL Authentication. To authenticate using Windows Authentication, assign the credentials
        to the built-in parameter 'PsDscRunAsCredential'. If both parameters 'Credential' and 'PsDscRunAsCredential' are not assigned, then
        the SYSTEM account will be used to authenticate using Windows Authentication.

    .PARAMETER QueryTimeout
        Specifies, as an integer, the number of seconds after which the T-SQL script execution will time out.
        In some SQL Server versions there is a bug in Invoke-Sqlcmd where the normal default value 0 (no timeout) is not respected and the default value is incorrectly set to 30 seconds.

    .PARAMETER Variable
        Creates a Invoke-Sqlcmd scripting variable for use in the Invoke-Sqlcmd script, and sets a value for the variable.
#>
function Invoke-SqlScript
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerInstance,

        [Parameter(ParameterSetName = 'File', Mandatory = $true)]
        [System.String]
        $InputFile,

        [Parameter(ParameterSetName = 'Query', Mandatory = $true)]
        [System.String]
        $Query,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        [Parameter()]
        [System.UInt32]
        $QueryTimeout,

        [Parameter()]
        [System.String[]]
        $Variable
    )

    Import-SQLPSModule

    if ($PSCmdlet.ParameterSetName -eq 'File')
    {
        $null = $PSBoundParameters.Remove('Query')
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'Query')
    {
        $null = $PSBoundParameters.Remove('InputFile')
    }

    if ($null -ne $Credential)
    {
        $null = $PSBoundParameters.Add('Username', $Credential.UserName)

        $null = $PSBoundParameters.Add('Password', $Credential.GetNetworkCredential().Password)
    }

    $null = $PSBoundParameters.Remove('Credential')

    Invoke-SqlCmd @PSBoundParameters
}

<#
    .SYNOPSIS
        Builds service account parameters for service account.

    .PARAMETER ServiceAccount
        Credential for the service account.
#>
function Get-ServiceAccount
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $ServiceAccount
     )

    $accountParameters = @{}

    switch -Regex ($ServiceAccount.UserName.ToUpper())
    {
        '^(?:NT ?AUTHORITY\\)?(SYSTEM|LOCALSERVICE|LOCAL SERVICE|NETWORKSERVICE|NETWORK SERVICE)$'
        {
            $accountParameters = @{
                "UserName" = "NT AUTHORITY\$($Matches[1])"
            }
        }

        '^(?:NT SERVICE\\)(.*)$'
        {
            $accountParameters = @{
                "UserName" = "NT SERVICE\$($Matches[1])"
            }
        }

        # Testing if account is a Managed Service Account, which ends with '$'.
        '\$$'
        {
            $accountParameters = @{
                "UserName" = $ServiceAccount.UserName
            }
        }

        # Normal local or domain service account.
        default
        {
            $accountParameters = @{
                "UserName" = $ServiceAccount.UserName
                "Password" = $ServiceAccount.GetNetworkCredential().Password
            }
        }
    }

    return $accountParameters
}

<#
    .SYNOPSIS
    Recursevly searches Exception stack for specific error number.

    .PARAMETER ExceptionToSearch
    The Exception object to test

    .PARAMETER ErrorNumber
    The specific error number to look for

    .NOTES
    This function allows us to more easily write mocks.
#>
function Find-ExceptionByNumber
{
    # Define parameters
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Exception]
        $ExceptionToSearch,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ErrorNumber
    )

    # Define working variables
    $errorFound = $false

    # Check to see if the exception has an inner exception
    if ($ExceptionToSearch.InnerException)
    {
        # Assign found to the returned recursive call
        $errorFound = Find-ExceptionByNumber -ExceptionToSearch $ExceptionToSearch.InnerException -ErrorNumber $ErrorNumber
    }

    # Check to see if it was found
    if (!$errorFound)
    {
        # Check this exceptions message
        $errorFound = $ExceptionToSearch.Number -eq $ErrorNumber
    }

    # Return
    return $errorFound
}

$script:localizedData = Get-LocalizedData -ResourceName 'SqlServerDsc.Common' -ScriptRoot $PSScriptRoot
