function Get-SuperInfo ($Text, $Pattern) {
    # this works, but may also summon cthulhu
    $span = [regex]::match($Text, $pattern + '[\s\S]*?<div id')

    switch -Wildcard ($span.Value) {
        "*div style*" { $regex = '">\s*(.*?)\s*<\/div>' }
        "*a href*" { $regex = "<div[\s\S]*?'>(.*?)<\/a" }
        default { $regex = '"\s?>\s*(\S+?)\s*<\/div>' }
    }

    $spanMatches = [regex]::Matches($span, $regex).ForEach( { $_.Groups[1].Value })
    if ($spanMatches -eq 'n/a') { $spanMatches = $null }

    if ($spanMatches) {
        foreach ($superMatch in $spanMatches) {
            $detailedMatches = [regex]::Matches($superMatch, '\b[kK][bB]([0-9]{6,})\b')
            # $null -ne $detailedMatches can throw cant index null errors, get more detailed
            if ($null -ne $detailedMatches.Groups) {
                [PSCustomObject] @{
                    'KB'          = $detailedMatches.Groups[1].Value
                    'Description' = $superMatch
                } | Add-Member -MemberType ScriptMethod -Name ToString -Value { $this.Description } -PassThru -Force
            }
        }
    }
}