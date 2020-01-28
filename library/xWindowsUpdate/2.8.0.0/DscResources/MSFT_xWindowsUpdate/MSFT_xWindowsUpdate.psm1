Data LocalizedData
{
    # culture="en-US"e
    ConvertFrom-StringData @'
        GettingHotfixMessage=Getting the hotfix patch with ID {0}.
        ValidatingPathUri=Validating path/URI.
        ErrorPathUriSpecifiedTogether=Hotfix path and Uri parameters cannot be specified together.
        ErrorInvalidFilePathMsu=Filename provided is an invalid file path for hotfix since it does not have the msu suffix to it.
        StartKeyWord=START
        EndKeyWord= END
        FailedKeyword = FAILED
        ActionDownloadFromUri= Download from {0} using BitsTransfer.
        ActionInstallUsingwsusa = Install using wsusa.exe
        ActionUninstallUsingwsusa = Uninstall using wsusa.exe
        DownloadingPackageTo = Downloading package to filepath {0}
        FileDoesntExist=The given path {0} does not exist.
        LogNotSpecified=Log name hasn't been specified. Hotfix will use the temporary log {0} .
        ErrorOccuredOnHotfixInstall = \nCould not install the windows update. Details are stored in the log {0} . Error message is \n\n {1}  .\n\nPlease look at Windows Update error codes here for more information - http://technet.microsoft.com/en-us/library/dd939837(WS.10).aspx .
        ErrorOccuredOnHotfixUninnstall = \nCould not uninstall the windows update. Details are stored in the log {0} . Error message is \n\n {1}  .\n\nPlease look at Windows Update error codes here for more information - http://technet.microsoft.com/en-us/library/dd939837(WS.10).aspx .
        TestingEnsure = Testing whether hotfix is {0}.
        InvalidPath=The specified Path ({0}) is not in a valid format. Valid formats are local paths, UNC, and HTTP.
        InvalidBinaryType=The specified Path ({0}) does not appear to specify an MSU file and as such is not supported.
        TestStandardArgumentsPathWasPath = Test-StandardArguments, Path was {0}.
        NeedToDownloadFileFromSchemeDestinationWillBeDestName = Need to download file from {0}, destination will be {1}.
        TheUriSchemeWasUriScheme = The uri scheme was {0}.
        MountSharePath=Mount share to get media.
        NeedsMoreInfo=Id is required.
        InvalidIdFormat=Id must be formated either KBNNNNNNN or NNNNNNN.
        DownloadHTTPFile=Download the media over HTTP or HTTPS.
        CreatingCacheLocation = Creating cache location.
        CouldNotOpenDestFile=Cannot open the file {0} for writing.
        CreatingTheSchemeStream = Creating the {0} stream.
        SettingDefaultCredential = Setting default credential.
        SettingAuthenticationLevel = Setting authentication level.
        IgnoringBadCertificates = Ignoring bad certificates.
        GettingTheSchemeResponseStream = Getting the {0} response stream.
        ErrorOutString = Error: {0}.
        CopyingTheSchemeStreamBytesToTheDiskCache = Copying the {0} stream bytes to the disk cache.
        RedirectingPackagePathToCacheFileLocation = Redirecting package path to cache file location.
        ThePathExtensionWasPathExt = The path extension was {0}
        CreatingTheDestinationCacheFile = Creating the destination cache file.
'@
}

$CacheLocation = "$env:ProgramData\Microsoft\Windows\PowerShell\Configuration\BuiltinProvCache\MSFT_xWindowsUpdate"

# Get-TargetResource function  
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    Param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [parameter(Mandatory = $true)]
        [System.String]
        $Id
    )
    Set-StrictMode -Version latest

    $uri, $kbId = Test-StandardArguments -Path $Path -Id $Id

    Write-Verbose $($LocalizedData.GettingHotfixMessage -f ${Id})

    $hotfix = Get-HotFix -Id "KB$kbId"
    
    $returnValue = @{
        Path = ''
        Id = $hotfix.HotFixId
        Log = ''
    }

    $returnValue    

}

$Debug = $true
Function Trace-Message
{
    param([string] $Message)
    Set-StrictMode -Version latest
    if($Debug)
    {
        Write-Verbose $Message
    }
}

Function New-InvalidArgumentException
{
    param(
        [string] $Message,
        [string] $ParamName
    )
    Set-StrictMode -Version latest
    
    $exception = new-object System.ArgumentException $Message,$ParamName
    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception,$ParamName,'InvalidArgument',$null
    throw $errorRecord
}

# The Set-TargetResource cmdlet
function Set-TargetResource
{
    # should be [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "DSCMachineStatus")], but it doesn't work
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "")]   
    [CmdletBinding()]
    Param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [parameter(Mandatory = $true)]
        [System.String]
        $Id,

        [System.String]
        $Log,

        [ValidateSet('Present','Absent')]
        [System.String]
        $Ensure='Present',

        [pscredential] $Credential

    )
    Set-StrictMode -Version latest
    if (!$Log)
    {
        $Log = [IO.Path]::GetTempFileName()
        $Log += '.etl'

        Write-Verbose "$($LocalizedData.LogNotSpecified -f ${Log})"
    }
    $uri, $kbId = Test-StandardArguments -Path $Path -Id $Id

    
            
    if($Ensure -eq 'Present')
    {
        $filePath = Test-WindowsUpdatePath -uri $uri -Credential $Credential 
        Write-Verbose "$($LocalizedData.StartKeyWord) $($LocalizedData.ActionInstallUsingwsusa)"
    
        Start-Process -FilePath 'wusa.exe' -ArgumentList "`"$filepath`" /quiet /norestart /log:`"$Log`"" -Wait -NoNewWindow -ErrorAction SilentlyContinue
        $errorOccured = Get-WinEvent -Path $Log -Oldest | Where-Object {$_.Id -eq 3}                         
        if($errorOccured)
        {
            $errorMessage= $errorOccured.Message
            Throw "$($LocalizedData.ErrorOccuredOnHotfixInstall -f ${Log}, ${errorMessage})"
        }

        Write-Verbose "$($LocalizedData.EndKeyWord) $($LocalizedData.ActionInstallUsingwsusa)"
    }
    else
    {
        $argumentList = "/uninstall /KB:$kbId /quiet /norestart /log:`"$Log`""
        
        Write-Verbose "$($LocalizedData.StartKeyWord) $($LocalizedData.ActionUninstallUsingwsusa) Arguments: $ArgumentList"
    
        Start-Process -FilePath 'wusa.exe' -ArgumentList $argumentList  -Wait -NoNewWindow  -ErrorAction SilentlyContinue 
        #Read the log and see if there was an error event
        $errorOccured = Get-WinEvent -Path $Log -Oldest | Where-Object {$_.Id -eq 3}                         
        if($errorOccured)
        {
            $errorMessage= $errorOccured.Message
            Throw "$($LocalizedData.ErrorOccuredOnHotfixUninstall -f ${Log}, ${errorMessage})"
        }

        Write-Verbose "$($LocalizedData.EndKeyWord) $($LocalizedData.ActionUninstallUsingwsusa)"

        
    }
    
    if (Test-Path -Path 'variable:\LASTEXITCODE')
    {
        if ($LASTEXITCODE -eq 3010)
        {
            # reboot machine if exitcode indicates reboot.
            $global:DSCMachineStatus = 1        
        }
    }
}


# Function to test if Hotfix is installed.
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [parameter(Mandatory = $true)]
        [System.String]
        $Id,

        [System.String]
        $Log,

        [ValidateSet('Present','Absent')]
        [System.String]
        $Ensure='Present',

        [pscredential] $Credential
    )
    Set-StrictMode -Version latest
    Write-Verbose "$($LocalizedData.TestingEnsure -f ${Ensure})"
    $uri, $kbId = Test-StandardArguments -Path $Path -Id $Id
    
    # This is not the correct way to test to see if an update is applicable to a machine
    # but, WUSA does not currently expose a way to ask.
    $result = Get-HotFix -Id "KB$kbId" -ErrorAction SilentlyContinue
    $returnValue=  [bool]$result
    if($Ensure -eq 'Present')
    {

        Return $returnValue
    }
    else
    {
        Return !$returnValue
    }

}

Function Test-StandardArguments
{
    param(
        [string]
        $Path,

        [string]
        $Id
    )
    Set-StrictMode -Version latest
    
    Trace-Message ($LocalizedData.TestStandardArgumentsPathWasPath -f $Path)
    $uri = $null
    try
    {
        $uri = [uri] $Path
    }
    catch
    {
        New-InvalidArgumentException ($LocalizedData.InvalidPath -f $Path) 'Path'
    }
    
    if(-not @('file', 'http', 'https') -contains $uri.Scheme)
    {
        Trace-Message ($Localized.TheUriSchemeWasUriScheme -f $uri.Scheme)
        New-InvalidArgumentException ($LocalizedData.InvalidPath -f $Path) 'Path'
    }
    
    $pathExt = [System.IO.Path]::GetExtension($Path)
    Trace-Message ($LocalizedData.ThePathExtensionWasPathExt -f $pathExt)
    if(-not @('.msu') -contains $pathExt.ToLower())
    {
        New-InvalidArgumentException ($LocalizedData.InvalidBinaryType -f $Path) 'Path'
    }
    
    if(-not $Id)
    {
        New-InvalidArgumentException ($LocalizedData.NeedsMoreInfo -f $Path) 'Id'
    }
    else
    {
        if($Id -match 'kb[0-9]+')
        {
            if($Matches[0] -eq $id)
            {
                $kbId = $id.Substring(2)
            }
            else
            {
                New-InvalidArgumentException ($LocalizedData.InvalidIdFormat -f $Path) 'Id'
            }
        }
        elseif($id -match '[0-9]+')
        {
            if($Matches[0] -eq $id)
            {
                $kbId = $id
            }
            else
            {
                New-InvalidArgumentException ($LocalizedData.InvalidIdFormat -f $Path) 'Id'
            }
        }
    }
    
    return @($uri, $kbId)
}


function Test-WindowsUpdatePath
{
    <#
        .SYNOPSIS
        Validate path, if necessary, cache file and return the location to be accessed
    #>
    param(
            [parameter(Mandatory = $true)]
            [System.Uri] $uri,
            
            [pscredential] $Credential
    )
    Set-StrictMode -Version latest

    if($uri.IsUnc)
    {
        $psdriveArgs = @{Name=([guid]::NewGuid());PSProvider='FileSystem';Root=(Split-Path $uri.LocalPath)}
        if($Credential)
        {
            #We need to optionally include these and then splat the hash otherwise
            #we pass a null for Credential which causes the cmdlet to pop a dialog up
            $psdriveArgs['Credential'] = $Credential
        }
        
        $psdrive = New-PSDrive @psdriveArgs
        $Path = Join-Path $psdrive.Root (Split-Path -Leaf $uri.LocalPath) #Necessary?
    }
    elseif(@('http', 'https') -contains $uri.Scheme)
    {
        $scheme = $uri.Scheme
        $outStream = $null
        $responseStream = $null
        
        try
        {
            Trace-Message ($LocalizedData.CreatingCacheLocation)
            
            if(-not (Test-Path -PathType Container $CacheLocation))
            {
                mkdir $CacheLocation | Out-Null
            }
            
            $destName = Join-Path $CacheLocation (Split-Path -Leaf $uri.LocalPath)
            
            Trace-Message ($LocalizedData.NeedToDownloadFileFromSchemeDestinationWillBeDestName -f $scheme, $destName)
            
            try
            {
                Trace-Message ($LocalizedData.CreatingTheDestinationCacheFile)
                $outStream = New-Object System.IO.FileStream $destName, 'Create'
            }
            catch
            {
                #Should never happen since we own the cache directory
                Throw-TerminatingError ($LocalizedData.CouldNotOpenDestFile -f $destName) $_
            }
            
            try
            {
                Trace-Message ($LocalizedData.CreatingTheSchemeStream -f $scheme)
                $request = [System.Net.WebRequest]::Create($uri)
                Trace-Message ($LocalizedData.SettingDefaultCredential)
                $request.Credentials = [System.Net.CredentialCache]::DefaultCredentials
                if ($scheme -eq 'http')
                {
                    Trace-Message ($LocalizedData.SettingAuthenticationLevel)
                    # default value is MutualAuthRequested, which applies to https scheme
                    $request.AuthenticationLevel = [System.Net.Security.AuthenticationLevel]::None                            
                }
                if ($scheme -eq 'https')
                {
                    Trace-Message ($LocalizedData.IgnoringBadCertificates)
                    $request.ServerCertificateValidationCallBack = {$true}
                }
                Trace-Message ($LocalizedData.GettingTheSchemeResponseStream -f $scheme)
                $responseStream = (([System.Net.HttpWebRequest]$request).GetResponse()).GetResponseStream()
            }
            catch
            {
                Trace-Message ($LocalizedData.ErrorOutString -f ($_ | Out-String))
                Throw-TerminatingError ($LocalizedData.CouldNotGetHttpStream -f $scheme, $Path) $_
            }
            
            try
            {
                Trace-Message ($LocalizedData.CopyingTheSchemeStreamBytesToTheDiskCache -f $scheme)
                $responseStream.CopyTo($outStream)
                $responseStream.Flush()
                $outStream.Flush()
            }
            catch
            {
                Trace-Message ($LocalizedData.ErrorOutString -f ($_ | Out-String))
                Throw-TerminatingError ($LocalizedData.ErrorCopyingDataToFile -f $Path,$destName) $_
            }
        }
        finally
        {
            if($outStream)
            {
                $outStream.Close()
            }
            
            if($responseStream)
            {
                $responseStream.Close()
            }
        }
        Trace-Message ($LocalizedData.RedirectingPackagePathToCacheFileLocation)
        $Path = $downloadedFileName = $destName
    }
    return $Path
}

Export-ModuleMember -Function *-TargetResource



