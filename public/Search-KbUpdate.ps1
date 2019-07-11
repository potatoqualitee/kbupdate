
function Search-KbUpdate {
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
        PS C:\> Search-KbUpdate -Name KB4057119

        Downloads KB4057119 to the current directory. This works for SQL Server or any other KB.

    .EXAMPLE
        PS C:\> Get-KbUpdate -Name 3118347 -Simple -Architecture x64 | Out-GridView -Passthru | Search-KbUpdate

        Downloads the selected files from KB4057119 to the current directory.

    .EXAMPLE
        PS C:\> Search-KbUpdate -Name KB4057119, 4057114 -Architecture x64 -Path C:\temp

        Downloads KB4057119 and the x64 version of KB4057114 to C:\temp.

    .EXAMPLE
        PS C:\> Search-KbUpdate -Name KB4057114 -Path C:\temp

        Downloads all versions of KB4057114 and the x86 version of KB4057114 to C:\temp.
#>
    [CmdletBinding()]
    param(
        [string[]]$Name,
        [ValidateSet("x64", "x86", "ia64", "All")]
        [string]$Architecture = "All",
        [parameter(ValueFromPipeline)]
        [pscustomobject[]]$InputObject
    )
    process {
        if (-not $PSBoundParameters.InputObject -and -not $PSBoundParameters.Name) {
            Write-Warning -Message "You must specify a KB name or pipe in results from Get-KbUpdate"
            return
        }

        foreach ($kb in $Name) {
            $InputObject += Get-KbUpdate -Name $kb -Architecture $Architecture
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