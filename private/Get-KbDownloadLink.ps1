function Get-KbDownloadLink {
    <#
    .SYNOPSIS
        Extracts trusted Microsoft Update Catalog download links from dialog HTML.

    .DESCRIPTION
        Supports both the legacy Windows Update download hosts and the Microsoft delivery host used by newer update packages. Legacy HTTP links are normalized to the secure catalog host.

    .PARAMETER Content
        One or more Microsoft Update Catalog DownloadDialog HTML responses.

    .EXAMPLE
        Get-KbDownloadLink -Content $downloadDialog

        Returns the unique Microsoft-hosted package URLs in the dialog.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [string[]]$Content
    )

    process {
        foreach ($document in $Content) {
            $pattern = 'https?://(?:(?:[a-z0-9-]+\.)*download\.windowsupdate\.com|catalog\.sf\.dl\.delivery\.mp\.microsoft\.com)/[^''"\s<]*'
            $matches = [regex]::Matches($document, $pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase)
            $links = foreach ($match in $matches) {
                $link = [Net.WebUtility]::HtmlDecode($match.Value)
                # Canonicalize the bare or www legacy host to the secure catalog host (case-insensitive).
                $link = $link -replace '(?i)^https?://(?:www\.)?download\.windowsupdate\.com', 'https://catalog.s.download.windowsupdate.com'
                # Every matched host is Microsoft-owned; never hand back a plaintext HTTP link.
                $link = $link -replace '(?i)^http://', 'https://'
                $link
            }
            $links | Select-Object -Unique
        }
    }
}
