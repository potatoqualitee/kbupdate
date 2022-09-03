[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
param ()

$errorActionPreference = 'Stop'
Set-StrictMode -Version 'Latest'

$modulePath = Join-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -ChildPath 'Modules'

# Import the shared modules
Import-Module -Name (Join-Path -Path $modulePath `
    -ChildPath (Join-Path -Path 'xPSDesiredStateConfiguration.Common' `
        -ChildPath 'xPSDesiredStateConfiguration.Common.psm1'))

Import-Module -Name (Join-Path -Path $modulePath -ChildPath 'DscResource.Common')

# Import Localization Strings
$script:localizedData = Get-LocalizedData -DefaultUICulture 'en-US'

$script:packageCacheLocation = "$env:programData\Microsoft\Windows\PowerShell\Configuration\BuiltinProvCache\DSC_xPackageResource"
$script:msiTools = $null

<#
    .SYNOPSIS
        Retrieves the current installation state of the package.

    .PARAMETER Name
        The name of the package to be added or removed.

    .PARAMETER ProductId
        The identifying number used to uniquely identify this package.

    .PARAMETER Path
        The path, URL or UNC path to the package.

    .PARAMETER CreateCheckRegValue
        Specifies if a registry value should be created when the packages is installed.

    .PARAMETER InstalledCheckRegHive
        The hive in which to create the registry key. Defaults to 'LocalMachine'.

    .PARAMETER InstalledCheckRegKey
        The registry key to validate the package is installed.

    .PARAMETER InstalledCheckRegValueName
        The registry value name to validate the package is installed.

    .PARAMETER InstalledCheckRegValueData
        The registry value to validate the package is installed.
#>

function Get-TargetResource
{
    [OutputType([System.Collections.Hashtable])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [System.String]
        $ProductId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        [Parameter()]
        [System.Boolean]
        $CreateCheckRegValue = $false,

        [Parameter()]
        [ValidateSet('LocalMachine', 'CurrentUser')]
        [System.String]
        $InstalledCheckRegHive = 'LocalMachine',

        [Parameter()]
        [System.String]
        $InstalledCheckRegKey,

        [Parameter()]
        [System.String]
        $InstalledCheckRegValueName,

        [Parameter()]
        [System.String]
        $InstalledCheckRegValueData
    )

    Write-Verbose -Message $script:localizedData.EnteringGetTargetResource

    Assert-PathExtensionValid -Path $Path

    $identifyingNumber = [System.String]::Empty

    if (-not [System.String]::IsNullOrEmpty($ProductId))
    {
        $identifyingNumber = Convert-ProductIdToIdentifyingNumber -ProductId $ProductId
    }

    $packageResourceResult = @{}

    $getProductEntryParameters = @{
        Name              = $Name
        IdentifyingNumber = $identifyingNumber
    }

    $checkRegistryValueParameters = @{
        CreateCheckRegValue        = $CreateCheckRegValue
        InstalledCheckRegHive      = $InstalledCheckRegHive
        InstalledCheckRegKey       = $InstalledCheckRegKey
        InstalledCheckRegValueName = $InstalledCheckRegValueName
        InstalledCheckRegValueData = $InstalledCheckRegValueData
    }

    if ($CreateCheckRegValue)
    {
        Assert-RegistryParametersValid -InstalledCheckRegKey $InstalledCheckRegKey -InstalledCheckRegValueName $InstalledCheckRegValueName -InstalledCheckRegValueData $InstalledCheckRegValueData

        $getProductEntryParameters += $checkRegistryValueParameters
        $packageResourceResult += $checkRegistryValueParameters
    }

    $productEntry = Get-ProductEntry @getProductEntryParameters

    if ($null -eq $productEntry)
    {
        $packageResourceResult += @{
            Ensure    = 'Absent'
            Name      = $Name
            ProductId = $identifyingNumber
            Path      = $Path
            Installed = $false
        }

        return $packageResourceResult
    }
    elseif ($CreateCheckRegValue)
    {
        $packageResourceResult += @{
            Ensure    = 'Present'
            Name      = $Name
            ProductId = $identifyingNumber
            Path      = $Path
            Installed = $true
        }

        return $packageResourceResult
    }

    <#
        Identifying number can still be null here (e.g. remote MSI with Name specified, local EXE).
        If the user gave a product ID just pass it through, otherwise get it from the product.
    #>
    if ($null -eq $identifyingNumber -and $null -ne $productEntry.Name)
    {
        $identifyingNumber = Split-Path -Path $productEntry.Name -Leaf
    }

    $installDate = $productEntry.GetValue('InstallDate')

    if ($null -ne $installDate)
    {
        try
        {
            $installDate = '{0:d}' -f [System.DateTime]::ParseExact($installDate, 'yyyyMMdd', [System.Globalization.CultureInfo]::CurrentCulture).Date
        }
        catch
        {
            $installDate = $null
        }
    }

    $publisher = Get-LocalizedRegistryKeyValue -RegistryKey $productEntry -ValueName 'Publisher'

    $estimatedSize = $productEntry.GetValue('EstimatedSize')

    if ($null -ne $estimatedSize)
    {
        $estimatedSize = $estimatedSize / 1024
    }

    $displayVersion = $productEntry.GetValue('DisplayVersion')

    $comments = $productEntry.GetValue('Comments')

    $displayName = Get-LocalizedRegistryKeyValue -RegistryKey $productEntry -ValueName 'DisplayName'

    $packageResourceResult += @{
        Ensure             = 'Present'
        Name               = $displayName
        Path               = $Path
        InstalledOn        = $installDate
        ProductId          = $identifyingNumber
        Size               = $estimatedSize
        Installed          = $true
        Version            = $displayVersion
        PackageDescription = $comments
        Publisher          = $publisher
    }

    return $packageResourceResult
}

<#
    .SYNOPSIS
        Installs or uninstalls a package.

    .PARAMETER Ensure
        Indicates whether to Ensure that the package is 'Present' or 'Absent'.
        Defaults to 'Present'.

    .PARAMETER Name
        The name of the package to be added or removed.

    .PARAMETER ProductId
        The identifying number used to uniquely identify this package.

    .PARAMETER Path
        The path, URL or UNC path to the package.

    .PARAMETER Arguments
        The arguments to be passed to the package during addition or removal.

        When installing MSI packages, the `/quiet` and `/norestart` arguments are
        automatically applied.

    .PARAMETER IgnoreReboot
        Ignore a pending reboot if requested by package installation. The default
        value is $false and DSC will try to reboot the system.

    .PARAMETER Credential
        The credentials to be used for mounting the UNC path (if applicable).

    .PARAMETER ReturnCode
        The list of possible valid return codes for this install or removal.

    .PARAMETER LogPath
        The path to log the output of the MSI or EXE.

    .PARAMETER FileHash
        The expected hash value of the file found in the Path location.

    .PARAMETER HashAlgorithm
        The algorithm used to generate the FileHash value. Defaults to 'SHA256'.

    .PARAMETER SignerSubject
        The subject that must match the signer certificate of the digital signature.
        Wildcards are allowed.

    .PARAMETER SignerThumbprint
        The certificate thumbprint which must match the signer certificate of the
        digital signature.

    .PARAMETER ServerCertificateValidationCallback
        PowerShell code used to validate SSL certificates of HTTPS url assigned to Path.

    .PARAMETER RunAsCredential
        The credentials under which to run the installation.

    .PARAMETER CreateCheckRegValue
        Specifies if a registry value should be created when the packages is installed.

    .PARAMETER InstalledCheckRegHive
        The hive in which to create the registry key. Defaults to 'LocalMachine'.

    .PARAMETER InstalledCheckRegKey
        The registry key to validate the package is installed.

    .PARAMETER InstalledCheckRegValueName
        The registry value name to validate the package is installed.

    .PARAMETER InstalledCheckRegValueData
        The registry value to validate the package is installed.
#>
function Set-TargetResource
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [System.String]
        $ProductId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        [Parameter()]
        [System.String]
        $Arguments,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        # Return codes 1641 and 3010 indicate success when a restart is requested per installation
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.UInt32[]]
        $ReturnCode = @( 0, 1641, 3010 ),

        [Parameter()]
        [System.String]
        $LogPath,

        [Parameter()]
        [System.String]
        $FileHash,

        [Parameter()]
        [ValidateSet('SHA1', 'SHA256', 'SHA384', 'SHA512', 'MD5', 'RIPEMD160')]
        [System.String]
        $HashAlgorithm,

        [Parameter()]
        [System.String]
        $SignerSubject,

        [Parameter()]
        [System.String]
        $SignerThumbprint,

        [Parameter()]
        [System.String]
        $ServerCertificateValidationCallback,

        [Parameter()]
        [System.Boolean]
        $CreateCheckRegValue = $false,

        [Parameter()]
        [ValidateSet('LocalMachine', 'CurrentUser')]
        [System.String]
        $InstalledCheckRegHive = 'LocalMachine',

        [Parameter()]
        [System.String]
        $InstalledCheckRegKey,

        [Parameter()]
        [System.String]
        $InstalledCheckRegValueName,

        [Parameter()]
        [System.String]
        $InstalledCheckRegValueData,

        [Parameter()]
        [System.Boolean]
        $IgnoreReboot = $false,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.CredentialAttribute()]
        $RunAsCredential
    )

    $ErrorActionPreference = 'Stop'

    if (Test-TargetResource @PSBoundParameters)
    {
        return
    }

    Assert-PathExtensionValid -Path $Path
    $uri = Convert-PathToUri -Path $Path

    if (-not [System.String]::IsNullOrEmpty($ProductId))
    {
        $identifyingNumber = Convert-ProductIdToIdentifyingNumber -ProductId $ProductId
    }
    else
    {
        $identifyingNumber = $ProductId
    }

    $productEntry = Get-ProductEntry -Name $Name -IdentifyingNumber $identifyingNumber

    <#
        Path gets overwritten in the download code path. Retain the user's original Path in case
        the install succeeded but the named package wasn't present on the system afterward so we
        can give a better error message.
    #>
    $originalPath = $Path

    Write-Verbose -Message $script:localizedData.PackageConfigurationStarting

    $logStream = $null
    $psDrive = $null
    $downloadedFileName = $null

    try
    {
        $fileExtension = [System.IO.Path]::GetExtension($Path).ToLower()
        if (-not [System.String]::IsNullOrEmpty($LogPath))
        {
            try
            {
                if ($fileExtension -eq '.msi')
                {
                    <#
                        We want to pre-verify the log path exists and is writable ahead of time
                        even in the MSI case, as detecting WHY the MSI log path doesn't exist would
                        be rather problematic for the user.
                    #>
                    if ((Test-Path -Path $LogPath) -and $PSCmdlet.ShouldProcess($script:localizedData.RemoveExistingLogFile, $null, $null))
                    {
                        Remove-Item -Path $LogPath
                    }

                    if ($PSCmdlet.ShouldProcess($script:localizedData.CreateLogFile, $null, $null))
                    {
                        New-Item -Path $LogPath -Type 'File' | Out-Null
                    }
                }
                elseif ($PSCmdlet.ShouldProcess($script:localizedData.CreateLogFile, $null, $null))
                {
                    $logStream = New-Object -TypeName 'System.IO.StreamWriter' -ArgumentList @( $LogPath, $false )
                }
            }
            catch
            {
                New-InvalidOperationException -Message ($script:localizedData.CouldNotOpenLog -f $LogPath) -ErrorRecord $_
            }
        }

        # Download or mount file as necessary
        if (-not ($fileExtension -eq '.msi' -and $Ensure -eq 'Absent'))
        {
            if ($uri.IsUnc -and $PSCmdlet.ShouldProcess($script:localizedData.MountSharePath, $null, $null))
            {
                $psDriveArgs = @{
                    Name       = [System.Guid]::NewGuid()
                    PSProvider = 'FileSystem'
                    Root       = Split-Path -Path $uri.LocalPath
                }

                # If we pass a null for Credential, a dialog will pop up.
                if ($null -ne $Credential)
                {
                    $psDriveArgs['Credential'] = $Credential
                }

                $psDrive = New-PSDrive @psDriveArgs
                $Path = Join-Path -Path $psDrive.Root -ChildPath (Split-Path -Path $uri.LocalPath -Leaf)
            }
            elseif (@( 'http', 'https' ) -contains $uri.Scheme -and $Ensure -eq 'Present' -and $PSCmdlet.ShouldProcess($script:localizedData.DownloadHTTPFile, $null, $null))
            {
                $uriScheme = $uri.Scheme
                $outStream = $null
                $responseStream = $null

                try
                {
                    Write-Verbose -Message ($script:localizedData.CreatingCacheLocation)

                    if (-not (Test-Path -Path $script:packageCacheLocation -PathType 'Container'))
                    {
                        New-Item -Path $script:packageCacheLocation -ItemType 'Directory' | Out-Null
                    }

                    $destinationPath = Join-Path -Path $script:packageCacheLocation -ChildPath (Split-Path -Path $uri.LocalPath -Leaf)

                    Write-Verbose -Message ($script:localizedData.NeedtodownloadfilefromschemedestinationwillbedestName -f $uriScheme, $destinationPath)

                    try
                    {
                        Write-Verbose -Message ($script:localizedData.CreatingTheDestinationCacheFile)
                        $outStream = New-Object -TypeName 'System.IO.FileStream' -ArgumentList @( $destinationPath, 'Create' )
                    }
                    catch
                    {
                        # Should never happen since we own the cache directory
                        New-InvalidOperationException -Message ($script:localizedData.CouldNotOpenDestFile -f $destinationPath) -ErrorRecord $_
                    }

                    try
                    {
                        Write-Verbose -Message ($script:localizedData.CreatingTheSchemeStream -f $uriScheme)
                        $webRequest = [System.Net.WebRequest]::Create($uri)

                        Write-Verbose -Message ($script:localizedData.SettingDefaultCredential)
                        $webRequest.Credentials = [System.Net.CredentialCache]::DefaultCredentials

                        if ($uriScheme -eq 'http')
                        {
                            # Default value is MutualAuthRequested, which applies to the https scheme
                            Write-Verbose -Message ($script:localizedData.SettingAuthenticationLevel)
                            $webRequest.AuthenticationLevel = [System.Net.Security.AuthenticationLevel]::None
                        }
                        elseif ($uriScheme -eq 'https' -and -not [System.String]::IsNullOrEmpty($ServerCertificateValidationCallback))
                        {
                            Write-Verbose -Message 'Assigning user-specified certificate verification callback'
                            $serverCertificateValidationScriptBlock = [System.Management.Automation.ScriptBlock]::Create($ServerCertificateValidationCallback)
                            $webRequest.ServerCertificateValidationCallBack = $serverCertificateValidationScriptBlock
                        }

                        Write-Verbose -Message ($script:localizedData.Gettingtheschemeresponsestream -f $uriScheme)
                        $responseStream = (([System.Net.HttpWebRequest] $webRequest).GetResponse()).GetResponseStream()
                    }
                    catch
                    {
                        Write-Verbose -Message ($script:localizedData.ErrorOutString -f ($_ | Out-String))
                        New-InvalidOperationException -Message ($script:localizedData.CouldNotGetHttpStream -f $uriScheme, $Path) -ErrorRecord $_
                    }

                    try
                    {
                        Write-Verbose -Message ($script:localizedData.CopyingTheSchemeStreamBytesToTheDiskCache -f $uriScheme)
                        $responseStream.CopyTo($outStream)
                        $responseStream.Flush()
                        $outStream.Flush()
                    }
                    catch
                    {
                        New-InvalidOperationException -Message ($script:localizedData.ErrorCopyingDataToFile -f $Path, $destinationPath) -ErrorRecord $_
                    }
                }
                finally
                {
                    if ($null -ne $outStream)
                    {
                        $outStream.Close()
                    }

                    if ($null -ne $responseStream)
                    {
                        $responseStream.Close()
                    }
                }

                Write-Verbose -Message ($script:localizedData.RedirectingPackagePathToCacheFileLocation)
                $Path = $destinationPath
                $downloadedFileName = $destinationPath
            }

            # At this point the Path ought to be valid unless it's a MSI uninstall case
            if (-not (Test-Path -Path $Path -PathType 'Leaf'))
            {
                New-InvalidOperationException -Message ($script:localizedData.PathDoesNotExist -f $Path)
            }

            Assert-FileValid -Path $Path -HashAlgorithm $HashAlgorithm -FileHash $FileHash -SignerSubject $SignerSubject -SignerThumbprint $SignerThumbprint
        }

        $startInfo = New-Object -TypeName 'System.Diagnostics.ProcessStartInfo'

        # Necessary for I/O redirection and just generally a good idea
        $startInfo.UseShellExecute = $false

        $process = New-Object -TypeName 'System.Diagnostics.Process'
        $process.StartInfo = $startInfo

        # Concept only, will never touch disk
        $errorLogPath = $LogPath + '.err'

        if ($fileExtension -eq '.msi')
        {
            $startInfo.FileName = "$env:winDir\system32\msiexec.exe"

            if ($Ensure -eq 'Present')
            {
                # Check if the MSI package specifies the ProductName and Code
                $productName = Get-MsiProductName -Path $Path
                $productCode = Get-MsiProductCode -Path $Path

                if ((-not [System.String]::IsNullOrEmpty($Name)) -and ($productName -ne $Name))
                {
                    New-InvalidArgumentException -ArgumentName 'Name' -Message ($script:localizedData.InvalidNameOrId -f $Name, $identifyingNumber, $productName, $productCode)
                }

                if ((-not [System.String]::IsNullOrEmpty($identifyingNumber)) -and ($identifyingNumber -ne $productCode))
                {
                    New-InvalidArgumentException -ArgumentName 'ProductId' -Message ($script:localizedData.InvalidNameOrId -f $Name, $identifyingNumber, $productName, $productCode)
                }

                $startInfo.Arguments = '/i "{0}"' -f $Path
            }
            else
            {
                $productEntry = Get-ProductEntry -Name $Name -IdentifyingNumber $identifyingNumber

                # We may have used the Name earlier, now we need the actual ID
                $id = Split-Path -Path $productEntry.Name -Leaf
                $startInfo.Arguments = '/x{0}' -f $id
            }

            if ($LogPath)
            {
                $startInfo.Arguments += ' /log "{0}"' -f $LogPath
            }

            $startInfo.Arguments += ' /quiet /norestart'

            if ($Arguments)
            {
                # Append any specified arguments with a space (#195)
                $startInfo.Arguments += ' {0}' -f $Arguments
            }
        }
        else
        {
            # EXE
            Write-Verbose -Message $script:localizedData.TheBinaryIsAnExe

            if ($Ensure -eq 'Present')
            {
                $startInfo.FileName = $Path
                $startInfo.Arguments = $Arguments

                if ($LogPath)
                {
                    Write-Verbose -Message ($script:localizedData.UserHasRequestedLoggingNeedToAttachEventHandlersToTheProcess)
                    $startInfo.RedirectStandardError = $true
                    $startInfo.RedirectStandardOutput = $true

                    Register-ObjectEvent -InputObject $process -EventName 'OutputDataReceived' -SourceIdentifier $LogPath
                    Register-ObjectEvent -InputObject $process -EventName 'ErrorDataReceived' -SourceIdentifier $errorLogPath
                }
            }
            else
            {
                # Absent case
                $startInfo.FileName = "$env:winDir\system32\msiexec.exe"

                # We may have used the Name earlier, now we need the actual ID
                if ($null -eq $productEntry -or $null -eq $productEntry.Name)
                {
                    $id = $Path
                }
                else
                {
                    $id = Split-Path -Path $productEntry.Name -Leaf
                }

                $startInfo.Arguments = "/x `"$id`" /quiet /norestart"

                if ($LogPath)
                {
                    $startInfo.Arguments += ' /log "{0}"' -f $LogPath
                }

                if ($Arguments)
                {
                    # Append the specified arguments with a space (#195)
                    $startInfo.Arguments += ' {0}' -f $Arguments
                }
            }
        }

        Write-Verbose -Message ($script:localizedData.StartingWithStartInfoFileNameStartInfoArguments -f $startInfo.FileName, $startInfo.Arguments)

        if ($PSCmdlet.ShouldProcess(($script:localizedData.StartingProcessMessage -f $startInfo.FileName, $startInfo.Arguments), $null, $null))
        {
            try
            {
                [System.Int32] $exitCode = 0
                if ($PSBoundParameters.ContainsKey('RunAsCredential'))
                {
                    $commandLine = '"{0}" {1}' -f $startInfo.FileName, $startInfo.Arguments
                    $exitCode = Invoke-PInvoke -CommandLine $commandLine -Credential $RunAsCredential
                }
                else
                {
                    $process = Invoke-Process -Process $process -LogStream ($null -ne $logStream)
                    $exitCode = $process.ExitCode
                }
            }
            catch
            {
                New-InvalidOperationException -Message ($script:localizedData.CouldNotStartProcess -f $Path) -ErrorRecord $_
            }

            if ($logStream)
            {
                <#
                    We have to re-mux these since they appear to us as different streams
                    the underlying Win32 APIs prevent this problem, as would constructing a script
                    on the fly and executing it, but the former is highly problematic from PowerShell
                    and the latter doesn't let us get the return code for UI-based EXEs
                #>
                $outputEvents = Get-Event -SourceIdentifier $LogPath
                $errorEvents = Get-Event -SourceIdentifier $errorLogPath
                $masterEvents = @() + $outputEvents + $errorEvents
                $masterEvents = $masterEvents | Sort-Object -Property TimeGenerated

                foreach ($event in $masterEvents)
                {
                    $logStream.Write($event.SourceEventArgs.Data);
                }

                Remove-Event -SourceIdentifier $LogPath
                Remove-Event -SourceIdentifier $errorLogPath
            }

            if (-not ($ReturnCode -contains $exitCode))
            {
                # Some .exe files do not support uninstall
                if ($Ensure -eq 'Absent' -and $fileExtension -eq '.exe' -and $exitCode -eq '1620')
                {
                    Write-Warning -Message ($script:localizedData.ExeCouldNotBeUninstalled -f $Path)
                }
                else
                {
                    New-InvalidOperationException ($script:localizedData.UnexpectedReturnCode -f $exitCode.ToString())
                }
            }
        }
    }
    finally
    {
        if ($psDrive)
        {
            Remove-PSDrive -Name $psDrive -Force
        }

        if ($logStream)
        {
            $logStream.Dispose()
        }
    }

    if ($downloadedFileName -and $PSCmdlet.ShouldProcess($script:localizedData.RemoveDownloadedFile, $null, $null))
    {
        <#
            This is deliberately not in the finally block because we want to leave the downloaded
            file on disk if an error occurred as a debugging aid for the user.
        #>
        Remove-Item -Path $downloadedFileName
    }

    $operationMessageString = $script:localizedData.PackageUninstalled
    if ($Ensure -eq 'Present')
    {
        $operationMessageString = $script:localizedData.PackageInstalled
    }

    if ($CreateCheckRegValue)
    {
        $registryValueString = '{0}\{1}\{2}' -f $InstalledCheckRegHive, $InstalledCheckRegKey, $InstalledCheckRegValueName
        if ($Ensure -eq 'Present')
        {
            Write-Verbose -Message ($script:localizedData.CreatingRegistryValue -f $registryValueString)
            Set-RegistryValue -RegistryHive $InstalledCheckRegHive -Key $InstalledCheckRegKey -Value $InstalledCheckRegValueName -Data $InstalledCheckRegValueData
        }
        else
        {
            Write-Verbose ($script:localizedData.RemovingRegistryValue -f $registryValueString)
            Remove-RegistryValue -RegistryHive $InstalledCheckRegHive -Key $InstalledCheckRegKey -Value $InstalledCheckRegValueName
        }
    }

    <#
        Check if a reboot is required, if so notify CA. The MSFT_ServerManagerTasks provider is
        missing on some client SKUs (worked on both Server and Client Skus in Windows 10).
    #>

    $serverFeatureData = Invoke-CimMethod `
        -Name 'GetServerFeature' `
        -Namespace 'root\microsoft\windows\servermanager' `
        -Class 'MSFT_ServerManagerTasks' `
        -Arguments @{
            BatchSize = 256
        } `
        -ErrorAction 'Ignore'
    $registryData = Get-ItemProperty `
        -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' `
        -Name 'PendingFileRenameOperations' `
        -ErrorAction 'Ignore'

    if (($serverFeatureData -and $serverFeatureData.RequiresReboot) -or $registryData -or $exitcode -eq 3010 -or $exitcode -eq 1641)
    {
        Write-Verbose $script:localizedData.MachineRequiresReboot
        if ($IgnoreReboot)
        {
            Write-Verbose $script:localizedData.IgnoreReboot
        }
        else
        {
            Set-DscMachineRebootRequired
        }
    }
    elseif ($Ensure -eq 'Present')
    {
        $getProductEntryParameters = @{
            Name              = $Name
            IdentifyingNumber = $identifyingNumber
        }

        $checkRegistryValueParameters = @{
            CreateCheckRegValue        = $CreateCheckRegValue
            InstalledCheckRegHive      = $InstalledCheckRegHive
            InstalledCheckRegKey       = $InstalledCheckRegKey
            InstalledCheckRegValueName = $InstalledCheckRegValueName
            InstalledCheckRegValueData = $InstalledCheckRegValueData
        }

        if ($CreateCheckRegValue)
        {
            $getProductEntryParameters += $checkRegistryValueParameters
        }

        $productEntry = Get-ProductEntry @getProductEntryParameters

        if ($null -eq $productEntry)
        {
            New-InvalidOperationException -Message ($script:localizedData.PostValidationError -f $originalPath)
        }
    }

    Write-Verbose -Message $operationMessageString
    Write-Verbose -Message $script:localizedData.PackageConfigurationComplete
}

<#
    .SYNOPSIS
        Tests the current state of the installed package.

    .PARAMETER Ensure
        Indicates whether to Ensure that the package is 'Present' or 'Absent'.
        Defaults to 'Present'.

    .PARAMETER Name
        The name of the package to be added or removed.

    .PARAMETER ProductId
        The identifying number used to uniquely identify this package.

    .PARAMETER Path
        The path, URL or UNC path to the package.

    .PARAMETER Arguments
        The arguments to be passed to the package during addition or removal.

        When installing MSI packages, the '/quiet' and '/norestart' arguments are
        automatically applied.

    .PARAMETER IgnoreReboot
        Ignore a pending reboot if requested by package installation. The default
        value is $false and DSC will try to reboot the system.

    .PARAMETER Credential
        The credentials to be used for mounting the UNC path (if applicable).

    .PARAMETER ReturnCode
        The list of possible valid return codes for this install or removal.

    .PARAMETER LogPath
        The path to log the output of the MSI or EXE.

    .PARAMETER FileHash
        The expected hash value of the file found in the Path location.

    .PARAMETER HashAlgorithm
        The algorithm used to generate the FileHash value. Defaults to 'SHA256'.

    .PARAMETER SignerSubject
        The subject that must match the signer certificate of the digital signature.
        Wildcards are allowed.

    .PARAMETER SignerThumbprint
        The certificate thumbprint which must match the signer certificate of the
        digital signature.

    .PARAMETER ServerCertificateValidationCallback
        PowerShell code used to validate SSL certificates of HTTPS url assigned to Path.

    .PARAMETER RunAsCredential
        The credentials under which to run the installation.

    .PARAMETER CreateCheckRegValue
        Specifies if a registry value should be created when the packages is installed.

    .PARAMETER InstalledCheckRegHive
        The hive in which to create the registry key. Defaults to 'LocalMachine'.

    .PARAMETER InstalledCheckRegKey
        The registry key to validate the package is installed.

    .PARAMETER InstalledCheckRegValueName
        The registry value name to validate the package is installed.

    .PARAMETER InstalledCheckRegValueData
        The registry value to validate the package is installed.
#>

function Test-TargetResource
{
    [OutputType([System.Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [System.String]
        $ProductId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        [Parameter()]
        [System.String]
        $Arguments,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        # Return codes 1641 and 3010 indicate success when a restart is requested per installation
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.UInt32[]]
        $ReturnCode = @( 0, 1641, 3010 ),

        [Parameter()]
        [System.String]
        $LogPath,

        [Parameter()]
        [System.String]
        $FileHash,

        [Parameter()]
        [ValidateSet('SHA1', 'SHA256', 'SHA384', 'SHA512', 'MD5', 'RIPEMD160')]
        [System.String]
        $HashAlgorithm,

        [Parameter()]
        [System.String]
        $SignerSubject,

        [Parameter()]
        [System.String]
        $SignerThumbprint,

        [Parameter()]
        [System.String]
        $ServerCertificateValidationCallback,

        [Parameter()]
        [System.Boolean]
        $CreateCheckRegValue = $false,

        [Parameter()]
        [ValidateSet('LocalMachine', 'CurrentUser')]
        [System.String]
        $InstalledCheckRegHive = 'LocalMachine',

        [Parameter()]
        [System.String]
        $InstalledCheckRegKey,

        [Parameter()]
        [System.String]
        $InstalledCheckRegValueName,

        [Parameter()]
        [System.String]
        $InstalledCheckRegValueData,

        [Parameter()]
        [System.Boolean]
        $IgnoreReboot = $false,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $RunAsCredential
    )

    Assert-PathExtensionValid -Path $Path
    $identifyingNumber = $null

    if (-not [System.String]::IsNullOrEmpty($ProductId))
    {
        $identifyingNumber = Convert-ProductIdToIdentifyingNumber -ProductId $ProductId
    }

    $getProductEntryParameters = @{
        Name              = $Name
        IdentifyingNumber = $identifyingNumber
    }

    $checkRegistryValueParameters = @{
        CreateCheckRegValue        = $CreateCheckRegValue
        InstalledCheckRegHive      = $InstalledCheckRegHive
        InstalledCheckRegKey       = $InstalledCheckRegKey
        InstalledCheckRegValueName = $InstalledCheckRegValueName
        InstalledCheckRegValueData = $InstalledCheckRegValueData
    }

    if ($CreateCheckRegValue)
    {
        Assert-RegistryParametersValid -InstalledCheckRegKey $InstalledCheckRegKey -InstalledCheckRegValueName $InstalledCheckRegValueName -InstalledCheckRegValueData $InstalledCheckRegValueData
        $getProductEntryParameters += $checkRegistryValueParameters
    }

    $productEntry = Get-ProductEntry @getProductEntryParameters

    Write-Verbose -Message ($script:localizedData.EnsureIsEnsure -f $Ensure)

    if ($null -ne $productEntry)
    {
        Write-Verbose -Message ($script:localizedData.ProductIsProduct -f $productEntry)
    }
    else
    {
        Write-Verbose -Message 'Product installation cannot be determined'
    }

    Write-Verbose -Message ($script:localizedData.ProductAsBooleanIs -f [System.Boolean] $productEntry)

    if ($null -ne $productEntry)
    {
        if ($CreateCheckRegValue)
        {
            Write-Verbose -Message ($script:localizedData.PackageAppearsInstalled -f $Name)
        }
        else
        {
            $displayName = Get-LocalizedRegistryKeyValue -RegistryKey $productEntry -ValueName 'DisplayName'
            Write-Verbose -Message ($script:localizedData.PackageAppearsInstalled -f $displayName)
        }
    }
    else
    {
        $displayName = $null

        if (-not [System.String]::IsNullOrEmpty($Name))
        {
            $displayName = $Name
        }
        else
        {
            $displayName = $ProductId
        }

        Write-Verbose -Message ($script:localizedData.PackageDoesNotAppearInstalled -f $displayName)
    }

    return ($null -ne $productEntry -and $Ensure -eq 'Present') -or ($null -eq $productEntry -and $Ensure -eq 'Absent')
}

<#
    .SYNOPSIS
        Asserts that the path extension is valid - either .msi or .exe.

    .PARAMETER Path
        The path to validate the extension of.
#>
function Assert-PathExtensionValid
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path
    )

    $pathExtension = [System.IO.Path]::GetExtension($Path)
    Write-Verbose -Message ($script:localizedData.ThePathExtensionWasPathExt -f $pathExtension)

    $validPathExtensions = @( '.msi', '.exe' )

    if ($validPathExtensions -notcontains $pathExtension.ToLower())
    {
        New-InvalidArgumentException -ArgumentName 'Path' -Message ($script:localizedData.InvalidBinaryType -f $Path)
    }
}

<#
    .SYNOPSIS
        Converts the given path to a URI.
        Throws an exception if the path's scheme as a URI is not valid.

    .PARAMETER Path
        The path to retrieve as a URI.
#>
function Convert-PathToUri
{
    [OutputType([System.Uri])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path
    )

    try
    {
        $uri = [System.Uri] $Path
    }
    catch
    {
        New-InvalidArgumentException -ArgumentName 'Path' -Message ($script:localizedData.InvalidPath -f $Path)
    }

    $validUriSchemes = @( 'file', 'http', 'https' )

    if ($validUriSchemes -notcontains $uri.Scheme)
    {
        Write-Verbose -Message ($script:localizedData.TheUriSchemeWasUriScheme -f $uri.Scheme)
        New-InvalidArgumentException -ArgumentName 'Path' -Message ($script:localizedData.InvalidPath -f $Path)
    }

    return $uri
}

<#
    .SYNOPSIS
        Retrieves the product ID as an identifying number.

    .PARAMETER ProductId
        The product id to retrieve as an identifying number.
#>
function Convert-ProductIdToIdentifyingNumber
{
    [OutputType([System.String])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ProductId
    )

    try
    {
        Write-Verbose -Message ($script:localizedData.ParsingProductIdAsAnIdentifyingNumber -f $ProductId)
        $identifyingNumber = '{{{0}}}' -f [System.Guid]::Parse($ProductId).ToString().ToUpper()

        Write-Verbose -Message ($script:localizedData.ParsedProductIdAsIdentifyingNumber -f $ProductId, $identifyingNumber)
        return $identifyingNumber
    }
    catch
    {
        New-InvalidArgumentException -ArgumentName 'ProductId' -Message ($script:localizedData.InvalidIdentifyingNumber -f $ProductId)
    }
}

<#
    .SYNOPSIS
        Asserts that the InstalledCheckRegKey, InstalledCheckRegValueName, and
        InstalledCheckRegValueData parameter required for retrieving package installation status
        from a registry are not null or empty.

    .PARAMETER InstalledCheckRegKey
        The InstalledCheckRegKey parameter to check.

    .PARAMETER InstalledCheckRegValueName
        The InstalledCheckRegValueName parameter to check.

    .PARAMETER InstalledCheckRegValueData
        The InstalledCheckRegValueData parameter to check.

    .NOTES
        This could be done with parameter validation.
        It is implemented this way to provide a clearer error message.
#>
function Assert-RegistryParametersValid
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.String]
        $InstalledCheckRegKey,

        [Parameter()]
        [System.String]
        $InstalledCheckRegValueName,

        [Parameter()]
        [System.String]
        $InstalledCheckRegValueData
    )

    foreach ($parameter in $PSBoundParameters.Keys)
    {
        if ([System.String]::IsNullOrEmpty($PSBoundParameters[$parameter]))
        {
            New-InvalidArgumentException -ArgumentName $parameter -Message ($script:localizedData.ProvideParameterForRegistryCheck -f $parameter)
        }
    }
}

<#
    .SYNOPSIS
        Retrieves the product entry for the package with the given name and/or identifying number.

    .PARAMETER Name
        The name of the product entry to retrieve.

    .PARAMETER CreateCheckRegValue
        Indicates whether or not to retrieve the package installation status from a registry.

    .PARAMETER IdentifyingNumber
        The identifying number of the product entry to retrieve.

    .PARAMETER InstalledCheckRegHive
        The registry hive to check for package installation status.

    .PARAMETER InstalledCheckRegKey
        The registry key to open to check for package installation status.

    .PARAMETER InstalledCheckRegValueName
        The registry value name to check for package installation status.

    .PARAMETER InstalledCheckRegValueData
        The value to compare against the retrieved registry value to check for package installation.
#>
function Get-ProductEntry
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.String]
        $Name,

        [Parameter()]
        [System.String]
        $IdentifyingNumber,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $CreateCheckRegValue,

        [Parameter()]
        [ValidateSet('LocalMachine', 'CurrentUser')]
        [System.String]
        $InstalledCheckRegHive = 'LocalMachine',

        [Parameter()]
        [System.String]
        $InstalledCheckRegKey,

        [Parameter()]
        [System.String]
        $InstalledCheckRegValueName,

        [Parameter()]
        [System.String]
        $InstalledCheckRegValueData
    )

    $uninstallRegistryKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    $uninstallRegistryKeyWow64 = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'

    $productEntry = $null

    if (-not [System.String]::IsNullOrEmpty($IdentifyingNumber))
    {
        $productEntryKeyLocation = Join-Path -Path $uninstallRegistryKey -ChildPath $IdentifyingNumber
        $productEntry = Get-Item -Path $productEntryKeyLocation -ErrorAction 'SilentlyContinue'

        if ($null -eq $productEntry)
        {
            $productEntryKeyLocation = Join-Path -Path $uninstallRegistryKeyWow64 -ChildPath $IdentifyingNumber
            $productEntry = Get-Item $productEntryKeyLocation -ErrorAction 'SilentlyContinue'
        }
    }
    else
    {
        foreach ($registryKeyEntry in (Get-ChildItem -Path @( $uninstallRegistryKey, $uninstallRegistryKeyWow64) -ErrorAction 'Ignore' ))
        {
            if ($Name -eq (Get-LocalizedRegistryKeyValue -RegistryKey $registryKeyEntry -ValueName 'DisplayName'))
            {
                $productEntry = $registryKeyEntry
                break
            }
        }
    }

    if ($null -eq $productEntry)
    {
        if ($CreateCheckRegValue)
        {
            $installValue = $null

            $win32OperatingSystem = Get-CimInstance -ClassName 'Win32_OperatingSystem' -ErrorAction 'SilentlyContinue'

            # If 64-bit OS, check 64-bit registry view first
            if ($win32OperatingSystem.OSArchitecture -ieq '64-bit')
            {
                $installValue = Get-RegistryValueWithErrorsIgnored -Key $InstalledCheckRegKey -Value $InstalledCheckRegValueName -RegistryHive $InstalledCheckRegHive -RegistryView 'Registry64'
            }

            if ($null -eq $installValue)
            {
                $installValue = Get-RegistryValueWithErrorsIgnored -Key $InstalledCheckRegKey -Value $InstalledCheckRegValueName -RegistryHive $InstalledCheckRegHive -RegistryView 'Registry32'
            }

            if ($null -ne $installValue)
            {
                if ($InstalledCheckRegValueData -and $installValue -eq $InstalledCheckRegValueData)
                {
                    $productEntry = @{
                        Installed = $true
                    }
                }
            }
        }
    }

    return $productEntry
}

<#
    .SYNOPSIS
        Retrieves a value from a registry without throwing errors.

    .PARAMETER Key
        The key of the registry to get the value from.

    .PARAMETER Value
        The name of the value to retrieve.

    .PARAMETER RegistryHive
        The registry hive to retrieve the value from.

    .PARAMETER RegistyView
        The registry view to retrieve the value from.
#>
function Get-RegistryValueWithErrorsIgnored
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Key,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Value,

        [Parameter(Mandatory = $true)]
        [Microsoft.Win32.RegistryHive]
        $RegistryHive,

        [Parameter(Mandatory = $true)]
        [Microsoft.Win32.RegistryView]
        $RegistryView
    )

    $registryValue = $null

    try
    {
        $baseRegistryKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey($RegistryHive, $RegistryView)
        $subRegistryKey = $baseRegistryKey.OpenSubKey($Key)

        if ($null -ne $subRegistryKey)
        {
            $registryValue = $subRegistryKey.GetValue($Value)
        }
    }
    catch
    {
        $exceptionText = ($_ | Out-String).Trim()
        Write-Verbose -Message "An exception occured while attempting to retrieve a registry value: $exceptionText"
    }

    return $registryValue
}

<#
    .SYNOPSIS
        Retrieves a localized registry key value.

    .PARAMETER RegistryKey
        The registry key to retrieve the value from.

    .PARAMETER ValueName
        The name of the value to retrieve.
#>
function Get-LocalizedRegistryKeyValue
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.Object]
        $RegistryKey,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ValueName
    )

    $localizedRegistryKeyValue = $RegistryKey.GetValue('{0}_Localized' -f $ValueName)

    if ($null -eq $localizedRegistryKeyValue)
    {
        $localizedRegistryKeyValue = $RegistryKey.GetValue($ValueName)
    }

    return $localizedRegistryKeyValue
}

<#
    .SYNOPSIS
        Asserts that the file at the given path is valid.

    .PARAMETER Path
        The path to the file to check.

    .PARAMETER FileHash
        The hash that should match the hash of the file.

    .PARAMETER HashAlgorithm
        The algorithm to use to retrieve the file hash.

    .PARAMETER SignerThumbprint
        The certificate thumbprint that should match the file's signer certificate.

    .PARAMETER SignerSubject
        The certificate subject that should match the file's signer certificate.
#>
function Assert-FileValid
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter()]
        [System.String]
        $FileHash,

        [Parameter()]
        [System.String]
        $HashAlgorithm,

        [Parameter()]
        [System.String]
        $SignerThumbprint,

        [Parameter()]
        [System.String]
        $SignerSubject
    )

    if (-not [System.String]::IsNullOrEmpty($FileHash))
    {
        Assert-FileHashValid -Path $Path -Hash $FileHash -Algorithm $HashAlgorithm
    }

    if (-not [System.String]::IsNullOrEmpty($SignerThumbprint) -or -not [System.String]::IsNullOrEmpty($SignerSubject))
    {
        Assert-FileSignatureValid -Path $Path -Thumbprint $SignerThumbprint -Subject $SignerSubject
    }
}

<#
    .SYNOPSIS
        Asserts that the hash of the file at the given path matches the given hash.

    .PARAMETER Path
        The path to the file to check the hash of.

    .PARAMETER Hash
        The hash to check against.

    .PARAMETER Algorithm
        The algorithm to use to retrieve the file's hash.
#>
function Assert-FileHashValid
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Hash,

        [Parameter()]
        [System.String]
        $Algorithm = 'SHA256'
    )

    if ([System.String]::IsNullOrEmpty($Algorithm))
    {
        $Algorithm = 'SHA256'
    }

    Write-Verbose -Message ($script:localizedData.CheckingFileHash -f $Path, $Hash, $Algorithm)

    $fileHash = Get-FileHash -LiteralPath $Path -Algorithm $Algorithm -ErrorAction 'Stop'

    if ($fileHash.Hash -ne $Hash)
    {
        throw ($script:localizedData.InvalidFileHash -f $Path, $Hash, $Algorithm)
    }
}

<#
    .SYNOPSIS
        Asserts that the signature of the file at the given path is valid.

    .PARAMETER Path
        The path to the file to check the signature of

    .PARAMETER Thumbprint
        The certificate thumbprint that should match the file's signer certificate.

    .PARAMETER Subject
        The certificate subject that should match the file's signer certificate.
#>
function Assert-FileSignatureValid
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter()]
        [System.String]
        $Thumbprint,

        [Parameter()]
        [System.String]
        $Subject
    )

    Write-Verbose -Message ($script:localizedData.CheckingFileSignature -f $Path)

    $signature = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction 'Stop'

    if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid)
    {
        throw ($script:localizedData.InvalidFileSignature -f $Path, $signature.Status)
    }
    else
    {
        Write-Verbose -Message ($script:localizedData.FileHasValidSignature -f $Path, $signature.SignerCertificate.Thumbprint, $signature.SignerCertificate.Subject)
    }

    if ($null -ne $Subject -and ($signature.SignerCertificate.Subject -notlike $Subject))
    {
        throw ($script:localizedData.WrongSignerSubject -f $Path, $Subject)
    }

    if ($null -ne $Thumbprint -and ($signature.SignerCertificate.Thumbprint -ne $Thumbprint))
    {
        throw ($script:localizedData.WrongSignerThumbprint -f $Path, $Thumbprint)
    }
}

<#
    .SYNOPSIS
        Retrieves the name of a product from an msi.

    .PARAMETER Path
        The path to the msi to retrieve the name from.
#>
function Get-MsiProductName
{
    [OutputType([System.String])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path
    )

    $msiTools = Get-MsiTool

    $productName = $msiTools::GetProductName($Path)

    return $productName
}

<#
    .SYNOPSIS
        Retrieves the code of a product from an msi.

    .PARAMETER Path
        The path to the msi to retrieve the code from.
#>
function Get-MsiProductCode
{
    [OutputType([System.String])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path
    )

    $msiTools = Get-MsiTool

    $productCode = $msiTools::GetProductCode($Path)

    return $productCode
}

<#
    .SYNOPSIS
        Retrieves the MSI tools type.
#>
function Get-MsiTool
{
    [OutputType([System.Type])]
    [CmdletBinding()]
    param ()

    if ($null -ne $script:msiTools)
    {
        return $script:msiTools
    }

    $msiToolsCodeDefinition = @'
    [DllImport("msi.dll", CharSet = CharSet.Unicode, PreserveSig = true, SetLastError = true, ExactSpelling = true)]
    private static extern UInt32 MsiOpenPackageExW(string szPackagePath, int dwOptions, out IntPtr hProduct);

    [DllImport("msi.dll", CharSet = CharSet.Unicode, PreserveSig = true, SetLastError = true, ExactSpelling = true)]
    private static extern uint MsiCloseHandle(IntPtr hAny);

    [DllImport("msi.dll", CharSet = CharSet.Unicode, PreserveSig = true, SetLastError = true, ExactSpelling = true)]
    private static extern uint MsiGetPropertyW(IntPtr hAny, string name, StringBuilder buffer, ref int bufferLength);

    private static string GetPackageProperty(string msi, string property)
    {
        IntPtr MsiHandle = IntPtr.Zero;
        try
        {
            var res = MsiOpenPackageExW(msi, 1, out MsiHandle);
            if (res != 0)
            {
                return null;
            }

            int length = 256;
            var buffer = new StringBuilder(length);
            res = MsiGetPropertyW(MsiHandle, property, buffer, ref length);
            return buffer.ToString();
        }
        finally
        {
            if (MsiHandle != IntPtr.Zero)
            {
                MsiCloseHandle(MsiHandle);
            }
        }
    }
    public static string GetProductCode(string msi)
    {
        return GetPackageProperty(msi, "ProductCode");
    }

    public static string GetProductName(string msi)
    {
        return GetPackageProperty(msi, "ProductName");
    }
'@

    if (([System.Management.Automation.PSTypeName]'Microsoft.Windows.DesiredStateConfiguration.xPackageResource.MsiTools').Type)
    {
        $script:msiTools = ([System.Management.Automation.PSTypeName]'Microsoft.Windows.DesiredStateConfiguration.xPackageResource.MsiTools').Type
    }
    else
    {
        $script:msiTools = Add-Type `
            -Namespace 'Microsoft.Windows.DesiredStateConfiguration.xPackageResource' `
            -Name 'MsiTools' `
            -Using 'System.Text' `
            -MemberDefinition $msiToolsCodeDefinition `
            -PassThru
    }

    return $script:msiTools
}

<#
    .SYNOPSIS
        Runs a process as the specified user via PInvoke.

    .PARAMETER CommandLine
        The command line (including arguments) of the process to start.

    .PARAMETER Credential
        The user credential to start the process as.
#>
function Invoke-PInvoke
{
    [CmdletBinding()]
    [OutputType([System.Int32])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $CommandLine,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.CredentialAttribute()]
        $Credential
    )

    Register-PInvoke
    [System.Int32] $exitCode = 0

    [Source.NativeMethods]::CreateProcessAsUser($CommandLine, `
            $Credential.GetNetworkCredential().Domain, `
            $Credential.GetNetworkCredential().UserName, `
            $Credential.GetNetworkCredential().Password, `
            [ref] $exitCode
    )

    return $exitCode;
}

<#
    .SYNOPSIS
        Starts and waits for a process.

    .DESCRIPTION
        Allows mocking and testing of process arguments.

    .PARAMETER Process
        The System.Diagnositics.Process object to start.

    .PARAMETER LogStream
        Redirect STDOUT and STDERR output.
#>
function Invoke-Process
{
    [CmdletBinding()]
    [OutputType([System.Diagnostics.Process])]
    param (
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]
        $Process,

        [Parameter()]
        [System.Boolean]
        $LogStream
    )

    $Process.Start() | Out-Null

    if ($LogStream)
    {
        $Process.BeginOutputReadLine()
        $Process.BeginErrorReadLine()
    }

    $Process.WaitForExit()
    return $Process
}

<#
    .SYNOPSIS
        Sets the value of a registry key to the specified data.

    .PARAMETER Key
        The registry key that contains the value to set.

    .PARAMETER Value
        The value name of the registry key value to set.

    .PARAMETER RegistryHive
        The registry hive that contains the registry key to set.

    .PARAMETER Data
        The data to set the registry key value to.
#>
function Set-RegistryValue
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Key,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Value,

        [Parameter(Mandatory = $true)]
        [Microsoft.Win32.RegistryHive]
        $RegistryHive,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Data
    )

    try
    {
        $baseRegistryKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey($RegistryHive, [Microsoft.Win32.RegistryView]::Default)

        # Opens the subkey with write access
        $subRegistryKey = $baseRegistryKey.OpenSubKey($Key, $true)

        if ($null -eq $subRegistryKey)
        {
            Write-Verbose "Key: '$Key'"
            $subRegistryKey = $baseRegistryKey.CreateSubKey($Key)
        }

        $subRegistryKey.SetValue($Value, $Data)
        $subRegistryKey.Close()
    }
    catch
    {
        New-InvalidOperationException -Message ($script:localizedData.ErrorSettingRegistryValue -f $Key, $Value, $Data) -ErrorRecord $_
    }
}

<#
    .SYNOPSIS
        Removes the specified value of a registry key.

    .PARAMETER Key
        The registry key that contains the value to remove.

    .PARAMETER Value
        The value name of the registry key value to remove.

    .PARAMETER RegistryHive
        The registry hive that contains the registry key to remove.
#>
function Remove-RegistryValue
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Key,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Value,

        [Parameter(Mandatory = $true)]
        [Microsoft.Win32.RegistryHive]
        $RegistryHive
    )

    try
    {
        $baseRegistryKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey($RegistryHive, [Microsoft.Win32.RegistryView]::Default)

        $subRegistryKey = $baseRegistryKey.OpenSubKey($Key, $true)
        $subRegistryKey.DeleteValue($Value)
        $subRegistryKey.Close()
    }
    catch
    {
        New-InvalidOperationException -Message ($script:localizedData.ErrorRemovingRegistryValue -f $Key, $Value) -ErrorRecord $_
    }
}

<#
    .SYNOPSIS
        Registers PInvoke to run a process as a user.
#>
function Register-PInvoke
{
    $programSource = @'
        using System;
        using System.Collections.Generic;
        using System.Text;
        using System.Security;
        using System.Runtime.InteropServices;
        using System.Diagnostics;
        using System.Security.Principal;
        using System.ComponentModel;
        using System.IO;

        namespace Source
        {
            [SuppressUnmanagedCodeSecurity]
            public static class NativeMethods
            {
                //The following structs and enums are used by the various Win32 API's that are used in the code below

                [StructLayout(LayoutKind.Sequential)]
                public struct STARTUPINFO
                {
                    public Int32 cb;
                    public string lpReserved;
                    public string lpDesktop;
                    public string lpTitle;
                    public Int32 dwX;
                    public Int32 dwY;
                    public Int32 dwXSize;
                    public Int32 dwXCountChars;
                    public Int32 dwYCountChars;
                    public Int32 dwFillAttribute;
                    public Int32 dwFlags;
                    public Int16 wShowWindow;
                    public Int16 cbReserved2;
                    public IntPtr lpReserved2;
                    public IntPtr hStdInput;
                    public IntPtr hStdOutput;
                    public IntPtr hStdError;
                }

                [StructLayout(LayoutKind.Sequential)]
                public struct PROCESS_INFORMATION
                {
                    public IntPtr hProcess;
                    public IntPtr hThread;
                    public Int32 dwProcessID;
                    public Int32 dwThreadID;
                }

                [Flags]
                public enum LogonType
                {
                    LOGON32_LOGON_INTERACTIVE = 2,
                    LOGON32_LOGON_NETWORK = 3,
                    LOGON32_LOGON_BATCH = 4,
                    LOGON32_LOGON_SERVICE = 5,
                    LOGON32_LOGON_UNLOCK = 7,
                    LOGON32_LOGON_NETWORK_CLEARTEXT = 8,
                    LOGON32_LOGON_NEW_CREDENTIALS = 9
                }

                [Flags]
                public enum LogonProvider
                {
                    LOGON32_PROVIDER_DEFAULT = 0,
                    LOGON32_PROVIDER_WINNT35,
                    LOGON32_PROVIDER_WINNT40,
                    LOGON32_PROVIDER_WINNT50
                }
                [StructLayout(LayoutKind.Sequential)]
                public struct SECURITY_ATTRIBUTES
                {
                    public Int32 Length;
                    public IntPtr lpSecurityDescriptor;
                    public bool bInheritHandle;
                }

                public enum SECURITY_IMPERSONATION_LEVEL
                {
                    SecurityAnonymous,
                    SecurityIdentification,
                    SecurityImpersonation,
                    SecurityDelegation
                }

                public enum TOKEN_TYPE
                {
                    TokenPrimary = 1,
                    TokenImpersonation
                }

                [StructLayout(LayoutKind.Sequential, Pack = 1)]
                internal struct TokPriv1Luid
                {
                    public int Count;
                    public long Luid;
                    public int Attr;
                }

                public const int GENERIC_ALL_ACCESS = 0x10000000;
                public const int CREATE_NO_WINDOW = 0x08000000;
                internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
                internal const int TOKEN_QUERY = 0x00000008;
                internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
                internal const string SE_INCRASE_QUOTA = "SeIncreaseQuotaPrivilege";

                [DllImport("kernel32.dll",
                    EntryPoint = "CloseHandle", SetLastError = true,
                    CharSet = CharSet.Auto, CallingConvention = CallingConvention.StdCall)]
                public static extern bool CloseHandle(IntPtr handle);

                [DllImport("advapi32.dll",
                    EntryPoint = "CreateProcessAsUser", SetLastError = true,
                    CharSet = CharSet.Ansi, CallingConvention = CallingConvention.StdCall)]
                public static extern bool CreateProcessAsUser(
                    IntPtr hToken,
                    string lpApplicationName,
                    string lpCommandLine,
                    ref SECURITY_ATTRIBUTES lpProcessAttributes,
                    ref SECURITY_ATTRIBUTES lpThreadAttributes,
                    bool bInheritHandle,
                    Int32 dwCreationFlags,
                    IntPtr lpEnvrionment,
                    string lpCurrentDirectory,
                    ref STARTUPINFO lpStartupInfo,
                    ref PROCESS_INFORMATION lpProcessInformation
                    );

                [DllImport("advapi32.dll", EntryPoint = "DuplicateTokenEx")]
                public static extern bool DuplicateTokenEx(
                    IntPtr hExistingToken,
                    Int32 dwDesiredAccess,
                    ref SECURITY_ATTRIBUTES lpThreadAttributes,
                    Int32 ImpersonationLevel,
                    Int32 dwTokenType,
                    ref IntPtr phNewToken
                    );

                [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
                public static extern Boolean LogonUser(
                    String lpszUserName,
                    String lpszDomain,
                    String lpszPassword,
                    LogonType dwLogonType,
                    LogonProvider dwLogonProvider,
                    out IntPtr phToken
                    );

                [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
                internal static extern bool AdjustTokenPrivileges(
                    IntPtr htok,
                    bool disall,
                    ref TokPriv1Luid newst,
                    int len,
                    IntPtr prev,
                    IntPtr relen
                    );

                [DllImport("kernel32.dll", ExactSpelling = true)]
                internal static extern IntPtr GetCurrentProcess();

                [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
                internal static extern bool OpenProcessToken(
                    IntPtr h,
                    int acc,
                    ref IntPtr phtok
                    );

                [DllImport("kernel32.dll", ExactSpelling = true)]
                internal static extern int WaitForSingleObject(
                    IntPtr h,
                    int milliseconds
                    );

                [DllImport("kernel32.dll", ExactSpelling = true)]
                internal static extern bool GetExitCodeProcess(
                    IntPtr h,
                    out int exitcode
                    );

                [DllImport("advapi32.dll", SetLastError = true)]
                internal static extern bool LookupPrivilegeValue(
                    string host,
                    string name,
                    ref long pluid
                    );

                public static void CreateProcessAsUser(string strCommand, string strDomain, string strName, string strPassword, ref int ExitCode )
                {
                    var hToken = IntPtr.Zero;
                    var hDupedToken = IntPtr.Zero;
                    TokPriv1Luid tp;
                    var pi = new PROCESS_INFORMATION();
                    var sa = new SECURITY_ATTRIBUTES();
                    sa.Length = Marshal.SizeOf(sa);
                    Boolean bResult = false;
                    try
                    {
                        bResult = LogonUser(
                            strName,
                            strDomain,
                            strPassword,
                            LogonType.LOGON32_LOGON_BATCH,
                            LogonProvider.LOGON32_PROVIDER_DEFAULT,
                            out hToken
                            );
                        if (!bResult)
                        {
                            throw new Win32Exception("Logon error #" + Marshal.GetLastWin32Error().ToString());
                        }
                        IntPtr hproc = GetCurrentProcess();
                        IntPtr htok = IntPtr.Zero;
                        bResult = OpenProcessToken(
                                hproc,
                                TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY,
                                ref htok
                            );
                        if(!bResult)
                        {
                            throw new Win32Exception("Open process token error #" + Marshal.GetLastWin32Error().ToString());
                        }
                        tp.Count = 1;
                        tp.Luid = 0;
                        tp.Attr = SE_PRIVILEGE_ENABLED;
                        bResult = LookupPrivilegeValue(
                            null,
                            SE_INCRASE_QUOTA,
                            ref tp.Luid
                            );
                        if(!bResult)
                        {
                            throw new Win32Exception("Lookup privilege error #" + Marshal.GetLastWin32Error().ToString());
                        }
                        bResult = AdjustTokenPrivileges(
                            htok,
                            false,
                            ref tp,
                            0,
                            IntPtr.Zero,
                            IntPtr.Zero
                            );
                        if(!bResult)
                        {
                            throw new Win32Exception("Token elevation error #" + Marshal.GetLastWin32Error().ToString());
                        }

                        bResult = DuplicateTokenEx(
                            hToken,
                            GENERIC_ALL_ACCESS,
                            ref sa,
                            (int)SECURITY_IMPERSONATION_LEVEL.SecurityIdentification,
                            (int)TOKEN_TYPE.TokenPrimary,
                            ref hDupedToken
                            );
                        if(!bResult)
                        {
                            throw new Win32Exception("Duplicate Token error #" + Marshal.GetLastWin32Error().ToString());
                        }
                        var si = new STARTUPINFO();
                        si.cb = Marshal.SizeOf(si);
                        si.lpDesktop = "";
                        bResult = CreateProcessAsUser(
                            hDupedToken,
                            null,
                            strCommand,
                            ref sa,
                            ref sa,
                            false,
                            0,
                            IntPtr.Zero,
                            null,
                            ref si,
                            ref pi
                            );
                        if(!bResult)
                        {
                            throw new Win32Exception("Create process as user error #" + Marshal.GetLastWin32Error().ToString());
                        }

                        int status = WaitForSingleObject(pi.hProcess, -1);
                        if(status == -1)
                        {
                            throw new Win32Exception("Wait during create process failed user error #" + Marshal.GetLastWin32Error().ToString());
                        }

                        bResult = GetExitCodeProcess(pi.hProcess, out ExitCode);
                        if(!bResult)
                        {
                            throw new Win32Exception("Retrieving status error #" + Marshal.GetLastWin32Error().ToString());
                        }
                    }
                    finally
                    {
                        if (pi.hThread != IntPtr.Zero)
                        {
                            CloseHandle(pi.hThread);
                        }
                        if (pi.hProcess != IntPtr.Zero)
                        {
                            CloseHandle(pi.hProcess);
                        }
                        if (hDupedToken != IntPtr.Zero)
                        {
                            CloseHandle(hDupedToken);
                        }
                    }
                }
            }
        }
'@
    Add-Type -TypeDefinition $programSource -ReferencedAssemblies 'System.ServiceProcess'
}

Export-ModuleMember -Function *-TargetResource
