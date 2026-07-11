function Get-KbDelistedUpdate {
    <#
    .SYNOPSIS
        Gets curated delisted updates from trusted Microsoft download hosts.

    .DESCRIPTION
        Resolves exact KB identities from the module's curated delisted-update data. Every stored link is validated through Get-KbDownloadLink before it is returned.

    .PARAMETER Pattern
        Exact KB identity with or without the KB prefix.

    .PARAMETER Architecture
        Optional package architecture filter.

    .PARAMETER Exclude
        Optional text excluded from matching records.

    .PARAMETER Since
        Optional minimum update release date.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Pattern,
        [string[]]$Architecture,
        [string[]]$Exclude,
        [Nullable[datetime]]$Since
    )

    $identityMatch = [regex]::Match($Pattern.Trim(), '^(?i:KB)?(?<Number>[0-9]+)$')
    if (-not $identityMatch.Success) {
        return
    }

    $kbIdentity = "KB$($identityMatch.Groups['Number'].Value)"
    $catalogPath = Join-Path $script:ModuleRoot 'data/delisted-updates.csv'
    $records = Import-Csv -LiteralPath $catalogPath

    foreach ($record in $records) {
        if ($record.KBUpdate -ne $kbIdentity) {
            continue
        }
        if ($Architecture -and $record.Architecture -notin $Architecture) {
            continue
        }

        $isExcluded = $false
        foreach ($exclusion in $Exclude) {
            if ($record.KBUpdate -like "*$exclusion*" -or $record.Title -like "*$exclusion*") {
                $isExcluded = $true
                break
            }
        }
        if ($isExcluded) {
            continue
        }

        $lastModified = [datetime]::ParseExact(
            $record.LastModified,
            'yyyy-MM-dd',
            [Globalization.CultureInfo]::InvariantCulture
        )
        if ($Since -and $lastModified -lt $Since) {
            continue
        }

        $trustedLinks = @(Get-KbDownloadLink -Content $record.Link)
        if ($trustedLinks.Count -ne 1 -or $trustedLinks[0] -ne $record.Link) {
            throw "Delisted update data for $kbIdentity contains an untrusted Microsoft download link."
        }

        [pscustomobject]@{
            Title             = $record.Title
            Id                = $record.KBUpdate
            Description       = "Curated delisted Microsoft package documented at $($record.SupportUrl)"
            Architecture      = $record.Architecture
            Language          = 'All'
            Classification    = 'Updates'
            SupportedProducts = @($record.SupportedProducts.Split('|'))
            MSRCNumber        = $null
            MSRCSeverity      = $null
            Size              = [long]$record.Size
            UpdateId          = $null
            RebootBehavior    = $null
            RequestsUserInput = $null
            ExclusiveInstall  = $null
            NetworkRequired   = $true
            UninstallNotes    = $null
            UninstallSteps    = $null
            SupersededBy      = $null
            Supersedes        = $null
            LastModified      = $lastModified
            Link              = $trustedLinks[0]
            Source            = 'Delisted'
            SupportUrl        = $record.SupportUrl
            InputObject       = $Pattern
        }
    }
}
