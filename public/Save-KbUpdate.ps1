function Save-KbUpdate {
    <#
    .SYNOPSIS
        Downloads patches from Microsoft

    .DESCRIPTION
         Downloads patches from Microsoft

    .PARAMETER Name
        The KB name or number. For example, KB4057119 or 4057119.

    .PARAMETER Path
        The directory to save the file.

    .PARAMETER FilePath
        The exact file name to save to, otherwise, it uses the name given by the webserver

     .PARAMETER Architecture
        Can be x64, x86, ia64 or "All". Defaults to All.

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
        PS C:\> Save-KbUpdate -Name KB4057119

        Downloads KB4057119 to the current directory. This works for SQL Server or any other KB.

    .EXAMPLE
        PS C:\> Get-KbUpdate -Name 3118347 -Simple -Architecture x64 | Out-GridView -Passthru | Save-KbUpdate

        Downloads the selected files from KB4057119 to the current directory.

    .EXAMPLE
        PS C:\> Save-KbUpdate -Name KB4057119, 4057114 -Architecture x64 -Path C:\temp

        Downloads KB4057119 and the x64 version of KB4057114 to C:\temp.

    .EXAMPLE
        PS C:\> Save-KbUpdate -Name KB4057114 -Path C:\temp

        Downloads all versions of KB4057114 and the x86 version of KB4057114 to C:\temp.
#>
    [CmdletBinding()]
    param(
        [string[]]$Name,
        [string]$Path = ".",
        [string]$FilePath,
        [ValidateSet("x64", "x86", "ia64", "All")]
        [string]$Architecture = "All",
        [parameter(ValueFromPipeline)]
        [pscustomobject[]]$InputObject,
        [switch]$EnableException
    )
    process {
        if ($Name.Count -gt 0 -and $PSBoundParameters.FilePath) {
            Stop-PSFFunction -Message "You can only specify one KB when using FilePath"
            return
        }

        if (-not $PSBoundParameters.InputObject -and -not $PSBoundParameters.Name) {
            Stop-PSFFunction -Message "You must specify a KB name or pipe in results from Get-KbUpdate"
            return
        }

        foreach ($kb in $Name) {
            $InputObject += Get-KbUpdate -Name $kb -Architecture $Architecture
        }

        foreach ($object in $InputObject) {
            if ($Architecture -ne "All") {
                $templinks = $object.Link | Where-Object { $PSItem -match "$($Architecture)_" }

                if (-not $templinks) {
                    $templinks = $object | Where-Object Architecture -eq $Architecture
                }

                if ($templinks) {
                    $object = $templinks
                } else {
                    Stop-PSFFunction -Message "Could not find architecture match, downloading all"
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
                        Stop-PSFFunction -Message "Failure" -ErrorRecord $_ -Continue
                    }
                }
                if (Test-Path -Path $file) {
                    Get-ChildItem -Path $file
                }
            }
        }
    }
}