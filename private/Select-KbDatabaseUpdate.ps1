function Select-KbDatabaseUpdate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [object[]]$InputObject,

        [string[]]$KnownUpdateId = @(),

        [datetime]$RecentSince = (Get-Date).AddMonths(-3)
    )

    begin {
        $knownUpdates = @{}
        foreach ($knownId in $KnownUpdateId) {
            if ($knownId) {
                $knownUpdates["$knownId"] = $true
            }
        }
    }

    process {
        foreach ($update in $InputObject) {
            $updateId = "$($update.UpdateId)"
            if (-not $updateId) {
                continue
            }

            $isRecent = $false
            try {
                $isRecent = ([datetime]$update.CreationDate) -gt $RecentSince
            } catch {
                Write-PSFMessage -Level Warning -Message "Could not parse the creation date for update $updateId. Treating it as a missing update so it can be refreshed."
                $isRecent = $true
            }

            if (-not $knownUpdates.ContainsKey($updateId) -or $isRecent) {
                $update
            }
        }
    }
}
