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
        Can be x64, x86, ia64, ARM or "All".

    .PARAMETER OperatingSystem
        Specify one or more operating systems. Tab complete to see what's available. If anything is missing, please file an issue.

    .PARAMETER InputObject
        Enables piping from Get-KbUpdate

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

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
    #>
    [CmdletBinding()]
    param(
        [Alias("Name")]
        [string[]]$Pattern,
        [string]$Path = ".",
        [string]$FilePath,
        [ValidateSet("x64", "x86", "ia64", "ARM", "All")]
        [string[]]$Architecture,
        [ValidateSet("Windows XP", "Windows Vista", "Windows 7", "Windows 8", "Windows 10", "Windows Server 2019", "Windows Server 2012", "Windows Server 2012 R2", "Windows Server 2008", "Windows Server 2008 R2", "Windows Server 2003", "Windows Server 2000")]
        [string[]]$OperatingSystem,
        [parameter(ValueFromPipeline)]
        [pscustomobject[]]$InputObject,
        [switch]$EnableException
    )
    process {
        if ($Pattern.Count -gt 0 -and $PSBoundParameters.FilePath) {
            Stop-PSFFunction -EnableException:$EnableException -Message "You can only specify one KB when using FilePath"
            return
        }

        if (-not $PSBoundParameters.InputObject -and -not $PSBoundParameters.Pattern) {
            Stop-PSFFunction -EnableException:$EnableException -Message "You must specify a KB name or pipe in results from Get-KbUpdate"
            return
        }

        foreach ($kb in $Pattern) {
            # why arent psboundparams working, this just started happening
            # terribly gross but i'm sleepy and it works
            if ($Architecture -and $OperatingSystem) {
                $InputObject += Get-KbUpdate -Pattern $kb -EnableException:$EnableException -Architecture $Architecture -OperatingSystem $OperatingSystem
            } elseif ($Architecture -and -not $OperatingSystem) {
                $InputObject += Get-KbUpdate -Pattern $kb -EnableException:$EnableException -Architecture $Architecture
            } elseif (-not $Architecture -and $OperatingSystem) {
                $InputObject += Get-KbUpdate -Pattern $kb -EnableException:$EnableException -OperatingSystem $OperatingSystem
            } else {
                $InputObject += Get-KbUpdate -Pattern $kb -EnableException:$EnableException
            }
        }

        foreach ($object in $InputObject) {
            if ($Architecture -and $Architecture -ne "All") {
                $templinks = $object.Link | Where-Object { $PSItem -match "$($Architecture)_" }

                if (-not $templinks) {
                    $templinks = $object | Where-Object Architecture -eq $Architecture
                }

                if ($templinks) {
                    $object = $templinks
                } else {
                    Stop-PSFFunction -EnableException:$EnableException -Message "Could not find architecture match, downloading all"
                }
            }

            foreach ($link in $object.Link) {
                if (-not $PSBoundParameters.FilePath) {
                    $FilePath = Split-Path -Path $link -Leaf
                } else {
                    $Path = Split-Path -Path $FilePath
                }

                $file = "$Path$([IO.Path]::DirectorySeparatorChar)$FilePath"

                if ((Get-Command Start-BitsTransfer -ErrorAction Ignore)) {
                    try {
                        Start-BitsTransfer -Source $link -Destination $file -ErrorAction Stop
                    } catch {
                        Write-Progress -Activity "Downloading $FilePath" -Id 1
                        Invoke-TlsWebRequest -OutFile $file -Uri $link -UseBasicParsing
                        Write-Progress -Activity "Downloading $FilePath" -Id 1 -Completed
                    }
                } else {
                    try {
                        # IWR is crazy slow for large downloads
                        Write-Progress -Activity "Downloading $FilePath" -Id 1
                        Invoke-TlsWebRequest -OutFile $file -Uri $link -UseBasicParsing
                        Write-Progress -Activity "Downloading $FilePath" -Id 1 -Completed
                    } catch {
                        Stop-PSFFunction -EnableException:$EnableException -Message "Failure" -ErrorRecord $_ -Continue
                    }
                }
                if (Test-Path -Path $file) {
                    Get-ChildItem -Path $file
                }
            }
        }
    }
}