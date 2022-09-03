#Region './prefix.ps1' 0
$script:modulesFolderPath = Split-Path -Path $PSScriptRoot -Parent
#EndRegion './prefix.ps1' 1
#Region './Public/Assert-Module.ps1' 0
<#
    .SYNOPSIS
        Assert if the specific module is available to be imported.

    .PARAMETER ModuleName
        Specifies the name of the module to assert.

    .EXAMPLE
        Assert-Module -ModuleName 'DhcpServer'

        This asserts that the module DhcpServer is available on the system.
#>
function Assert-Module
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ModuleName
    )

    if (-not (Get-Module -Name $ModuleName -ListAvailable))
    {
        $errorMessage = $script:localizedData.ModuleNotFound -f $ModuleName
        New-ObjectNotFoundException -Message $errorMessage
    }
}
#EndRegion './Public/Assert-Module.ps1' 28
#Region './Public/Get-LocalizedData.ps1' 0
<#
    .SYNOPSIS
        Gets language-specific data into scripts and functions based on the UI culture
        that is selected for the operating system.
        Similar to Import-LocalizedData, with extra parameter 'DefaultUICulture'.

    .DESCRIPTION
        The Get-LocalizedData cmdlet dynamically retrieves strings from a subdirectory
        whose name matches the UI language set for the current user of the operating system.
        It is designed to enable scripts to display user messages in the UI language selected
        by the current user.

        Get-LocalizedData imports data from .psd1 files in language-specific subdirectories
        of the script directory and saves them in a local variable that is specified in the
        command. The cmdlet selects the subdirectory and file based on the value of the
        $PSUICulture automatic variable. When you use the local variable in the script to
        display a user message, the message appears in the user's UI language.

        You can use the parameters of G-LocalizedData to specify an alternate UI culture,
        path, and file name, to add supported commands, and to suppress the error message that
        appears if the .psd1 files are not found.

        The G-LocalizedData cmdlet supports the script internationalization
        initiative that was introduced in Windows PowerShell 2.0. This initiative
        aims to better serve users worldwide by making it easy for scripts to display
        user messages in the UI language of the current user. For more information
        about this and about the format of the .psd1 files, see about_Script_Internationalization.

    .PARAMETER BindingVariable
        Specifies the variable into which the text strings are imported. Enter a variable
        name without a dollar sign ($).

        In Windows PowerShell 2.0, this parameter is required. In Windows PowerShell 3.0,
        this parameter is optional. If you omit this parameter, Import-LocalizedData
        returns a hash table of the text strings. The hash table is passed down the pipeline
        or displayed at the command line.

        When using Import-LocalizedData to replace default text strings specified in the
        DATA section of a script, assign the DATA section to a variable and enter the name
        of the DATA section variable in the value of the BindingVariable parameter. Then,
        when Import-LocalizedData saves the imported content in the BindingVariable, the
        imported data will replace the default text strings. If you are not specifying
        default text strings, you can select any variable name.

    .PARAMETER UICulture
        Specifies an alternate UI culture. The default is the value of the $PsUICulture
        automatic variable. Enter a UI culture in <language>-<region> format, such as
        en-US, de-DE, or ar-SA.

        The value of the UICulture parameter determines the language-specific subdirectory
        (within the base directory) from which Import-LocalizedData gets the .psd1 file
        for the script.

        The cmdlet searches for a subdirectory with the same name as the value of the
        UICulture parameter or the $PsUICulture automatic variable, such as de-DE or
        ar-SA. If it cannot find the directory, or the directory does not contain a .psd1
        file for the script, it searches for a subdirectory with the name of the language
        code, such as de or ar. If it cannot find the subdirectory or .psd1 file, the
        command fails and the data is displayed in the default language specified in the
        script.

    .PARAMETER BaseDirectory
        Specifies the base directory where the .psd1 files are located. The default is
        the directory where the script is located. Import-LocalizedData searches for
        the .psd1 file for the script in a language-specific subdirectory of the base
        directory.

    .PARAMETER FileName
        Specifies the name of the data file (.psd1) to be imported. Enter a file name.
        You can specify a file name that does not include its .psd1 file name extension,
        or you can specify the file name including the .psd1 file name extension.

        The FileName parameter is required when Import-LocalizedData is not used in a
        script. Otherwise, the parameter is optional and the default value is the base
        name of the script. You can use this parameter to direct Import-LocalizedData
        to search for a different .psd1 file.

        For example, if the FileName is omitted and the script name is FindFiles.ps1,
        Import-LocalizedData searches for the FindFiles.psd1 data file.

    .PARAMETER SupportedCommand
        Specifies cmdlets and functions that generate only data.

        Use this parameter to include cmdlets and functions that you have written or
        tested. For more information, see about_Script_Internationalization.

    .PARAMETER DefaultUICulture
        Specifies which UICulture to default to if current UI culture or its parents
        culture don't have matching data file.

        For example, if you have a data file in 'en-US' but not in 'en' or 'en-GB' and
        your current culture is 'en-GB', you can default back to 'en-US'.

    .NOTES
        Before using Import-LocalizedData, localize your user messages. Format the messages
        for each locale (UI culture) in a hash table of key/value pairs, and save the
        hash table in a file with the same name as the script and a .psd1 file name extension.
        Create a directory under the script directory for each supported UI culture, and
        then save the .psd1 file for each UI culture in the directory with the UI
        culture name.

        For example, localize your user messages for the de-DE locale and format them in
        a hash table. Save the hash table in a <ScriptName>.psd1 file. Then create a de-DE
        subdirectory under the script directory, and save the de-DE <ScriptName>.psd1
        file in the de-DE subdirectory. Repeat this method for each locale that you support.

        Import-LocalizedData performs a structured search for the localized user
        messages for a script.

        Import-LocalizedData begins the search in the directory where the script file
        is located (or the value of the BaseDirectory parameter). It then searches within
        the base directory for a subdirectory with the same name as the value of the
        $PsUICulture variable (or the value of the UICulture parameter), such as de-DE or
        ar-SA. Then, it searches in that subdirectory for a .psd1 file with the same name
        as the script (or the value of the FileName parameter).

        If Import-LocalizedData cannot find a subdirectory with the name of the UI culture,
        or the subdirectory does not contain a .psd1 file for the script, it searches for
        a .psd1 file for the script in a subdirectory with the name of the language code,
        such as de or ar. If it cannot find the subdirectory or .psd1 file, the command
        fails, the data is displayed in the default language in the script, and an error
        message is displayed explaining that the data could not be imported. To suppress
        the message and fail gracefully, use the ErrorAction common parameter with a value
        of SilentlyContinue.

        If Import-LocalizedData finds the subdirectory and the .psd1 file, it imports the
        hash table of user messages into the value of the BindingVariable parameter in the
        command. Then, when you display a message from the hash table in the variable, the
        localized message is displayed.

        For more information, see about_Script_Internationalization.
#>
function Get-LocalizedData
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0)]
        [Alias('Variable')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $BindingVariable,

        [Parameter(Position = 1, ParameterSetName = 'TargetedUICulture')]
        [System.String]
        $UICulture,

        [Parameter()]
        [System.String]
        $BaseDirectory,

        [Parameter()]
        [System.String]
        $FileName,

        [Parameter()]
        [System.String[]]
        $SupportedCommand,

        [Parameter(Position = 1, ParameterSetName = 'DefaultUICulture')]
        [System.String]
        $DefaultUICulture
    )

    begin
    {
        <#
            Because Proxy Command changes the Invocation origin, we need to be explicit
            when handing the pipeline back to original command.
        #>
        if (!$PSBoundParameters.ContainsKey('FileName'))
        {
            if ($myInvocation.ScriptName)
            {
                $file = [System.IO.FileInfo] $myInvocation.ScriptName
            }
            else
            {
                $file = [System.IO.FileInfo] $myInvocation.MyCommand.Module.Path
            }

            $FileName = $file.BaseName

            $PSBoundParameters.Add('FileName', $file.Name)
        }

        if ($PSBoundParameters.ContainsKey('BaseDirectory'))
        {
            $callingScriptRoot = $BaseDirectory
        }
        else
        {
            $callingScriptRoot = $MyInvocation.PSScriptRoot

            $PSBoundParameters.Add('BaseDirectory', $callingScriptRoot)
        }

        if ($PSBoundParameters.ContainsKey('DefaultUICulture') -and !$PSBoundParameters.ContainsKey('UICulture'))
        {
            <#
                We don't want the resolution to eventually return the ModuleManifest
                so we run the same GetFilePath() logic than here:
                https://github.com/PowerShell/PowerShell/blob/master/src/Microsoft.PowerShell.Commands.Utility/commands/utility/Import-LocalizedData.cs#L302-L333
                and if we see it will return the wrong thing, set the UICulture to DefaultUI culture, and return the logic to Import-LocalizedData
            #>
            $currentCulture = Get-UICulture

            $languageFile = $null

            $localizedFileNames = @(
                $FileName + '.psd1'
                $FileName + '.strings.psd1'
            )

            while ($null -ne $currentCulture -and $currentCulture.Name -and !$languageFile)
            {
                foreach ($fullFileName in $localizedFileNames)
                {
                    $filePath = [io.Path]::Combine($callingScriptRoot, $CurrentCulture.Name, $fullFileName)

                    if (Test-Path -Path $filePath)
                    {
                        Write-Debug -Message "Found $filePath"

                        $languageFile = $filePath

                        # Set the filename to the file we found.
                        $PSBoundParameters['FileName'] = $fullFileName

                        # Exit loop if we find the first filename.
                        break
                    }
                    else
                    {
                        Write-Debug -Message "File $filePath not found"
                    }
                }

                $currentCulture = $currentCulture.Parent
            }

            if (!$languageFile)
            {
                $PSBoundParameters.Add('UICulture', $DefaultUICulture)
            }

            $null = $PSBoundParameters.Remove('DefaultUICulture')
        }

        try
        {
            $outBuffer = $null

            if ($PSBoundParameters.TryGetValue('OutBuffer', [ref] $outBuffer))
            {
                $PSBoundParameters['OutBuffer'] = 1
            }

            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Utility\Import-LocalizedData', [System.Management.Automation.CommandTypes]::Cmdlet)
            $scriptCmd = { & $wrappedCmd @PSBoundParameters }

            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)
        }
        catch
        {
            throw
        }
    }

    process
    {
        try
        {
            $steppablePipeline.Process($_)
        }
        catch
        {
            throw
        }
    }

    end
    {
        if ($BindingVariable -and ($valueToBind = Get-Variable -Name $BindingVariable -ValueOnly -ErrorAction 'Ignore'))
        {
            # Bringing the variable to the parent scope
            Set-Variable -Scope 1 -Name $BindingVariable -Force -ErrorAction 'SilentlyContinue' -Value $valueToBind
        }

        try
        {
            $steppablePipeline.End()
        }
        catch
        {
            throw
        }
    }
}
#EndRegion './Public/Get-LocalizedData.ps1' 300
#Region './Public/New-InvalidArgumentException.ps1' 0
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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
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
#EndRegion './Public/New-InvalidArgumentException.ps1' 39
#Region './Public/New-InvalidOperationException.ps1' 0
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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
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
#EndRegion './Public/New-InvalidOperationException.ps1' 52
#Region './Public/New-InvalidResultException.ps1' 0
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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
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
#EndRegion './Public/New-InvalidResultException.ps1' 52
#Region './Public/New-NotImplementedException.ps1' 0
<#
    .SYNOPSIS
        Creates and throws an not implemented exception.

    .PARAMETER Message
        The message explaining why this error is being thrown.

    .PARAMETER ErrorRecord
        The error record containing the exception that is causing this terminating error.
#>
function New-NotImplementedException
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
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
#EndRegion './Public/New-NotImplementedException.ps1' 52
#Region './Public/New-ObjectNotFoundException.ps1' 0

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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
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
#EndRegion './Public/New-ObjectNotFoundException.ps1' 53
#Region './Public/Test-DscParameterState.ps1' 0

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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'returnValue')]
    [CmdletBinding()]
    [OutputType([Boolean])]
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
#EndRegion './Public/Test-DscParameterState.ps1' 180
#Region './Public/Test-IsNanoServer.ps1' 0
<#
    .SYNOPSIS
        Tests if the current OS is a Nano server.
#>
function Test-IsNanoServer
{
    [OutputType([System.Boolean])]
    [CmdletBinding()]
    param ()

    $productDatacenterNanoServer = 143
    $productStandardNanoServer = 144

    $operatingSystemSKU = (Get-CimInstance -ClassName Win32_OperatingSystem).OperatingSystemSKU

    Write-Verbose -Message ($script:localizedData.TestIsNanoServerOperatingSystemSku -f $operatingSystemSKU)

    return ($operatingSystemSKU -in ($productDatacenterNanoServer, $productStandardNanoServer))
}
#EndRegion './Public/Test-IsNanoServer.ps1' 19
#Region './suffix.ps1' 0

$script:localizedData = Get-LocalizedData -DefaultUICulture 'en-US'
#EndRegion './suffix.ps1' 2
