function Get-Info ($Text, $Pattern) {
    if ($Pattern -match "labelTitle") {
        # this should work... not accounting for multiple divs however?
        [regex]::Match($Text, $Pattern + '[\s\S]*?\s*(.*?)\s*<\/div>').Groups[1].Value
    } elseif ($Pattern -match "span ") {
        [regex]::Match($Text, $Pattern + '(.*?)<\/span>').Groups[1].Value
    } else {
        [regex]::Match($Text, $Pattern + "\s?'?(.*?)'?;").Groups[1].Value
    }
}