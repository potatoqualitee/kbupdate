function Repair-Date {
    <#
        .SYNOPSIS
            Normalizes an update's LastModified value to an invariant yyyy-MM-dd string.

        .DESCRIPTION
            The Microsoft Update Catalog localizes the displayed "Last Updated" date to the
            Accept-Language header kbupdate sends for the -Language parameter. A US request
            returns 7/8/2025 (M/d/yyyy) while a German request returns 08.07.2025 (dd.MM.yyyy)
            and a French request returns 08/07/2025 (dd/MM/yyyy) for the very same update.

            Parsing every value as US M/d/yyyy therefore silently swaps the month and day for
            localized responses (or drops the date entirely when the day is greater than 12),
            so this helper parses using the culture that matches the requested language. The
            local database stores US-format dates, so the language-less default stays US.

        .PARAMETER Date
            The raw date value. A [datetime] is normalized directly; a string is parsed.

        .PARAMETER Language
            The -Language value used for the catalog request (a code such as "de" or "de-DE",
            or a display name such as "German"). Determines the culture used to parse a string.
    #>
    [CmdletBinding()]
    param(
        $Date,
        $Language
    )

    if (-not $Date) {
        return $null
    }

    # A real DateTime needs no locale parsing
    if ($Date -is [datetime]) {
        return $Date.ToString("yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
    }

    $enus = [System.Globalization.CultureInfo]::GetCultureInfo("en-US")

    # Resolve the culture that matches the Accept-Language kbupdate sent for this request
    $culture = $enus
    if ($Language) {
        if ($Language -is [System.Globalization.CultureInfo]) {
            $culture = $Language
        } else {
            $name = "$Language".Trim()
            # Map a display name (e.g. "German") to its Accept-Language code, as requests do
            if ($name.Length -gt 3 -and $script:languagescsv) {
                $code = ($script:languagescsv | Where-Object Name -eq $name | Select-Object -First 1).Code
                if ($code) {
                    $name = $code
                }
            }
            try {
                $culture = [System.Globalization.CultureInfo]::CreateSpecificCulture($name)
            } catch {
                $culture = $enus
            }
        }
    }

    $text = "$Date".Trim()
    $styles = [System.Globalization.DateTimeStyles]::None
    $parsed = [datetime]::MinValue

    if ([datetime]::TryParse($text, $culture, $styles, [ref]$parsed)) {
        return $parsed.ToString("yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
    }

    # Fall back to US parsing for already-normalized or US-format values (e.g. the local database)
    if ($culture -ne $enus -and [datetime]::TryParse($text, $enus, $styles, [ref]$parsed)) {
        return $parsed.ToString("yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
    }

    return $null
}
