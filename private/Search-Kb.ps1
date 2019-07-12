
function Search-Kb {
    <#
    .SYNOPSIS
        Searches the kb results

    .DESCRIPTION
         Searches patches from Microsoft

    .PARAMETER Name
        The KB name or number. For example, KB4057119 or 4057119.

    .PARAMETER Architecture
        Can be x64, x86, ia64 or "All". Defaults to All.

    .PARAMETER InputObject
        Enables piping from Get-KbUpdate

    .NOTES
        Tags: Update
        Author: Chrissy LeMaire (@cl), netnerds.net
        Copyright: (c) licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .EXAMPLE
        PS C:\> Search-KbUpdate -Pattern KB4057119

        Downloads KB4057119 to the current directory. This works for SQL Server or any other KB.

    .EXAMPLE
        PS C:\> Get-KbUpdate -Pattern 3118347 -Simple -Architecture x64 | Out-GridView -Passthru | Search-KbUpdate

        Downloads the selected files from KB4057119 to the current directory.

    .EXAMPLE
        PS C:\> Search-KbUpdate -Pattern KB4057119, 4057114 -Architecture x64 -Path C:\temp

        Downloads KB4057119 and the x64 version of KB4057114 to C:\temp.

    .EXAMPLE
        PS C:\> Search-KbUpdate -Pattern KB4057114 -Path C:\temp

        Downloads all versions of KB4057114 and the x86 version of KB4057114 to C:\temp.
#>
    [CmdletBinding()]
    param(
        [string[]]$Pattern,
        [ValidateSet("x64", "x86", "ia64", "All")]
        [string]$Architecture = "All",
        [ValidateSet("Windows XP", "Windows Vista", "Windows 7", "Windows 8", "Windows 10", "Windows Server 2019", "Windows Server 2012", "Windows Server 2012 R2", "Windows Server 2008", "Windows Server 2008 R2", "Windows Server 2003")]
        [string[]]$OperatingSystem,
        [parameter(ValueFromPipeline)]
        [pscustomobject[]]$InputObject
    )
    process {
        $singlekb = $script:kbcollection[$guidarch]
        if ($OperatingSystem) {
            foreach ($os in $OperatingSystem) {
                $singlekb = $singlekb | Where-Object SupportedProducts -match $OperatingSystem.Replace(' ', '.*')
            }
        }
        $singlekb
        return
        if (-not $PSBoundParameters.InputObject -and -not $PSBoundParameters.Pattern) {
            Write-Warning -Message "You must specify a KB name or pipe in results from Get-KbUpdate"
            return
        }

        foreach ($kb in $Pattern) {
            $InputObject += Get-KbUpdate -Pattern $kb
        }

        foreach ($object in $InputObject) {
            if ($ComputerName) {
                # if they specify a computername and it's a SQL patch
                # if they specify comptutername and not $Architecture, grab the unique architecutre
                # if they specify comptuername and they have kbs already installed that supercedes, warn (Maybe Test output?)
            }

            if ($Architecture -ne "All") {
                $templinks = $object.Link | Where-Object { $PSItem -match "$($Architecture)_" }

                if (-not $templinks) {
                    $templinks = $object | Where-Object Architecture -eq $Architecture
                }

                if ($templinks) {
                    $object = $templinks
                }

                # if architecture from microsoft is all but then listed in the title without the others
                # if architecture from user is -ne all and then multiple files are listed?
            }
        }
    }
}