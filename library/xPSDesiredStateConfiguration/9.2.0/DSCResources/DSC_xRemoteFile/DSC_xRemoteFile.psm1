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

# Path where cache will be stored. It's cleared whenever LCM gets new configuration.
$script:cacheLocation = "$env:ProgramData\Microsoft\Windows\PowerShell\Configuration\BuiltinProvCache\DSC_xRemoteFile"

<#
    .SYNOPSIS
        The Get-TargetResource function is used to fetch the status of file
        specified in DestinationPath on the target machine.

    .PARAMETER DestinationPath
        Path under which downloaded or copied file should be accessible after
        operation.

    .PARAMETER Uri
        Uri of a file which should be copied or downloaded. This parameter
        supports HTTP and HTTPS values.

    .PARAMETER ChecksumType
        The algorithm used to calculate the checksum of the file.
#>
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DestinationPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Uri,

        [Parameter()]
        [System.String]
        [ValidateSet('None', 'SHA1', 'SHA256', 'SHA384', 'SHA512', 'MACTripleDES', 'MD5', 'RIPEMD160')]
        $ChecksumType = 'None'

    )

    # Check whether DestinationPath is existing file
    $ensure = 'Absent'
    $pathItemType = Get-PathItemType -Path $DestinationPath
    $checksumValue = ''

    switch ($pathItemType)
    {
        'File'
        {
            Write-Verbose -Message ($script:localizedData.DestinationPathIsExistingFile -f $DestinationPath)
            $ensure = 'Present'

            if ($ChecksumType -ine 'None')
            {
                $getFileHash = Get-FileHash -Path $DestinationPath -Algorithm $ChecksumType
                $checksumValue = $getFileHash.Hash
            }
        }

        'Directory'
        {
            Write-Verbose -Message ($script:localizedData.DestinationPathIsExistingPath -f $DestinationPath)

            # If it's existing directory, let's check whether expectedDestinationPath exists
            $uriFileName = Split-Path -Path $Uri -Leaf
            $expectedDestinationPath = Join-Path -Path $DestinationPath -ChildPath $uriFileName

            if (Test-Path -Path $expectedDestinationPath)
            {
                Write-Verbose -Message ($script:localizedData.FileExistsInDestinationPath -f $uriFileName)
                $ensure = 'Present'

                if ($ChecksumType -ine 'None')
                {
                    $getFileHash = Get-FileHash -Path $expectedDestinationPath -Algorithm $ChecksumType
                    $checksumValue = $getFileHash.Hash
                }
            }
        }

        'Other'
        {
            Write-Verbose -Message ($script:localizedData.DestinationPathUnknownType -f $DestinationPath, $pathItemType)
        }

        'NotExists'
        {
            Write-Verbose -Message ($script:localizedData.DestinationPathDoesNotExist -f $DestinationPath)
        }
    }

    return @{
        DestinationPath = $DestinationPath
        Uri             = $Uri
        Ensure          = $ensure
        Checksum        = $checksumValue
    }
}

<#
    .SYNOPSIS
        The Set-TargetResource function is used to download file found under
        Uri location to DestinationPath. Additional parameters can be specified
        to configure web request.

    .PARAMETER DestinationPath
        Path under which downloaded or copied file should be accessible after
        operation.

    .PARAMETER Uri
        Uri of a file which should be copied or downloaded. This parameter
        supports HTTP and HTTPS values.

    .PARAMETER UserAgent
        User agent for the web request.

    .PARAMETER Headers
        Headers of the web request.

    .PARAMETER Credential
        Specifies a user account that has permission to send the request.

    .PARAMETER MatchSource
        A boolean value to indicate whether the remote file should be re-downloaded
        if the file in the DestinationPath was modified locally. The default value
        is true.

    .PARAMETER TimeoutSec
        Specifies how long the request can be pending before it times out.

    .PARAMETER Proxy
        Uses a proxy server for the request, rather than connecting directly
        to the Internet resource. Should be the URI of a network proxy server
        (e.g 'http://10.20.30.1').

    .PARAMETER ProxyCredential
        Specifies a user account that has permission to use the proxy server that
        is specified by the Proxy parameter.

    .PARAMETER Checksum
        Specifies the expected checksum value of downloaded file.

    .PARAMETER ChecksumType
        The algorithm used to calculate the checksum of the file.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DestinationPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Uri,

        [Parameter()]
        [System.String]
        $UserAgent,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Headers,

        [Parameter()]
        [System.Management.Automation.Credential()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.Boolean]
        $MatchSource = $true,

        [Parameter()]
        [System.Uint32]
        $TimeoutSec,

        [Parameter()]
        [System.String]
        $Proxy,

        [Parameter()]
        [System.Management.Automation.Credential()]
        [System.Management.Automation.PSCredential]
        $ProxyCredential,

        [Parameter()]
        [System.String]
        [ValidateSet('None', 'SHA1', 'SHA256', 'SHA384', 'SHA512', 'MACTripleDES', 'MD5', 'RIPEMD160')]
        $ChecksumType = 'None',

        [Parameter()]
        [System.String]
        $Checksum
    )

    # Validate Uri
    if (-not (Test-UriScheme -Uri $Uri -Scheme 'http|https|file'))
    {
        $errorMessage = $script:localizedData.InvalidWebUriError -f $Uri
        New-InvalidDataException `
            -ErrorId 'UriValidationFailure' `
            -ErrorMessage $errorMessage
    }

    # Validate DestinationPath scheme
    if (-not (Test-UriScheme -Uri $DestinationPath -Scheme 'file'))
    {
        $errorMessage = $script:localizedData.InvalidDestinationPathSchemeError -f $DestinationPath
        New-InvalidDataException `
            -ErrorId 'DestinationPathSchemeValidationFailure' `
            -ErrorMessage $errorMessage
    }

    # Validate DestinationPath is not UNC path
    if ($DestinationPath.StartsWith('\\'))
    {
        $errorMessage = $script:localizedData.DestinationPathIsUncError -f $DestinationPath
        New-InvalidDataException `
            -ErrorId 'DestinationPathIsUncFailure' `
            -ErrorMessage $errorMessage
    }

    # Validate DestinationPath does not contain invalid characters
    @('*', '?', '"', '<', '>', '|') | ForEach-Object -Process {
        if ($DestinationPath.Contains($_))
        {
            $errorMessage = $script:localizedData.DestinationPathHasInvalidCharactersError -f $DestinationPath
            New-InvalidDataException `
                -ErrorId 'DestinationPathHasInvalidCharactersError' `
                -ErrorMessage $errorMessage
        }
    }

    # Validate DestinationPath does not end with / or \ (Invoke-WebRequest requirement)
    if ($DestinationPath.EndsWith('/') -or $DestinationPath.EndsWith('\'))
    {
        $errorMessage = $script:localizedData.DestinationPathEndsWithInvalidCharacterError -f $DestinationPath
        New-InvalidDataException `
            -ErrorId 'DestinationPathEndsWithInvalidCharacterError' `
            -ErrorMessage $errorMessage
    }

    # Check whether DestinationPath's parent directory exists. Create if it doesn't.
    $destinationPathParent = Split-Path -Path $DestinationPath -Parent

    if (-not (Test-Path $destinationPathParent))
    {
        $null = New-Item -ItemType Directory -Path $destinationPathParent -Force
    }

    # Check whether DestinationPath's leaf is an existing folder
    $uriFileName = Split-Path -Path $Uri -Leaf

    if (Test-Path $DestinationPath -PathType Container)
    {
        $DestinationPath = Join-Path -Path $DestinationPath -ChildPath $uriFileName
    }

    # Remove ChecksumType and Checksum from parameters as they are not parameters of Invoke-WebRequest.
    $null = $PSBoundParameters.Remove('ChecksumType')
    $null = $PSBoundParameters.Remove('Checksum')

    # Remove DestinationPath and MatchSource from parameters as they are not parameters of Invoke-WebRequest
    $null = $PSBoundParameters.Remove('DestinationPath')
    $null = $PSBoundParameters.Remove('MatchSource')

    # Convert headers to hashtable
    $null = $PSBoundParameters.Remove('Headers')
    $headersHashtable = $null

    if ($null -ne $Headers)
    {
        $headersHashtable = Convert-KeyValuePairArrayToHashtable -Array $Headers
    }

    # Invoke web request
    try
    {
        $currentProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'

        Write-Verbose -Message ($script:localizedData.DownloadingURI -f $DestinationPath, $URI)
        $count = 0
        $success = $false

        do
        {
            try
            {
                $count++
                Invoke-WebRequest `
                    @PSBoundParameters `
                    -Headers $headersHashtable `
                    -OutFile $DestinationPath
                $success = $true
            }
            catch [System.Exception]
            {
                Write-Verbose -Message ($script:localizedData.DownloadingFailedRetry -f $URI, $count, $_.Exception.Message)

                if ($count -gt 5)
                {
                    # Inside catch variable $_ is not the exception itself, but a System.Management.Automation.ErrorRecord that contains the actual Exception
                    throw $_.Exception
                }

                Start-Sleep -Seconds 5
            }
        }
        while ($success -eq $false)
    }
    catch [System.OutOfMemoryException]
    {
        $errorMessage = $script:localizedData.DownloadOutOfMemoryException -f $_
        New-InvalidDataException `
            -ErrorId 'SystemOutOfMemoryException' `
            -ErrorMessage $errorMessage
    }
    catch [System.Exception]
    {
        $errorMessage = $script:localizedData.DownloadException -f $_
        New-InvalidDataException `
            -ErrorId 'SystemException' `
            -ErrorMessage $errorMessage
    }
    finally
    {
        $ProgressPreference = $currentProgressPreference
    }

    # Check checksum
    if ($ChecksumType -ine 'None' -and -not [String]::IsNullOrEmpty($Checksum))
    {
        $fileHashSplat = @{
            Path      = $DestinationPath
            Algorithm = $ChecksumType
        }

        $getFileHash = Get-FileHash @fileHashSplat
        $fileHash = $getFileHash.Hash

        if ($fileHash -ine $Checksum)
        {
            # the checksum failed
            $errorMessage = $script:localizedData.ChecksumDoesNotMatch -f $Checksum, $fileHash
            New-InvalidDataException `
                -ErrorId 'ChecksumDoesNotMatch' `
                -ErrorMessage $errorMessage
        }
    }

    # Update cache
    if (Test-Path -Path $DestinationPath)
    {
        $downloadedFile = Get-Item -Path $DestinationPath
        $lastWriteTime = $downloadedFile.LastWriteTimeUtc
        $filesize = $downloadedFile.Length
        $inputObject = @{ }
        $inputObject['LastWriteTime'] = $lastWriteTime
        $inputObject['FileSize'] = $filesize
        Update-Cache -DestinationPath $DestinationPath -Uri $Uri -InputObject $inputObject
    }
}

<#
    .SYNOPSIS
        The Test-TargetResource function is used to validate if the DestinationPath
        exists on the machine.

    .PARAMETER DestinationPath
        Path under which downloaded or copied file should be accessible after
        operation.

    .PARAMETER Uri
        Uri of a file which should be copied or downloaded. This parameter
        supports HTTP and HTTPS values.

    .PARAMETER UserAgent
        User agent for the web request.

    .PARAMETER Headers
        Headers of the web request.

    .PARAMETER Credential
        Specifies a user account that has permission to send the request.

    .PARAMETER MatchSource
        A boolean value to indicate whether the remote file should be re-downloaded
        if the file in the DestinationPath was modified locally. The default value
        is true.

    .PARAMETER TimeoutSec
        Specifies how long the request can be pending before it times out.

    .PARAMETER Proxy
        Uses a proxy server for the request, rather than connecting directly
        to the Internet resource. Should be the URI of a network proxy server
        (e.g 'http://10.20.30.1').

    .PARAMETER ProxyCredential
        Specifies a user account that has permission to use the proxy server that
        is specified by the Proxy parameter.

    .PARAMETER Checksum
        Specifies the expected checksum value of downloaded file.

    .PARAMETER ChecksumType
        The algorithm used to calculate the checksum of the file.
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DestinationPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Uri,

        [Parameter()]
        [System.String]
        $UserAgent,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Headers,

        [Parameter()]
        [System.Management.Automation.Credential()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.Boolean]
        $MatchSource = $true,

        [Parameter()]
        [System.Uint32]
        $TimeoutSec,

        [Parameter()]
        [System.String]
        $Proxy,

        [Parameter()]
        [System.Management.Automation.Credential()]
        [System.Management.Automation.PSCredential]
        $ProxyCredential,

        [Parameter()]
        [System.String]
        [ValidateSet('None', 'SHA1', 'SHA256', 'SHA384', 'SHA512', 'MACTripleDES', 'MD5', 'RIPEMD160')]
        $ChecksumType = 'None',

        [Parameter()]
        [System.String]
        $Checksum
    )

    # Check whether DestinationPath points to existing file or directory
    $fileExists = $false
    $uriFileName = Split-Path -Path $Uri -Leaf
    $pathItemType = Get-PathItemType -Path $DestinationPath

    switch ($pathItemType)
    {
        'File'
        {
            Write-Verbose -Message ($script:localizedData.DestinationPathIsExistingFile -f $DestinationPath)

            if ($MatchSource)
            {
                $file = Get-Item -Path $DestinationPath
                # Getting cache. It's cleared every time user runs Start-DscConfiguration
                $cache = Get-Cache -DestinationPath $DestinationPath -Uri $Uri

                if ($null -ne $cache `
                        -and ($cache.LastWriteTime -eq $file.LastWriteTimeUtc) `
                        -and ($cache.FileSize -eq $file.Length))
                {
                    Write-Verbose -Message $script:localizedData.CacheReflectsCurrentState
                    $fileExists = $true
                }
                else
                {
                    Write-Verbose -Message $script:localizedData.CacheIsEmptyOrNotMatchCurrentState
                }
            }
            else
            {
                Write-Verbose -Message $script:localizedData.MatchSourceFalse
                $fileExists = $true
            }

            if ($ChecksumType -ine 'None' `
                    -and -not [String]::IsNullOrEmpty($Checksum) `
                    -and $fileExists -eq $true)
            {
                $fileHashSplat = @{
                    Path      = $DestinationPath
                    Algorithm = $ChecksumType
                }
                $getFileHash = Get-FileHash @fileHashSplat
                $fileHash = $getFileHash.Hash

                if ($fileHash -ieq $Checksum)
                {
                    $fileExists = $true
                }
                else
                {
                    # The checksum does not match. The file may match what is in the cached data. Resetting it to false.
                    $fileExists = $false
                }
            }
        }

        'Directory'
        {
            Write-Verbose -Message ($script:localizedData.DestinationPathIsExistingPath -f $DestinationPath)

            $expectedDestinationPath = Join-Path -Path $DestinationPath -ChildPath $uriFileName

            if (Test-Path -Path $expectedDestinationPath)
            {
                if ($MatchSource)
                {
                    $file = Get-Item -Path $expectedDestinationPath
                    $cache = Get-Cache -DestinationPath $expectedDestinationPath -Uri $Uri

                    if ($null -ne $cache -and ($cache.LastWriteTime -eq $file.LastWriteTimeUtc))
                    {
                        Write-Verbose -Message $script:localizedData.CacheReflectsCurrentState
                        $fileExists = $true
                    }
                    else
                    {
                        Write-Verbose -Message $script:localizedData.CacheIsEmptyOrNotMatchCurrentState
                    }
                }
                else
                {
                    Write-Verbose -Message $script:localizedData.MatchSourceFalse
                    $fileExists = $true
                }

                if ($ChecksumType -ine 'None' `
                    -and -not [String]::IsNullOrEmpty($Checksum) `
                    -and $fileExists -eq $true)
            {
                $fileHashSplat = @{
                    Path      = $expectedDestinationPath
                    Algorithm = $ChecksumType
                }
                $getFileHash = Get-FileHash @fileHashSplat
                $fileHash = $getFileHash.Hash

                if ($fileHash -ieq $Checksum)
                {
                    $fileExists = $true
                }
                else
                {
                    # The checksum does not match. The file may match what is in the cached data. Resetting it to false.
                    $fileExists = $false
                }
            }
            }
        }

        'Other'
        {
            Write-Verbose -Message ($script:localizedData.DestinationPathUnknownType -f $DestinationPath, $pathItemType)
        }

        'NotExists'
        {
            Write-Verbose -Message ($script:localizedData.DestinationPathDoesNotExist -f $DestinationPath)
        }
    }

    $result = $fileExists

    return $result
}

<#
    .SYNOPSIS
        Checks whether given URI represents specific scheme.

    .DESCRIPTION
        Most common schemes: file, http, https, ftp
        We can also specify logical expressions like: [http|https]

    .PARAMETER Uri
        The path of the item to test the scheme of.

    .PARAMETER Scheme
        The type of scheme to test the item is.
#>
function Test-UriScheme
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Uri,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Scheme
    )

    $newUri = $Uri -as [System.URI]

    return ($null -ne $newUri.AbsoluteURI -and $newUri.Scheme -match $Scheme)
}

<#
    .SYNOPSIS
        Gets type of the item which path points to.

    .PARAMETER Path
        The path of the item to return the item type of.

    .OUTPUTS
        File, Directory, Other or NotExists.
#>
function Get-PathItemType
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path
    )

    $type = $null

    # Check whether path exists
    if (Test-Path -Path $path)
    {
        # Check type of the path
        $pathItem = Get-Item -Path $Path
        $pathItemType = $pathItem.GetType().Name

        if ($pathItemType -eq 'FileInfo')
        {
            $type = 'File'
        }
        elseif ($pathItemType -eq 'DirectoryInfo')
        {
            $type = 'Directory'
        }
        else
        {
            $type = 'Other'
        }
    }
    else
    {
        $type = 'NotExists'
    }

    return $type
}

<#
    .SYNOPSIS
        Converts CimInstance array of type KeyValuePair to hashtable

    .PARAMETER Array
        The array of KeyValuePairs to convert to a hashtable.
#>
function Convert-KeyValuePairArrayToHashtable
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Array
    )

    $hashtable = @{ }

    foreach ($item in $Array)
    {
        $hashtable += @{
            $item.Key = $item.Value
        }
    }

    return $hashtable
}

<#
    .SYNOPSIS
        Gets cache for specific DestinationPath and Uri.

    .PARAMETER DestinationPath
        The path to the cache.

    .PARAMETER Uri
        The URI of the file to get the cache content for.
#>
function Get-Cache
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DestinationPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Uri
    )

    $cacheContent = $null
    $key = Get-CacheKey -DestinationPath $DestinationPath -Uri $Uri
    $path = Join-Path -Path $script:cacheLocation -ChildPath $key

    Write-Verbose -Message ($script:localizedData.CacheLookingForPath -f $Path)

    if (-not (Test-Path -Path $path))
    {
        Write-Verbose -Message ($script:localizedData.CacheNotFoundForPath -f $DestinationPath, $Uri, $Key)

        $cacheContent = $null
    }
    else
    {
        $cacheContent = Import-Clixml -Path $path
        Write-Verbose -Message ($script:localizedData.CacheFoundForPath -f $DestinationPath, $Uri, $Key)
    }

    return $cacheContent
}

<#
    .SYNOPSIS
        Creates or updates cache for specific DestinationPath and Uri.

    .PARAMETER DestinationPath
        The path to the cache.

    .PARAMETER Uri
        The URI of the file to update the cache for.

    .PARAMETER Uri
        The content of the file to update in the cache.
#>
function Update-Cache
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DestinationPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Uri,

        [Parameter(Mandatory = $true)]
        [System.Object]
        $InputObject
    )

    $key = Get-CacheKey -DestinationPath $DestinationPath -Uri $Uri
    $path = Join-Path -Path $script:cacheLocation -ChildPath $key

    if (-not (Test-Path -Path $script:cacheLocation))
    {
        $null = New-Item -ItemType Directory -Path $script:cacheLocation
    }

    Write-Verbose -Message ($script:localizedData.UpdatingCache -f $DestinationPath, $Uri, $Key)

    Export-Clixml -Path $path -InputObject $InputObject -Force
}

<#
    .SYNOPSIS
        Returns cache key for given parameters.

    .PARAMETER DestinationPath
        The path to the cache.

    .PARAMETER Uri
        The URI of the file to get the cache key for.
#>
function Get-CacheKey
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DestinationPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Uri
    )

    return [System.String]::Join('', @($DestinationPath, $Uri)).GetHashCode().ToString()
}

Export-ModuleMember -Function Get-TargetResource, Set-TargetResource, Test-TargetResource
