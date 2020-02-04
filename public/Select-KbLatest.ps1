
function Select-KbLatest {
    <#
    .SYNOPSIS
        Gets the latest patches from a batch of patches

    .DESCRIPTION
        Gets the latest patches from a batch of patches, based on Supersedes and SupersededBy

        This command exposes the routine that is used to filter using -Latest in Get-KbUpdate

    .NOTES
        Author: Chrissy LeMaire (@cl), netnerds.net
        Copyright: (c) licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .EXAMPLE
        PS C:\> Get-KbUpdate -Pattern 'sql 2017' | Where-Object Classification -eq Updates | Select-KbLatest

        Selects latest from a batch of patches based on Supersedes and SupersededBy
    #>
    [CmdletBinding()]
    param(
        [parameter(ValueFromPipeline)]
        [pscustomobject[]]$InputObject
    )
    begin {
        $allkbs = @()
    }
    process {
        # build the collection so that it's comparing all and not just one
        $allkbs += $InputObject
    }
    end {
        $matches = @()
        foreach ($kb in $allkbs) {
            $otherkbs = $allkbs | Where-Object Id -ne $kb.Id
            $matches += $allkbs | Where-Object { $PSItem.Id -eq $kb.Id -and $otherkbs.Supersedes.Kb -notcontains $kb.Id }
        }
        $matches | Sort-Object UpdateId -Unique
    }
}