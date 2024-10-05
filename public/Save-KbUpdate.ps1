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
        Specify one or more Language. Tab complete to see what's available.

    .PARAMETER Latest
        Filters out any patches that have been superseded by other patches in the batch

    .PARAMETER Source
        Search source. By default, Database is searched first, then if no matches are found, it tries finding it on the web if a an internet connection is detected.

    .PARAMETER InputObject
        Enables piping from Get-KbUpdate

    .PARAMETER AllowClobber
        Overwrite file if it exsits

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
        [Parameter(ValueFromPipelineByPropertyName, Mandatory, ParameterSetName = 'link')]
        [string[]]$Link,
        [Parameter(ValueFromPipelineByPropertyName, Position = 0)]
        [Alias("UpdateId", "Id", "KBUpdate", "HotfixId", "Name")]
        [string[]]$Pattern,
        [string]$Path = ".",
        [string]$FilePath,
        [string[]]$Architecture,
        [string[]]$OperatingSystem,
        [string[]]$Product,
        [string]$Language,
        [parameter(ValueFromPipeline)]
        [pscustomobject[]]$InputObject,
        [switch]$Latest,
        [switch]$AllowClobber,
        [ValidateSet("Wsus", "Web", "Database")]
        [string[]]$Source = (Get-PSFConfigValue -FullName kbupdate.app.source),
        [switch]$EnableException
    )
    begin {
        $jobs = $inputobjects = $uniquelinks = @()
        $count = 0
    }
    process {
        if ($InputObject) {
            $inputobjects += $InputObject
        }

        if ($Link) {
            $uniquelinks += $Link
        }
    }
    end {
        if ($uniquelinks) {
            $uniquelinks = $uniquelinks | Select-Object -Unique
        }
        switch ($PSCmdlet.ParameterSetName) {
            'link' {
                Write-PSFMessage -Level Verbose -Message "Processing link parameter set"
                $uniquelinks | Foreach-Object {
                    $hyperlinklol = $PSItem
                    $fileName = Split-Path $hyperlinklol -Leaf
                    if ($FilePath) {
                        $filename = $FilePath
                    }
                    $count++
                    if ($count -eq 300) {
                        $count = 1
                    }
                    $file = Join-Path -Path $Path -ChildPath $filename
                    if ((Test-Path -Path $file) -and -not $AllowClobber) {
                        Get-ChildItem -Path $file
                        continue
                    }
                    if (-not $filePath) {
                        $FilePath = $file
                    }

                    Write-PSFMessage -Level Verbose -Message "Link: $PSItem"
                    Write-PSFMessage -Level Verbose -Message "FilePath: $FilePath"
                    Write-PSFMessage -Level Verbose -Message "File: $file"

                    # just show any progress since piping won't allow calculation of the total
                    $percentcomplete = $(($count / 300) * 100)

                    if ($percentcomplete -lt 0 -or $percentcomplete -gt 100) {
                        $percentcomplete = 0
                    }

                    $progressparms = @{
                        Activity        = "Queuing up downloads"
                        Status          = "Adding files to download queue"
                        PercentComplete = $percentcomplete
                    }

                    Write-Progress @progressparms

                    if ((Get-Command Start-BitsTransfer -ErrorAction Ignore)) {
                        try {
                            if ((Get-BitsTransfer | Where-Object Description -match kbupdate).FileList.RemoteName -notcontains $hyperlinklol) {
                                Write-PSFMessage -Level Verbose -Message "Adding $filename to download queue"
                                $jobs += Start-BitsTransfer -Asynchronous -Source $hyperlinklol -Destination $Path -ErrorAction Stop -Description kbupdate
                            }
                        } catch {
                            Write-PSFMessage -Level Verbose -Message "Going to use uri: $hyperlinklol"
                            Write-Progress -Activity "Downloading $FilePath" -Id 1
                            Invoke-TlsWebRequest -OutFile $file -Uri $hyperlinklol
                            Write-Progress -Activity "Downloading $FilePath" -Id 1 -Completed
                        }
                    } else {
                        try {
                            Write-PSFMessage -Level Verbose -Message "Transfer failed. Trying again."
                            # IWR is crazy slow for large downloads
                            Write-Progress -Activity "Downloading $FilePath" -Id 1
                            Invoke-TlsWebRequest -OutFile $file -Uri $hyperlinklol
                            Write-Progress -Activity "Downloading $FilePath" -Id 1 -Completed
                        } catch {
                            Stop-PSFFunction -EnableException:$EnableException -Message "Failure" -ErrorRecord $_ -Continue
                        }
                    }
                }
            }

            default {
                Write-PSFMessage -Level Verbose -Message "Processing default parameter set"
                if ($Pattern.Count -gt 1 -and $PSBoundParameters.FilePath) {
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

                Write-PSFMessage -Level Verbose -Message "Source set to $Source"

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

                    $inputobjects += Get-KbUpdate @params
                }

                $inputobjects = $inputobjects | Sort-Object -Property UpdateId -Unique

                foreach ($object in $inputobjects) {
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

                    foreach ($dl in $object) {
                        $title = $dl.Title
                        $hyperlinklol = $object.Link
                        if (-not $PSBoundParameters.FilePath) {
                            $FilePath = Split-Path -Path $hyperlinklol -Leaf
                        } else {
                            if (-not $Path) {
                                $Path = Split-Path -Path $FilePath
                            }
                        }

                        $file = Join-Path -Path $Path -ChildPath $FilePath

                        if ((Test-Path -Path $file) -and -not $AllowClobber) {
                            Get-ChildItem -Path $file
                            continue
                        }

                        if ((Get-Command Start-BitsTransfer -ErrorAction Ignore)) {
                            try {
                                $filename = Split-Path $hyperlinklol -Leaf
                                if ((Get-BitsTransfer | Where-Object Description -match kbupdate).FileList.RemoteName -notcontains $hyperlinklol) {
                                    Write-PSFMessage -Level Verbose -Message "Adding $filename to download queue"
                                    $jobs += Start-BitsTransfer -Asynchronous -Source $hyperlinklol -Destination $file -ErrorAction Stop -Description "kbupdate - $title"
                                }
                            } catch {
                                foreach ($hyperlink in $hyperlinklol) {
                                    Write-Progress -Activity "Downloading $FilePath" -Id 1
                                    Write-PSFMessage -Level Verbose -Message "That failed, trying Invoke-WebRequest"
                                    $null = Invoke-TlsWebRequest -OutFile $file -Uri "$hyperlink"
                                    Write-Progress -Activity "Downloading $FilePath" -Id 1 -Completed
                                }
                            }
                        } else {
                            try {
                                # IWR is crazy slow for large downloads
                                Write-Progress -Activity "Downloading $FilePath" -Id 1
                                $null = Invoke-TlsWebRequest -OutFile $file -Uri "$hyperlinklol"
                                Write-Progress -Activity "Downloading $FilePath" -Id 1 -Completed
                            } catch {
                                Stop-PSFFunction -EnableException:$EnableException -Message "Failure" -ErrorRecord $_ -Continue
                            }
                            if ((Test-Path -Path $file)) {
                                Get-ChildItem -Path $file
                            }
                        }
                    }
                }
            }
        }

        if ($jobs) {
            Write-PSFMessage -Level Verbose -Message "Starting job process"
            $jobs | Start-BitsJobProcess
        }
        Write-Progress -Activity "Queuing up downloads" -Completed
    }
}
