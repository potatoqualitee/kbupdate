
function Select-Latest {
    <#
    .SYNOPSIS
        Gets the latest from a batch
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