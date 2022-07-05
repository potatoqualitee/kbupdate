function Save-KbUpdate {
    <#
    .SYNOPSIS
        Downloads patches from Microsoft

    .DESCRIPTION
         Downloads patches from Microsoft

    .PARAMETER Pattern
        Any pattern. Can be the KB name, number or even MSRC numbrer. For example, KB4057119, 4057119, or MS15-101.

    .PARAMETER Path
        The directory to save the file.

    .PARAMETER FilePath
        The exact file name to save to, otherwise, it uses the name given by the webserver

    .PARAMETER Architecture
        Can be x64, x86, ia64, or ARM.

    .PARAMETER OperatingSystem
        Specify one or more operating systems. Tab complete to see what's available. If anything is missing, please file an issue.

    .PARAMETER Product
        Specify one or more products (SharePoint, SQL Server, etc). Tab complete to see what's available. If anything is missing, please file an issue.

    .PARAMETER Language
        Specify one or more Language. Tab complete to see what's available. This is not an exact science, as the data itself is miscategorized.

    .PARAMETER Latest
        Filters out any patches that have been superseded by other patches in the batch

    .PARAMETER Source
        Search source. By default, Database is searched first, then if no matches are found, it tries finding it on the web if a an internet connection is detected.

    .PARAMETER InputObject
        Enables piping from Get-KbUpdate

    .PARAMETER AllowClobber
        Overwrite file if it exsits

    .PARAMETER Strict
        By default, when Language is specified, if a KB supports all language, the file will be downloaded.

        Use Strict to download ONLY the language and not universal KBs.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .PARAMETER Link
        When link is specified only the links in the array are processed and downloaded to the system.

    .NOTES
        Tags: Update
        Author: Chrissy LeMaire (@cl), netnerds.net
        Copyright: (c) licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .EXAMPLE
        PS C:\> Save-KbUpdate -Pattern KB4057119

        Downloads KB4057119 to the current directory. This works for SQL Server or any other KB.

    .EXAMPLE
        PS C:\> Save-KbUpdate -Pattern MS15-101

        Downloads KBs related to MSRC MS15-101 to the current directory.

    .EXAMPLE
        PS C:\> Get-KbUpdate -Pattern 3118347 -Simple -Architecture x64 | Out-GridView -Passthru | Save-KbUpdate

        Downloads the selected files from KB4057119 to the current directory.

    .EXAMPLE
        PS C:\> Save-KbUpdate -Pattern KB4057119, 4057114 -Architecture x64 -Path C:\temp

        Downloads KB4057119 and the x64 version of KB4057114 to C:\temp.

    .EXAMPLE
        PS C:\> Save-KbUpdate -Pattern KB4057114 -Path C:\temp

        Downloads all versions of KB4057114 and the x86 version of KB4057114 to C:\temp.

    .EXAMPLE
        PS C:\> Save-KBUpdate -Link $downloadLink -Path C:\temp

        Downloads all files from $downloadLink to C:\temp
    #>
    [CmdletBinding(DefaultParameterSetName = 'default')]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias("UpdateId", "Id", "KBUpdate", "HotfixId", "Name")]
        [string[]]$Pattern,
        [string]$Path = ".",
        [string]$FilePath,
        [string[]]$Architecture,
        [string[]]$OperatingSystem,
        [string[]]$Product,
        [string[]]$Language,
        [parameter(ValueFromPipeline)]
        [pscustomobject[]]$InputObject,
        [switch]$Latest,
        [switch]$AllowClobber,
        [ValidateSet("Wsus", "Web", "Database")]
        [string[]]$Source,
        [switch]$Strict,
        [switch]$EnableException,
        [Parameter(Mandatory, ParameterSetName = 'link')]
        [string[]]$Link
    )
    begin {
        $files = @()

        Write-PSFMessage -Level Verbose -Message "Source set to $Source"
    }
    process {
        switch ($PSCmdlet.ParameterSetName) {
            'link' {
                $Link | Foreach-Object {

                    $fileName = Split-Path $_ -Leaf
                    $file = Join-Path $Path -ChildPath $fileName
                    if ((Get-Command Start-BitsTransfer -ErrorAction Ignore)) {
                        try {
                            Start-BitsTransfer -Source $_ -Destination $Path -ErrorAction Stop
                        } catch {
                            Write-Host "Going to use uri: $_" -ForegroundColor Green
                            Write-Progress -Activity "Downloading $FilePath" -Id 1
                            Invoke-TlsWebRequest -OutFile $file -Uri $_
                            Write-Progress -Activity "Downloading $FilePath" -Id 1 -Completed
                        }
                    } else {
                        try {
                            # IWR is crazy slow for large downloads
                            Write-Progress -Activity "Downloading $FilePath" -Id 1
                            Invoke-TlsWebRequest -OutFile $file -Uri $_
                            Write-Progress -Activity "Downloading $FilePath" -Id 1 -Completed
                        } catch {
                            Stop-PSFFunction -EnableException:$EnableException -Message "Failure" -ErrorRecord $_ -Continue
                        }
                    }
                }
            }

            default {
                if ($Pattern.Count -gt 0 -and $PSBoundParameters.FilePath) {
                    Stop-PSFFunction -EnableException:$EnableException -Message "You can only specify one KB when using FilePath"
                    return
                }

                if (-not $PSBoundParameters.InputObject -and -not $PSBoundParameters.Pattern) {
                    Stop-PSFFunction -EnableException:$EnableException -Message "You must specify a KB name or pipe in results from Get-KbUpdate"
                    return
                }

                if (-not $PSBoundParameters.InputObject -and ($PSBoundParameters.OperatingSystem -or $PSBoundParameters.Product)) {
                    Stop-PSFFunction -EnableException:$EnableException -Message "When piping, please do not use OperatingSystem or Product filters. It's assumed that you are piping the results that you wish to download, so unexpected results may occur."
                    return
                }

                foreach ($kb in $Pattern) {
                    if ($Latest) {
                        $simple = $false
                    } else {
                        $simple = $true
                    }
                    $params = @{
                        Pattern         = $kb
                        Architecture    = $Architecture
                        OperatingSystem = $OperatingSystem
                        Product         = $Product
                        Language        = $Language
                        EnableException = $EnableException
                        Simple          = $Simple
                        Latest          = $Latest
                    }

                    if ($PSBoundParameters.Source) {
                        $params.Source = $Source
                    }

                    $InputObject += Get-KbUpdate @params
                }

                $InputObject = $InputObject | Sort-Object -Unique

                foreach ($object in $InputObject) {
                    if ($Architecture) {
                        $templinks = @()
                        foreach ($arch in $Architecture) {
                            $templinks += $object.Link | Where-Object { $PSItem -match "$($arch)_" }

                            if ("x64" -eq $arch) {
                                $templinks += $object.Link | Where-Object { $PSItem -match "64_" }
                                $templinks = $templinks | Where-Object { $PSItem -notmatch "-rt-" }
                            }
                            if (-not $templinks) {
                                $templinks += $object | Where-Object Architecture -eq $arch | Select-Object -ExpandProperty Link
                            }
                        }

                        if ($templinks) {
                            $object.Link = ($templinks | Sort-Object -Unique)
                        } else {
                            Stop-PSFFunction -EnableException:$EnableException -Message "Could not find architecture match, downloading all"
                        }
                    }

                    foreach ($link in $object.Link) {
                        $Strict = $true
                        # Microsoft's KB Language field cannot be relied upon. It'll say English then contain Chinese files.
                        if ($Language -and ($object.Link.Count -gt 1 -or $Strict)) {
                            # are there any language matches at all? if not, download it unless Strict
                            if ($Strict) {
                                $languagespecific = $true
                            } else {
                                $languagespecific = $false
                            }

                            foreach ($code in $script:languages.Values) {
                                if ($link -match "-$($code)_") {
                                    $languagespecific = $true
                                }
                            }

                            if ($languagespecific) {
                                $matches = @()
                                foreach ($value in $Language) {
                                    $code = $script:languages[$value]
                                    $matches += $object.Link -match "$($code)_"
                                }
                                if ($matches) {
                                    $object.Link = $matches
                                } else {
                                    Write-PSFMessage -Level Verbose -Message "Skipping $link - no match to $Language"
                                    continue
                                }
                            }
                        }

                        if (-not $PSBoundParameters.FilePath) {
                            $FilePath = Split-Path -Path $link -Leaf
                        } else {
                            $Path = Split-Path -Path $FilePath
                        }

                        $file = Join-Path -Path $Path -ChildPath $FilePath

                        if ((Test-Path -Path $file) -and -not $AllowClobber) {
                            Get-ChildItem -Path $file
                            $lastfile = $file
                            $files += $file
                            continue
                        }

                        # could also Get-ChildItem for the path prior to download
                        if ($file -in $files) { continue }

                        if ((Get-Command Start-BitsTransfer -ErrorAction Ignore)) {
                            try {
                                $null = Start-BitsTransfer -Source $link -Destination $file -ErrorAction Stop
                            } catch {
                                Write-Progress -Activity "Downloading $FilePath" -Id 1
                                $null = Invoke-TlsWebRequest -OutFile $file -Uri "$link"
                                Write-Progress -Activity "Downloading $FilePath" -Id 1 -Completed
                            }
                        } else {
                            try {
                                # IWR is crazy slow for large downloads
                                Write-Progress -Activity "Downloading $FilePath" -Id 1
                                $null = Invoke-TlsWebRequest -OutFile $file -Uri "$link"
                                Write-Progress -Activity "Downloading $FilePath" -Id 1 -Completed
                            } catch {
                                Stop-PSFFunction -EnableException:$EnableException -Message "Failure" -ErrorRecord $_ -Continue
                            }
                        }

                        if ((Test-Path -Path $file) -and $lastfile -ne $file) {
                            Get-ChildItem -Path $file
                            $files += $file
                        }
                    }
                }
            }
        }
    }
}