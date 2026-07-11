function Resolve-KbNeededUpdateLink {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [pscustomobject]$InputObject,
        [pscredential]$Credential
    )
    process {
        $result = $InputObject
        if (-not $result.Link -and $result.KBUpdate) {
            if ($result.UpdateId) {
                $lookupPattern = $result.UpdateId
            } else {
                $lookupPattern = $result.KBUpdate.Trim()
            }
            Write-PSFMessage -Level Verbose -Message "No link found for $lookupPattern. Looking it up."
            $lookupParameters = @{
                Pattern      = $lookupPattern
                Simple       = $true
                ComputerName = $result.ComputerName
                Credential   = $Credential
            }
            $lookupResult = @(Get-KbUpdate @lookupParameters)
            if ($result.UpdateId) {
                $lookupResult = @($lookupResult | Where-Object UpdateId -eq $result.UpdateId)
            } else {
                $lookupResult = @($lookupResult | Where-Object Title -Match $result.KBUpdate)
            }
            $link = @(
                $lookupResult.Link |
                    Where-Object { -not [string]::IsNullOrWhiteSpace([string]$PSItem) } |
                    Select-Object -Unique
            )
            if ($link) {
                $result.Link = $link
            }
        }
        $result
    }
}
