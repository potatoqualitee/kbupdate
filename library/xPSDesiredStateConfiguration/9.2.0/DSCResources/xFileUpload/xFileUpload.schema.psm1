$errorActionPreference = 'Stop'
Set-StrictMode -Version 'Latest'

$modulePath = Join-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -ChildPath 'Modules'

# Import the shared modules
Import-Module -Name (Join-Path -Path $modulePath `
    -ChildPath (Join-Path -Path 'xPSDesiredStateConfiguration.Common' `
        -ChildPath 'xPSDesiredStateConfiguration.Common.psm1'))

Import-Module -Name (Join-Path -Path $modulePath -ChildPath 'DscResource.Common')
<#
    .SYNOPSIS
        DSC Composite Resource uploads file or folder to an SMB share.

    .DESCRIPTION
        This is a DSC Composite resource that can be used to upload
        a file or folder into an SMB file share. The SMB file share
        does not have to be currently mounted. It will be mounted
        during the upload process using the optional Credential
        and then dismounted after completion of the upload.

    .PARAMETER DestinationPath
        The destination SMB share path to upload the file or folder to.

    .PARAMETER SourcePath
        The source path of the file or folder to upload.

    .PARAMETER Credential
        Credentials to access the destination SMB share path where file
        or folder should be uploaded.

    .PARAMETER certificateThumbprint
        Thumbprint of the certificate which should be used for encryption/decryption.

    .EXAMPLE
        $securePassword = ConvertTo-SecureString -String 'password' -AsPlainText -Force
        $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'domain\user', $securePassword
        xFileUpload `
            -DestinationPath '\\machine\share\destinationfolder' `
            -SourcePath 'C:\folder\file.txt' `
            -Credential $credential
#>
configuration xFileUpload
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-Keyword', '', Justification = 'Script resource name is seen as a keyword if this is not used.')]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DestinationPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $SourcePath,

        [Parameter()]
        [System.Management.Automation.Credential()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.String]
        $CertificateThumbprint
    )

    $cacheLocation = "$env:ProgramData\Microsoft\Windows\PowerShell\configuration\BuiltinProvCache\DSC_xFileUpload"

    if ($Credential)
    {
        $username = $Credential.UserName

        # Encrypt password
        $password = Invoke-Command `
            -ScriptBlock $getEncryptedPassword `
            -ArgumentList $Credential, $CertificateThumbprint
    }

    Script FileUpload
    {
        # Get script is not implemented cause reusing Script resource's schema does not make sense
        GetScript  = {
            return @{}
        };

        SetScript  = {
            # Generating credential object if password and username are specified
            $Credential = $null

            if (($using:password) -and ($using:username))
            {
                # Validate that certificate thumbprint is specified
                if (-not $using:CertificateThumbprint)
                {
                    $errorMessage = 'Certificate thumbprint has to be specified if credentials are present.'
                    Invoke-Command `
                        -ScriptBlock $using:throwTerminatingError `
                        -ArgumentList 'CertificateThumbprintIsRequired', $errorMessage, 'InvalidData'
                }

                Write-Debug -Message 'Username and password specified.'

                # Decrypt password
                $decryptedPassword = Invoke-Command `
                    -ScriptBlock $using:getDecryptedPassword `
                    -ArgumentList $using:password, $using:CertificateThumbprint

                # Generate credential
                $securePassword = ConvertTo-SecureString -String $decryptedPassword -AsPlainText -Force
                $Credential = New-Object `
                    -TypeName System.Management.Automation.PSCredential `
                    -ArgumentList ($using:username, $securePassword)
            }

            # Validate DestinationPath is UNC path
            if (-not ($using:DestinationPath -as [System.Uri]).isUnc)
            {
                $errorMessage = "Destination path $using:DestinationPath is not a valid UNC path."
                Invoke-Command `
                    -ScriptBlock $using:throwTerminatingError `
                    -ArgumentList 'DestinationPathIsNotUNCFailure', $errorMessage, 'InvalidData'
            }

            # Verify source is localpath
            if (-not (($using:SourcePath -as [System.Uri]).Scheme -match 'file'))
            {
                $errorMessage = "Source path $using:SourcePath has to be local path."
                Invoke-Command `
                    -ScriptBlock $using:throwTerminatingError `
                    -ArgumentList 'SourcePathIsNotLocalFailure', $errorMessage, 'InvalidData'
            }

            # Check whether source path is existing file or directory
            $sourcePathType = $null

            if (-not (Test-Path -Path $using:SourcePath))
            {
                $errorMessage = "Source path $using:SourcePath does not exist."
                Invoke-Command `
                    -ScriptBlock $using:throwTerminatingError `
                    -ArgumentList 'SourcePathDoesNotExistFailure', $errorMessage, 'InvalidData'
            }
            else
            {
                $item = Get-Item -Path $using:SourcePath

                switch ($item.GetType().Name)
                {
                    'FileInfo'
                    {
                        $sourcePathType = 'File'
                    }

                    'DirectoryInfo'
                    {
                        $sourcePathType = 'Directory'
                    }
                }
            }

            Write-Debug -Message "SourcePath $using:SourcePath is of type: $sourcePathType"

            $psDrive = $null

            # Mount the drive only if Credentials are specified and it's currently not accessible
            if ($Credential)
            {
                if (Test-Path -Path $using:DestinationPath -ErrorAction Ignore)
                {
                    Write-Debug -Message "Destination path $using:DestinationPath is already accessible. No mount needed."
                }
                else
                {
                    $psDriveArgs = @{
                        Name       = ([System.Guid]::NewGuid())
                        PSProvider = 'FileSystem'
                        Root       = $using:DestinationPath
                        Scope      = 'Private'
                        Credential = $Credential
                    }

                    try
                    {
                        Write-Debug -Message "Create psdrive with destination path $using:DestinationPath..."
                        $psDrive = New-PSDrive @psDriveArgs -ErrorAction Stop
                    }
                    catch
                    {
                        $errorMessage = "Cannot access destination path $using:DestinationPath with given Credential"
                        Invoke-Command `
                            -ScriptBlock $using:throwTerminatingError `
                            -ArgumentList 'DestinationPathNotAccessibleFailure', $errorMessage, 'InvalidData'
                    }
                }
            }

            try
            {
                # Get expected destination path
                $expectedDestinationPath = $null

                if (-not (Test-Path -Path $using:DestinationPath))
                {
                    # DestinationPath has to exist
                    $errorMessage = 'Invalid parameter values: DestinationPath does not exist, but has to be existing directory.'
                    Throw-TerminatingError -ErrorMessage $errorMessage -ErrorCategory 'InvalidData' -ErrorId 'DestinationPathDoesNotExistFailure'
                }
                else
                {
                    $item = Get-Item -Path $using:DestinationPath

                    switch ($item.GetType().Name)
                    {
                        'FileInfo'
                        {
                            # DestinationPath cannot be file
                            $errorMessage = 'Invalid parameter values: DestinationPath is file, but has to be existing directory.'
                            Invoke-Command `
                                -ScriptBlock $using:throwTerminatingError `
                                -ArgumentList 'DestinationPathCannotBeFileFailure', $errorMessage, 'InvalidData'
                        }

                        'DirectoryInfo'
                        {
                            $expectedDestinationPath = Join-Path `
                                -Path $using:DestinationPath `
                                -ChildPath (Split-Path -Path $using:SourcePath -Leaf)
                        }
                    }

                    Write-Debug -Message "ExpectedDestinationPath is $expectedDestinationPath"
                }

                # Copy destination path
                try
                {
                    Write-Debug -Message "Copying $using:SourcePath to $using:DestinationPath"
                    Copy-Item -Path $using:SourcePath -Destination $using:DestinationPath -Recurse -Force -ErrorAction Stop
                }
                catch
                {
                    $errorMessage = "Could not copy source path $using:SourcePath to $using:DestinationPath : $($_.Exception)"
                    Invoke-Command `
                        -ScriptBlock $using:throwTerminatingError `
                        -ArgumentList 'CopyDirectoryOverFileFailure', $errorMessage, 'InvalidData'
                }

                # Verify whether expectedDestinationPath was created
                if (-not (Test-Path -Path $expectedDestinationPath))
                {
                    $errorMessage = "Destination path $using:DestinationPath could not be created"
                    Invoke-Command `
                        -ScriptBlock $using:throwTerminatingError `
                        -ArgumentList 'DestinationPathNotCreatedFailure', $errorMessage, 'InvalidData'
                }
                # If expectedDestinationPath exists
                else
                {
                    Write-Verbose -Message "$sourcePathType $expectedDestinationPath has been successfully created"

                    # Update cache
                    $uploadedItem = Get-Item -Path $expectedDestinationPath
                    $lastWriteTime = $uploadedItem.LastWriteTimeUtc
                    $inputObject = @{}
                    $inputObject['LastWriteTimeUtc'] = $lastWriteTime
                    $key = [System.String]::Join('', @($using:DestinationPath, $using:SourcePath, $expectedDestinationPath)).GetHashCode().ToString()
                    $path = Join-Path $using:cacheLocation $key

                    if (-not (Test-Path -Path $using:cacheLocation))
                    {
                        New-Item -Path $using:cacheLocation -ItemType Directory | Out-Null
                    }

                    Write-Debug -Message "Updating cache for DestinationPath = $using:DestinationPath and SourcePath = $using:SourcePath. CacheKey = $key"
                    Export-CliXml -Path $path -InputObject $inputObject -Force
                }
            }
            finally
            {
                # Remove PSDrive
                if ($psDrive)
                {
                    Write-Debug -Message "Removing PSDrive on root $($psDrive.Root)"
                    Remove-PSDrive -Name $psDrive -Force
                }
            }
        };

        TestScript = {
            # Generating credential object if password and username are specified
            $Credential = $null

            if (($using:password) -and ($using:username))
            {
                # Validate that certificate thumbprint is specified
                if (-not $using:CertificateThumbprint)
                {
                    $errorMessage = 'Certificate thumbprint has to be specified if credentials are present.'
                    Invoke-Command `
                        -ScriptBlock $using:throwTerminatingError `
                        -ArgumentList 'CertificateThumbprintIsRequired', $errorMessage, 'InvalidData'
                }

                Write-Debug -Message 'Username and password specified. Generating credential'

                # Decrypt password
                $decryptedPassword = Invoke-Command `
                    -ScriptBlock $using:getDecryptedPassword `
                    -ArgumentList $using:password, $using:CertificateThumbprint

                # Generate credential
                $securePassword = ConvertTo-SecureString -String $decryptedPassword -AsPlainText -Force
                $Credential = New-Object `
                    -TypeName System.Management.Automation.PSCredential `
                    -ArgumentList ($using:username, $securePassword)
            }
            else
            {
                Write-Debug -Message 'No credentials specified.'
            }

            # Validate DestinationPath is UNC path
            if (-not ($using:DestinationPath -as [System.Uri]).isUnc)
            {
                $errorMessage = "Destination path $using:DestinationPath is not a valid UNC path."
                Invoke-Command `
                    -ScriptBlock $using:throwTerminatingError `
                    -ArgumentList 'DestinationPathIsNotUNCFailure', $errorMessage, 'InvalidData'

            }

            # Check whether source path is existing file or directory (needed for expectedDestinationPath)
            $sourcePathType = $null
            if (-not (Test-Path -Path $using:SourcePath))
            {
                $errorMessage = "Source path $using:SourcePath does not exist."
                Invoke-Command `
                    -ScriptBlock $using:throwTerminatingError `
                    -ArgumentList 'SourcePathDoesNotExistFailure', $errorMessage, 'InvalidData'
            }
            else
            {
                $item = Get-Item -Path $using:SourcePath

                switch ($item.GetType().Name)
                {
                    'FileInfo'
                    {
                        $sourcePathType = 'File'
                    }

                    'DirectoryInfo'
                    {
                        $sourcePathType = 'Directory'
                    }
                }
            }

            Write-Debug -Message "SourcePath $using:SourcePath is of type: $sourcePathType"

            $psDrive = $null

            # Mount the drive only if credentials are specified and it's currently not accessible
            if ($Credential)
            {
                if (Test-Path -Path $using:DestinationPath -ErrorAction Ignore)
                {
                    Write-Debug -Message "Destination path $using:DestinationPath is already accessible. No mount needed."
                }
                else
                {
                    $psDriveArgs = @{
                        Name       = ([System.Guid]::NewGuid())
                        PSProvider = 'FileSystem'
                        Root       = $using:DestinationPath
                        Scope      = 'Private'
                        Credential = $Credential

                    }
                    try
                    {
                        Write-Debug -Message "Create psdrive with destination path $using:DestinationPath..."
                        $psDrive = New-PSDrive @psDriveArgs -ErrorAction Stop
                    }
                    catch
                    {
                        $errorMessage = "Cannot access destination path $using:DestinationPath with given Credential"
                        Invoke-Command `
                            -ScriptBlock $using:throwTerminatingError `
                            -ArgumentList 'DestinationPathNotAccessibleFailure', $errorMessage, 'InvalidData'
                    }
                }
            }

            try
            {
                # Get expected destination path
                $expectedDestinationPath = $null

                if (-not (Test-Path -Path $using:DestinationPath))
                {
                    # DestinationPath has to exist
                    $errorMessage = 'Invalid parameter values: DestinationPath does not exist or is not accessible. DestinationPath has to be existing directory.'
                    Invoke-Command `
                        -ScriptBlock $using:throwTerminatingError `
                        -ArgumentList 'DestinationPathDoesNotExistFailure', $errorMessage, 'InvalidData'
                }
                else
                {
                    $item = Get-Item -Path $using:DestinationPath

                    switch ($item.GetType().Name)
                    {
                        'FileInfo'
                        {
                            # DestinationPath cannot be file
                            $errorMessage = 'Invalid parameter values: DestinationPath is file, but has to be existing directory.'
                            Invoke-Command `
                                -ScriptBlock $using:throwTerminatingError `
                                -ArgumentList 'DestinationPathCannotBeFileFailure', $errorMessage, 'InvalidData'
                        }

                        'DirectoryInfo'
                        {
                            $expectedDestinationPath = Join-Path `
                                -Path $using:DestinationPath `
                                -ChildPath (Split-Path -Path $using:SourcePath -Leaf)
                        }
                    }

                    Write-Debug -Message "ExpectedDestinationPath is $expectedDestinationPath"
                }

                # Check whether ExpectedDestinationPath exists and has expected type
                $itemExists = $false

                if (-not (Test-Path $expectedDestinationPath))
                {
                    Write-Debug -Message 'Expected destination path does not exist or is not accessible.'
                }
                # If expectedDestinationPath exists
                else
                {
                    $expectedItem = Get-Item -Path $expectedDestinationPath
                    $expectedItemType = $expectedItem.GetType().Name

                    # If expectedDestinationPath has same type as sourcePathType, we need to verify cache to determine whether no upload is needed
                    if ((($expectedItemType -eq 'FileInfo') -and ($sourcePathType -eq 'File')) -or `
                        (($expectedItemType -eq 'DirectoryInfo') -and ($sourcePathType -eq 'Directory')))
                    {
                        # Get cache
                        Write-Debug -Message "Getting cache for $expectedDestinationPath"
                        $cacheContent = $null
                        $key = [System.String]::Join('', @($using:DestinationPath, $using:SourcePath, $expectedDestinationPath)).GetHashCode().ToString()
                        $path = Join-Path -Path $using:cacheLocation -ChildPath $key
                        Write-Debug -Message "Looking for cache under $path"

                        if (-not (Test-Path -Path $path))
                        {
                            Write-Debug -Message "No cache found for DestinationPath = $using:DestinationPath and SourcePath = $using:SourcePath. CacheKey = $key"
                        }
                        else
                        {
                            $cacheContent = Import-CliXml -Path $path
                            Write-Debug -Message "Found cache for DestinationPath = $using:DestinationPath and SourcePath = $using:SourcePath. CacheKey = $key"
                        }

                        # Verify whether cache reflects current state or upload is needed
                        if ($cacheContent -ne $null -and ($cacheContent.LastWriteTimeUtc -eq $expectedItem.LastWriteTimeUtc))
                        {
                            # No upload needed
                            Write-Debug -Message 'Cache reflects current state. No need for upload.'
                            $itemExists = $true
                        }
                        else
                        {
                            Write-Debug -Message 'Cache is empty or it does not reflect current state. Upload will be performed.'
                        }
                    }
                    else
                    {
                        Write-Debug -Message "Expected destination path: $expectedDestinationPath is of type $expectedItemType, although source path is $sourcePathType"
                    }
                }
            }
            finally
            {
                # Remove PSDrive
                if ($psDrive)
                {
                    Write-Debug -Message "Removing PSDrive on root $($psDrive.Root)"
                    Remove-PSDrive -Name $psDrive -Force
                }
            }

            return $itemExists
        };
    }
}

# Encrypts password using the defined public key
[System.Management.Automation.ScriptBlock] $getEncryptedPassword = {
    param
    (
        [Parameter(Mandatory = $true)]
        [PSCredential]
        $Credential,

        [Parameter(Mandatory = $true)]
        [System.String]
        $CertificateThumbprint
    )

    $value = $Credential.GetNetworkCredential().Password

    $cert = Invoke-Command `
        -ScriptBlock $getCertificate `
        -ArgumentList $CertificateThumbprint

    $encryptedPassword = $null

    if ($cert)
    {
        # Cast the public key correctly
        $rsaProvider = [System.Security.Cryptography.RSACryptoServiceProvider] $cert.PublicKey.Key

        if ($rsaProvider -eq $null)
        {
            $errorMessage = "Could not get public key from certificate with thumbprint: $CertificateThumbprint . Please verify certificate is valid for encryption."
            Invoke-Command `
                -ScriptBlock $throwTerminatingError `
                -ArgumentList "DecryptionCertificateNotFound", $errorMessage, "InvalidOperation"
        }

        # Convert to a byte array
        $keybytes = [System.Text.Encoding]::UNICODE.GetBytes($value)

        # Add a null terminator to the byte array
        $keybytes += 0
        $keybytes += 0

        # Encrypt using the public key
        $encbytes = $rsaProvider.Encrypt($keybytes, $false)

        # Return a string
        $encryptedPassword = [Convert]::ToBase64String($encbytes)
    }
    else
    {
        $errorMessage = "Could not find certificate which matches thumbprint: $CertificateThumbprint . Could not encrypt password"
        Invoke-Command `
            -ScriptBlock $throwTerminatingError `
            -ArgumentList "EncryptionCertificateNot", $errorMessage, "InvalidOperation"
    }

    return $encryptedPassword
}

# Retrieves certificate by thumbprint
[System.Management.Automation.ScriptBlock] $getCertificate = {
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $CertificateThumbprint
    )

    $cert = $null

    foreach ($certIndex in (Get-Childitem -Path Cert:\LocalMachine\My))
    {
        if ($certIndex.Thumbprint -match $CertificateThumbprint)
        {
            $cert = $certIndex
            break
        }
    }

    if (-not $cert)
    {
        $errorMessage = "Error Reading certificate store for {0}. Please verify thumbprint is correct and certificate belongs to cert:\LocalMachine\My store." -f ${CertificateThumbprint};
        Invoke-Command `
            -ScriptBlock $throwTerminatingError `
            -ArgumentList "InvalidPathSpecified", $errorMessage, "InvalidOperation"
    }
    else
    {
        $cert
    }
}

# Throws terminating error specified errorCategory, errorId and errorMessage
[System.Management.Automation.ScriptBlock] $throwTerminatingError = {
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ErrorId,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ErrorMessage,

        [Parameter(Mandatory = $true)]
        $ErrorCategory
    )

    $exception = New-Object -TypeName System.InvalidOperationException -ArgumentList $ErrorMessage
    $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList ($exception, $ErrorId, $ErrorCategory, $null)
    throw $errorRecord
}

# Decrypts password using the defined private key
[System.Management.Automation.ScriptBlock] $getDecryptedPassword = {
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Value,

        [Parameter(Mandatory = $true)]
        [System.String]
        $CertificateThumbprint
    )

    $cert = $null

    foreach ($certIndex in (Get-Childitem -Path Cert:\LocalMachine\My))
    {
        if ($certIndex.Thumbprint -match $CertificateThumbprint)
        {
            $cert = $certIndex
            break
        }
    }

    if (-not $cert)
    {
        $errorMessage = "Error Reading certificate store for {0}. Please verify thumbprint is correct and certificate belongs to cert:\LocalMachine\My store." -f ${CertificateThumbprint};
        $exception = New-Object -TypeName System.InvalidOperationException -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList ($exception, "InvalidPathSpecified", "InvalidOperation", $null)
        throw $errorRecord
    }

    $decryptedPassword = $null

    # Get RSA provider
    $rsaProvider = [System.Security.Cryptography.RSACryptoServiceProvider] $cert.PrivateKey

    if ($rsaProvider -eq $null)
    {
        $errorMessage = "Could not get private key from certificate with thumbprint: $CertificateThumbprint . Please verify certificate is valid for decryption."
        $exception = New-Object -TypeName System.InvalidOperationException -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList ($exception, "DecryptionCertificateNotFound", "InvalidOperation", $null)
        throw $errorRecord
    }

    # Convert to bytes array
    $encBytes = [Convert]::FromBase64String($value)

    # Decrypt bytes
    $decryptedBytes = $rsaProvider.Decrypt($encBytes, $false)

    # Convert to string
    $decryptedPassword = [System.Text.Encoding]::Unicode.GetString($decryptedBytes)

    return $decryptedPassword
}
