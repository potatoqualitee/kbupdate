function Get-KbUpdate {
    <#
    .SYNOPSIS
        Gets download links and detailed information for KB files (SPs/hotfixes/CUs, etc) from local db, catalog.update.microsoft.com or WSUS.

    .DESCRIPTION
        Gets detailed information including download links for KB files (SPs/hotfixes/CUs, etc) from local db, catalog.update.microsoft.com or WSUS.

        By default, the local sqlite database (updated regularly) is searched first and if no result is found, the catalog will be searched as a failback.
        Because Microsoft's RSS feed does not work, this can result in slowness. Use the Simple parameter for simplified output and faster results when using the web option.

        If you'd prefer searching and downloading from a local WSUS source, this is an option as well. See the examples for more information.

    .PARAMETER Pattern
        Any pattern. Can be the KB name, number or even MSRC numbrer. For example, KB4057119, 4057119, or MS15-101.

    .PARAMETER Architecture
        Can be x64, x86, ia64, or ARM.

    .PARAMETER Language
        Cumulative Updates come in one file for all languages, but Service Packs have a file for every language.

        If you want to get only a specific language, use this parameter.

        You you can press tab for auto-complete or use the two letter code that is used for Accept-Language HTTP header, e. g. "en" for English or "de" for German.

    .PARAMETER OperatingSystem
        Specify one or more operating systems. Tab complete to see what's available. If anything is missing, please file an issue.

    .PARAMETER ComputerName
        Used to connect to a remote host - gets the Operating System and architecture information automatically

    .PARAMETER Credential
        The optional alternative credential to be used when connecting to ComputerName

    .PARAMETER Product
        Specify one or more products (SharePoint, SQL Server, etc). Tab complete to see what's available. If anything is missing, please file an issue.

    .PARAMETER Latest
        Filters out any patches that have been superseded by other patches in the batch

    .PARAMETER Force
        When using Latest, the Web is required to get the freshest data unless Force is used. Also when Force is used, the cache is ignored.

    .PARAMETER Exclude
        Exclude matches for pattern

    .PARAMETER Simple
        A lil faster. Returns, at the very least: Title, Architecture, Language, UpdateId and Link

    .PARAMETER Source
        Search source. By default, Database is searched first, then if no matches are found, it tries finding it on the web.

    .PARAMETER Multithread
        Multithread when three or more matches are returned. This is a lot faster than the default singlethread but also a lot less reliable.

    .PARAMETER Exact
        Search for exact matches only. Basically, the search will be in quotes.

    .PARAMETER Since
        Only return results newer than this date.

    .PARAMETER CustomQuery
        Perform a custom query on the kbupdate-library sqlite database. Sets the Source to Database.

        A common query looks like this: select *, NULL AS SupersededBy, NULL AS Supersedes, NULL AS Link from kb where UpdateId in (select UpdateId from kb where UpdateId = '$kb' or Title like '%$kb%' or Id like '%$kb%' or Description like '%$kb%' or MSRCNumber like '%$kb%') and SupportedProducts in ('$oses') COLLATE NOCASE and UpdateId not in (select UpdateId from kb where UpdateId = '$ex' or Title like '%$ex%' or Id like '%$ex%' or Description like '%$ex%')

    .PARAMETER MaxPages
        Maximum number of pages to parse when using the web source, each page returns 25 results. Defaults to 1 for a total of 25 max results from the web.

        Unless you set -Source Web, more than 25xMaxPages may be returned (because db lookups are faster and dont need to care about paging).

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Author: Chrissy LeMaire (@cl), netnerds.net
        Copyright: (c) licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .EXAMPLE
        PS C:\> Get-KbUpdate KB4057119

        Gets detailed information about KB4057119.

    .EXAMPLE
        PS C:\> Get-KbUpdate -Pattern KB4057119, 4057114 -Source Database

        Gets detailed information about KB4057119 and KB4057114. Only searches the database (useful for offline enviornments).


    .EXAMPLE
        PS C:\> Get-KbUpdate -Pattern MS15-101 -Source Web

        Downloads KBs related to MSRC MS15-101 to the current directory. Only searches the web and not the local db or WSUS.

    .EXAMPLE
        PS C:\> Connect-KbWsusServer -ComputerName server1 -SecureConnection
        PS C:\> Get-KbUpdate -Pattern KB2764916

        This command will make a secure connection (Default: 443) to a WSUS server.

        Then use Wsus as a source for Get-KbUpdate.

    .EXAMPLE
        PS C:\> Connect-KbWsusServer -ComputerName server1 -SecureConnection
        PS C:\> Get-KbUpdate -Pattern KB2764916 -Source Database

        Search the database even if you've connected to WSUS in the same session.

    .EXAMPLE
        PS C:\> Get-KbUpdate -Pattern KB4057119, 4057114 -Simple

        A lil faster when using web as a source. Returns, at the very least: Title, Architecture, Language, UpdateId and Link

    .EXAMPLE
        PS C:\> Get-KbUpdate -Pattern "KB2764916 Nederlands" -Simple

        An alternative way to search for language specific packages

    .EXAMPLE
        PS C:\> Get-KbUpdate -OperatingSystem 'Windows Server 2019' -Latest -Architecture x64 -Pattern KB5015878 -Exclude 20H2, 21h2

        Gets the latest KB for KB5015878 for Windows Server 2019 x64, but excludes results for builds 20H2 and 21H2.

    .EXAMPLE
        PS C:\> Get-KbUpdate -Pattern "Windows Server 2019" -MaxPages 2 -Source Web

        Gets KBs for Windows Server 2019 from the web, and returns 2 pages (up to 50 results) instead of 1 (25 max).
#>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [Alias("UpdateId", "Id", "KBUpdate", "HotfixId", "Name")]
        [string[]]$Pattern,
        [string[]]$Architecture,
        [string[]]$OperatingSystem,
        [string[]]$Exclude,
        [PSFComputer[]]$ComputerName,
        [pscredential]$Credential,
        [string[]]$Product,
        [string]$Language,
        [switch]$Simple,
        [switch]$Exact,
        [switch]$Latest,
        [switch]$Force,
        [switch]$Multithread,
        [ValidateSet("Wsus", "Web", "Database")]
        [string[]]$Source = (Get-PSFConfigValue -FullName kbupdate.app.source),
        [int]$MaxPages = 1,
        [datetime]$Since,
        [string]$CustomQuery,
        [switch]$EnableException
    )
    begin {
        $script:MaxPages = $MaxPages
        if ($NoMultithreading) {
            Write-PSFMessage -Level Warning -Message "Multithreading now disabled by default. This parameter will likely be removed in future versions."
        }

        if ($PSBoundParameters.Language) {
            Write-PSFMessage -Level Verbose -Message "Language specified, switching to web source only"
            $Source = "Web"
        }

        if ($script:ConnectedWsus -and -not $PSBoundParameters.Source) {
            Write-PSFMessage -Level Verbose -Message "Source not specified and WSUS connection detected. Setting source to Wsus."
            $Source = "Wsus"
        }

        if ($PSBoundParameters.Query -or $PSBoundParameters.Since) {
            Write-PSFMessage -Level Verbose -Message "Query or Since specified, switching to database source only"
            if (-not $Pattern) {
                $Pattern = "%"
            }
            $Source = "Database"
        }

        if ($script:importjob.State -eq "Completed") {
            $global:kbupdate = $script:importjob | Receive-Job -Wait -AutoRemoveJob
            $null = Remove-Variable -Name importjob -Scope Script
        }

        Write-PSFMessage -Level Verbose -Message "Source set to $Source"
        if ($OperatingSystem) {
            Write-PSFMessage -Level Verbose -Message "Operating system set to $OperatingSystem"
        }

        $script:allresults = @()
        function Get-KbItemFromDb {
            [CmdletBinding()]
            param($kb, $os, $arch, $lang, $exclude, $since, $customquery)
            process {
                if (-not $kb) {
                    continue
                }
                Write-PSFMessage -Level Verbose -Message "Processing $kb"
                # Join to dupe and check dupe
                $kb = $kb.ToLower()

                if ($customquery) {
                    $query = $customquery
                } else {
                    $query = "select *, NULL AS SupersededBy, NULL AS Supersedes, NULL AS Link from kb where UpdateId in (select UpdateId from kb where UpdateId = '$kb' or Title like '%$kb%' or Id like '%$kb%' or Description like '%$kb%' or MSRCNumber like '%$kb%')"

                    if ($Since) {
                        $date = $Since.ToString("yyyy-MM-dd")
                        $query = "$query and DateAdded > '$date'"
                    }

                    if ($os) {
                        $oses = $os -join "', '"
                        $query = "$query and SupportedProducts in ('$oses') COLLATE NOCASE"
                    }

                    if ($arch) {
                        $arch = $arch -join "', '"
                        $query = "$query and Architecture in ('$arch') COLLATE NOCASE"
                    }

                    if ($lang) {
                        $lang = $lang -join "', '"
                        $query = "$query and Language in ('$lang') COLLATE NOCASE"
                    }

                    if ($exclude) {
                        foreach ($ex in $exclude) {
                            $query = "$query and UpdateId not in (select UpdateId from kb where UpdateId = '$ex' or Title like '%$ex%' or Id like '%$ex%' or Description like '%$ex%')"
                        }
                    }
                }
                Write-PSFMessage -Level Verbose -Message "Query: $query"

                $allitems = Invoke-SqliteQuery -DataSource $script:basedb -Query $query |
                    Where-Object UpdateId -notin $script:allresults | Sort-Object UpdateId -Unique

                if ($allitems.UpdateId) {
                    Write-PSFMessage -Level Verbose -Message "Found $([array]($allitems.UpdateId).count) in the database for $kb"
                }

                foreach ($item in $allitems) {
                    $script:allresults += $item.UpdateId
                    if ($global:kbupdate) {
                        # cache has finished importing
                        $item.SupersededBy = $global:kbupdate["superbyhash"][$item.UpdateId]
                        $item.Supersedes = $global:kbupdate["superhash"][$item.UpdateId]
                        $item.Link = $global:kbupdate["linkhash"][$item.UpdateId]
                    } else {
                        # I do wish my import didn't return empties but sometimes it does so check for length of 3
                        $item.SupersededBy = Invoke-SqliteQuery -DataSource $script:basedb -Query "select KB, Description from SupersededBy where UpdateId = '$($item.UpdateId)' COLLATE NOCASE and LENGTH(kb) > 3"
                        $item.Supersedes = Invoke-SqliteQuery -DataSource $script:basedb -Query "select KB, Description from Supersedes where UpdateId = '$($item.UpdateId)' COLLATE NOCASE and LENGTH(kb) > 3"
                        $item.Link = (Invoke-SqliteQuery -DataSource $script:basedb -Query "select DISTINCT Link from Link where UpdateId = '$($item.UpdateId)' COLLATE NOCASE").Link
                    }

                    if ($item.SupportedProducts -match "\|") {
                        $item.SupportedProducts = $item.SupportedProducts -split "\|"
                    }

                    if ($item.Architecture -eq "n/a") {
                        $item.Architecture = $null
                    }
                    if ($item.title -match "ia32") {
                        $item.Architecture = "IA32"
                    }
                    if ($item.title -match "ia64") {
                        $item.Architecture = "IA64"
                    }
                    if ($item.title -match "64-Bit" -and $item.title -notmatch "32-Bit" -and -not $item.Architecture) {
                        $item.Architecture = "x64"
                    }
                    if ($item.title -notmatch "64-Bit" -and $item.title -match "32-Bit" -and -not $item.Architecture) {
                        $item.Architecture = "x86"
                    }
                    if ($item.title -match "x64" -or $item.title -match "AMD64") {
                        $item.Architecture = "x64"
                    }
                    if ($item.title -match "x86") {
                        $item.Architecture = "x86"
                    }
                    if ($item.title -match "ARM64") {
                        $item.Architecture = "ARM64"
                    }
                    if ($item.title -match "ARM-based") {
                        $item.Architecture = "ARM32"
                    }
                    if ($item.link -match "x64" -or $item.link -match "AMD64" -and -not $item.Architecture) {
                        $item.Architecture = "x64"
                    }
                    if ($item.link -match "x86" -and -not $item.Architecture) {
                        $item.Architecture = "x86"
                    }
                    if ($item.link -match "ARM64" -and -not $item.Architecture) {
                        $item.Architecture = "ARM64"
                    }
                    if ($item.link -match "ARM-based" -and -not $item.Architecture) {
                        $item.Architecture = "ARM32"
                    }
                    if ($item.LastModified) {
                        $item.LastModified = Repair-Date $item.LastModified
                    }
                    foreach ($super in $item.Supersedes) {
                        $null = $super | Add-Member -MemberType ScriptMethod -Name ToString -Value { $this.Description } -Force
                    }
                    foreach ($superby in $item.SupersededBy) {
                        $null = $superby | Add-Member -MemberType ScriptMethod -Name ToString -Value { $this.Description } -Force
                    }
                    $item
                }

                if (-not $item -and $Source -eq "Database") {
                    Write-PSFMessage -Level Verbose -Message "No results found for $kb in the local database"
                }
            }
        }

        function Get-KbItemFromWsusApi ($kb) {
            Write-PSFMessage -Level Verbose -Message "Executing 'Get-PSWSUSUpdate -Update $kb'"
            $results = Get-PSWSUSUpdate -Update $kb
            foreach ($wsuskb in $results) {
                # cacher
                $guid = $wsuskb.UpdateID
                $script:allresults += $guid
                $hashkey = "$guid-$Simple"
                if ($script:kbcollection.ContainsKey($hashkey)) {
                    if ($Force) {
                        $script:kbcollection.Remove($hashkey)
                    } else {
                        $script:kbcollection[$hashkey]
                        continue
                    }
                }
                $severity = $wsuskb.MsrcSeverity | Select-Object -First 1
                $alert = $wsuskb.SecurityBulletins | Select-Object -First 1
                if ($severity -eq "MsrcSeverity") {
                    $severity = $null
                }
                if ($alert -eq "") {
                    $alert = $null
                }

                $file = $wsuskb | Get-PSWSUSInstallableItem | Get-PSWSUSUpdateFile
                $link = $file.FileURI
                if ($null -ne $link -and "" -ne $link) {
                    $link = $file.OriginUri
                }
                if ($link -eq "") {
                    $link = $null
                }

                if ($title -match "ia32") {
                    $arch = "IA32"
                }
                if ($title -match "ia64") {
                    $arch = "IA64"
                }
                if ($title -match "64-Bit" -and $title -notmatch "32-Bit" -and -not $arch) {
                    $arch = "x64"
                }
                if ($title -notmatch "64-Bit" -and $title -match "32-Bit" -and -not $arch) {
                    $arch = "x86"
                }
                if ($title -match "x64" -or $title -match "AMD64") {
                    $arch = "x64"
                }
                if ($title -match "x86") {
                    $arch = "x86"
                }
                if ($title -match "ARM64") {
                    $arch = "ARM64"
                }
                if ($title -match "ARM-based") {
                    $arch = "ARM32"
                }
                if ($link -match "x64" -or $link -match "AMD64" -and -not $arch) {
                    $arch = "x64"
                }
                if ($link -match "x86" -and -not $arch) {
                    $arch = "x86"
                }
                if ($link -match "ARM64" -and -not $arch) {
                    $arch = "ARM64"
                }
                if ($link -match "ARM-based" -and -not $arch) {
                    $arch = "ARM32"
                }

                if ($wsuskb.ArrivalDate) {
                    $lastmod = Repair-Date $wsuskb.ArrivalDate
                }

                # reset values for the loop
                $supersededby = $null
                $supersedes = $null

                if ($guid) {
                    if ($global:kbupdate) {
                        # cache has finished importing
                        try {
                            $supersededby = $global:kbupdate["superbyhash"][$guid]
                            $supersedes = $global:kbupdate["superhash"][$guid]
                            if (-not $link) {
                                $link = $global:kbupdate["linkhash"][$guid]
                            }
                        } catch {
                            #whatever
                        }
                    } else {
                        # I do wish my import didn't return empties but sometimes it does so check for length of 3
                        $supersededby = Invoke-SqliteQuery -DataSource $script:basedb -Query "select KB, Description from SupersededBy where UpdateId = '$($guid)' COLLATE NOCASE and LENGTH(kb) > 3"
                        $supersedes = Invoke-SqliteQuery -DataSource $script:basedb -Query "select KB, Description from Supersedes where UpdateId = '$($guid)' COLLATE NOCASE and LENGTH(kb) > 3"
                        $link = (Invoke-SqliteQuery -DataSource $script:basedb -Query "select DISTINCT Link from Link where UpdateId = '$($guid)' COLLATE NOCASE").Link
                    }
                }

                $null = $script:kbcollection.Add($hashkey, (
                        [pscustomobject]@{
                            Title             = $wsuskb.Title
                            Id                = ($wsuskb.KnowledgebaseArticles | Select-Object -First 1)
                            Architecture      = $null
                            Language          = $null
                            Hotfix            = $null
                            Description       = $wsuskb.Description
                            LastModified      = $lastmod
                            Size              = $wsuskb.Size
                            Classification    = $wsuskb.UpdateClassificationTitle
                            SupportedProducts = $wsuskb.ProductTitles
                            MSRCNumber        = $alert
                            MSRCSeverity      = $severity
                            RebootBehavior    = $wsuskb.InstallationBehavior.RebootBehavior
                            RequestsUserInput = $wsuskb.InstallationBehavior.CanRequestUserInput
                            ExclusiveInstall  = $null
                            NetworkRequired   = $wsuskb.InstallationBehavior.RequiresNetworkConnectivity
                            UninstallNotes    = $null # $wsuskb.uninstallnotes
                            UninstallSteps    = $null # $wsuskb.uninstallsteps
                            UpdateId          = $guid
                            Supersedes        = $supersedes
                            SupersededBy      = $supersededby
                            Link              = $link
                            InputObject       = $kb
                        }))
                $script:kbcollection[$hashkey]
            }
        }

        function Get-GuidsFromWeb ($kb) {
            Write-PSFMessage -Level Verbose -Message "$kb"

            if ($kb -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
                Write-PSFMessage -Level Verbose -Message "Guid passed in, skipping initial web search"
                $guids = @()
                $guids += [PSCustomObject]@{
                    Guid  = $kb
                    Title = $kb
                }
            } else {
                Write-Progress -Activity "Searching catalog for $kb" -Id 1 -Status "Contacting catalog.update.microsoft.com"
                if ($OperatingSystem) {
                    $os = $OperatingSystem -join '" "'
                    $url = "https://www.catalog.update.microsoft.com/Search.aspx?q=$kb+`"$os`""
                    Write-PSFMessage -Level Verbose -Message "Accessing $url"
                    $results = Invoke-TlsWebRequest -Uri $url
                    $kbids = $results.InputFields |
                        Where-Object { $_.type -eq 'Button' -and ($_.Value -eq 'Download' -or $_.class -eq 'flatBlueButtonDownload focus-only') } |
                        Select-Object -ExpandProperty ID
                }
                if (-not $kbids) {
                    $url = "https://www.catalog.update.microsoft.com/Search.aspx?q=$kb"
                    $boundparams.OperatingSystem = $OperatingSystem
                    Write-PSFMessage -Level Verbose -Message "Failing back to $url"
                    $results = Invoke-TlsWebRequest -Uri $url
                    $kbids = $results.InputFields |
                        Where-Object { $_.type -eq 'Button' -and ($_.Value -eq 'Download' -or $_.class -eq 'flatBlueButtonDownload focus-only') } |
                        Select-Object -ExpandProperty ID
                }
                Write-Progress -Activity "Searching catalog for $kb" -Id 1 -Completed

                if (-not $kbids) {
                    try {
                        $null = Invoke-TlsWebRequest -Uri "https://support.microsoft.com/en-us/topic/$kb"
                        Stop-PSFFunction -EnableException:$EnableException -Message "Matches were found for $kb, but the results no longer exist in the catalog"
                        return
                    } catch {
                        Write-PSFMessage -Level Verbose -Message "No results found for $kb at microsoft.com"
                        return
                    }
                }

                Write-PSFMessage -Level Verbose -Message "$kbids"
                # Thanks! https://keithga.wordpress.com/2017/05/21/new-tool-get-the-latest-windows-10-cumulative-updates/
                $resultlinks = $results.Links |
                    Where-Object ID -match '_link' |
                    Where-Object { $_.OuterHTML -match ( "(?=.*" + ( $Filter -join ")(?=.*" ) + ")" ) }

                # get the title too
                $guids = @()
                foreach ($resultlink in $resultlinks) {
                    $itemguid = $resultlink.id.replace('_link', '')
                    $itemtitle = ($resultlink.outerHTML -replace '<[^>]+>', '').Trim()
                    if ($itemguid -in $kbids) {
                        $guids += [pscustomobject]@{
                            Guid  = $itemguid
                            Title = $itemtitle
                        }
                    }
                }
            }
            $guids | Where-Object Guid -notin $script:allresults
        }

        function Get-KbItemFromWeb ($kb, $exact, $exclude) {
            if ($Exact) {
                $kb = "`"$kb`""
            }
            if ($Exclude) {
                $excludestr = $exclude -join '" -"'
                $kb = "$kb -`"$excludestr`""
            }
            # Wishing Microsoft offered an RSS feed. Since they don't, we are forced to parse webpages.
            function Get-Info ($Text, $Pattern) {
                if ($Pattern -match "labelTitle") {
                    if ($Pattern -match "SupportedProducts") {
                        # no idea what the regex below does but it's not working for SupportedProducts
                        # do it the manual way instead
                        $block = [regex]::Match($Text, $Pattern + '[\s\S]*?\s*(.*?)\s*<\/div>').Groups[0].Value
                        $supported = $block -split "</span>" | Select-Object -Last 1
                        $supported.Trim().Replace("</div>","").Split(",").Trim()
                    } else {
                        # this should work... not accounting for multiple divs however?
                        [regex]::Match($Text, $Pattern + '[\s\S]*?\s*(.*?)\s*<\/div>').Groups[1].Value
                    }
                } elseif ($Pattern -match "span ") {
                    [regex]::Match($Text, $Pattern + '(.*?)<\/span>').Groups[1].Value
                } else {
                    [regex]::Match($Text, $Pattern + "\s?'?(.*?)'?;").Groups[1].Value
                }
            }

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

            try {
                if ($kb) {
                    $guids = Get-GuidsFromWeb -kb $kb
                } else {
                    $guids = $null
                }

                foreach ($item in $guids) {
                    $guid = $item.Guid
                    $itemtitle = $item.Title
                    $hashkey = "$guid-$Simple"
                    if ($script:kbcollection.ContainsKey($hashkey)) {
                        if ($Force) {
                            $script:kbcollection.Remove($hashkey)
                        } else {
                            $guids = $guids | Where-Object Guid -notin $guid
                            $script:kbcollection[$hashkey]
                            continue
                        }
                    }
                }

                $scriptblock = {
                    $completed++
                    $guid = $psitem.Guid
                    $itemtitle = $psitem.Title
                    Write-PSFMessage -Level Verbose -Message "Downloading information for $itemtitle"
                    $total = ($guids.Count) + 2
                    Write-ProgressHelper -TotalSteps $total -StepNumber $completed -Activity "Searching catalog" -Message "Downloading information for $itemtitle"
                    $post = @{ size = 0; updateID = $guid; uidInfo = $guid } | ConvertTo-Json -Compress
                    $body = @{ updateIDs = "[$post]" }
                    Invoke-TlsWebRequest -Uri 'https://www.catalog.update.microsoft.com/DownloadDialog.aspx' -Method Post -Body $body | Select-Object -ExpandProperty Content
                }


                if ($guids.Count -gt 2 -and $Multithread) {
                    $downloaddialogs = $guids | Invoke-Parallel -ImportVariables -ImportFunctions -ScriptBlock $scriptblock -ErrorAction Stop -RunspaceTimeout 60 -Activity "Parsing catalog.update.microsoft.com"
                } else {
                    $completed = 0
                    $downloaddialogs = $guids | ForEach-Object -Process $scriptblock
                    Write-Progress -Activity "Searching catalog" -Id 1 -Completed
                }
                $completed = 0
                foreach ($downloaddialog in $downloaddialogs) {
                    $completed++
                    $title = Get-Info -Text $downloaddialog -Pattern 'enTitle ='
                    $total = ($downloaddialogs.Count) + 2
                    Write-ProgressHelper -TotalSteps $total -StepNumber $completed -Activity "Downloading details" -Message "Getting details for $title"
                    $arch = $null
                    $longlang = Get-Info -Text $downloaddialog -Pattern 'longLanguages ='
                    if ($Pattern -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
                        $updateid = "$Pattern"
                    } else {
                        $updateid = Get-Info -Text $downloaddialog -Pattern 'updateID ='
                    }
                    $ishotfix = Get-Info -Text $downloaddialog -Pattern 'isHotFix ='
                    $hashkey = "$updateid-$Simple"

                    if ($ishotfix) {
                        $ishotfix = "True"
                    } else {
                        $ishotfix = "False"
                    }

                    if ($longlang -eq "all") {
                        $longlang = "All"
                    }
                    if ($title -match "ia32") {
                        $arch = "IA32"
                    }
                    if ($title -match "ia64") {
                        $arch = "IA64"
                    }
                    if ($title -match "64-Bit" -and $title -notmatch "32-Bit" -and -not $arch) {
                        $arch = "x64"
                    }
                    if ($title -notmatch "64-Bit" -and $title -match "32-Bit" -and -not $arch) {
                        $arch = "x86"
                    }
                    if ($title -match "x64" -or $title -match "AMD64") {
                        $arch = "x64"
                    }
                    if ($title -match "x86") {
                        $arch = "x86"
                    }
                    if ($title -match "ARM64") {
                        $arch = "ARM64"
                    }
                    if ($title -match "ARM-based") {
                        $arch = "ARM32"
                    }

                    if (-not $Simple) {
                        # Multi-byte character is corrupted if passing BasicHtmlWebResponseObject to Get-Info -Text.
                        $detaildialog = Invoke-TlsWebRequest -Uri "https://www.catalog.update.microsoft.com/ScopedViewInline.aspx?updateid=$updateid" | Select-Object -ExpandProperty Content
                        $description = Get-Info -Text $detaildialog -Pattern '<span id="ScopedViewHandler_desc">'
                        $lastmodified = Get-Info -Text $detaildialog -Pattern '<span id="ScopedViewHandler_date">'
                        $size = Get-Info -Text $detaildialog -Pattern '<span id="ScopedViewHandler_size">'
                        $classification = Get-Info -Text $detaildialog -Pattern '<span id="ScopedViewHandler_labelClassification_Separator" class="labelTitle">'
                        if (-not $arch) {
                            $arch = Get-Info -Text $detaildialog -Pattern '<span id="ScopedViewHandler_labelArchitecture_Separator" class="labelTitle">'
                        }
                        $supportedproducts = Get-Info -Text $detaildialog -Pattern '<span id="ScopedViewHandler_labelSupportedProducts_Separator" class="labelTitle">'
                        $msrcnumber = Get-Info -Text $detaildialog -Pattern '<span id="ScopedViewHandler_labelSecurityBulliten_Separator" class="labelTitle">'
                        $msrcseverity = Get-Info -Text $detaildialog -Pattern '<span id="ScopedViewHandler_msrcSeverity">'
                        $kbnumbers = Get-Info -Text $detaildialog -Pattern '<span id="ScopedViewHandler_labelKBArticle_Separator" class="labelTitle">'
                        $rebootbehavior = Get-Info -Text $detaildialog -Pattern '<span id="ScopedViewHandler_rebootBehavior">'
                        $requestuserinput = Get-Info -Text $detaildialog -Pattern '<span id="ScopedViewHandler_userInput">'
                        $exclusiveinstall = Get-Info -Text $detaildialog -Pattern '<span id="ScopedViewHandler_installationImpact">'
                        $networkrequired = Get-Info -Text $detaildialog -Pattern '<span id="ScopedViewHandler_connectivity">'
                        $uninstallnotes = Get-Info -Text $detaildialog -Pattern '<span id="ScopedViewHandler_labelUninstallNotes_Separator" class="labelTitle">'
                        $uninstallsteps = Get-Info -Text $detaildialog -Pattern '<span id="ScopedViewHandler_labelUninstallSteps_Separator" class="labelTitle">'
                        # Thanks @klorgas! https://github.com/potatoqualitee/kbupdate/issues/131
                        $supersededby = Get-SuperInfo -Text $detaildialog -Pattern '<div id="supersededbyInfo".*>'
                        $supersedes = Get-SuperInfo -Text $detaildialog -Pattern '<div id="supersedesInfo".*>'

                        if ($uninstallsteps -eq "n/a") {
                            $uninstallsteps = $null
                        }

                        if ($msrcnumber -eq "n/a" -or $msrcnumber -eq "Unspecified") {
                            $msrcnumber = $null
                        }
                    }

                    $downloaddialog = $downloaddialog.Replace('www.download.windowsupdate', 'download.windowsupdate')
                    # Thanks @BWarmuskerken https://github.com/potatoqualitee/kbupdate/issues/226
					$links = $downloaddialog | Select-String -AllMatches -Pattern "(http[s]?\://.*download\.windowsupdate\.com\/[^\'\""]*)" | Select-Object -Unique
					if (-not $links) {
						$links = $downloaddialog | Select-String -AllMatches -Pattern "(http[s]?\://.*catalog\.sf\.dl\.delivery\.mp\.microsoft\.com\/[^\'""]*)" | Select-Object -Unique
					}


                    foreach ($link in $links) {
                        if ($arch -eq "n/a") {
                            $arch = $null
                        }
                        if ($link -match "x64" -or $link -match "AMD64") {
                            $arch = "x64"
                        }
                        if ($link -match "x86") {
                            $arch = "x86"
                        }
                        if ($link -match "ARM64") {
                            $arch = "ARM64"
                        }
                        if ($link -match "ARM-based") {
                            $arch = "ARM32"
                        }

                        if ($kbnumbers -eq "n/a") {
                            $kbnumbers = $null
                        }
                        $properties = $baseproperties

                        if ($Simple) {
                            $properties = $properties | Where-Object { $PSItem -notin "Language", "LastModified", "Description", "Size", "Classification", "SupportedProducts", "MSRCNumber", "MSRCSeverity", "RebootBehavior", "RequestsUserInput", "ExclusiveInstall", "NetworkRequired", "UninstallNotes", "UninstallSteps", "SupersededBy", "Supersedes" }
                        }

                        $ishotfix = switch ($ishotfix) {
                            'Yes' { $true }
                            'No' { $false }
                            default { $ishotfix }
                        }

                        $requestuserinput = switch ($requestuserinput) {
                            'Yes' { $true }
                            'No' { $false }
                            default { $requestuserinput }
                        }

                        $exclusiveinstall = switch ($exclusiveinstall) {
                            'Yes' { $true }
                            'No' { $false }
                            default { $exclusiveinstall }
                        }

                        $networkrequired = switch ($networkrequired) {
                            'Yes' { $true }
                            'No' { $false }
                            default { $networkrequired }
                        }

                        if ('n/a' -eq $uninstallnotes) { $uninstallnotes = $null }
                        if ('n/a' -eq $uninstallsteps) { $uninstallsteps = $null }

                        # may fix later
                        $ishotfix = $null

                        $lastmod = Repair-Date $lastmodified

                        if (-not $script:kbcollection[$hashkey]) {
                            $null = $script:kbcollection.Add($hashkey, (
                                    [pscustomobject]@{
                                        Title             = $title
                                        Id                = $kbnumbers
                                        Architecture      = $arch
                                        Language          = $Language
                                        Hotfix            = $ishotfix
                                        Description       = $description
                                        LastModified      = $lastmod
                                        Size              = $size
                                        Classification    = $classification
                                        SupportedProducts = $supportedproducts
                                        MSRCNumber        = $msrcnumber
                                        MSRCSeverity      = $msrcseverity
                                        RebootBehavior    = $rebootbehavior
                                        RequestsUserInput = $requestuserinput
                                        ExclusiveInstall  = $exclusiveinstall
                                        NetworkRequired   = $networkrequired
                                        UninstallNotes    = $uninstallnotes
                                        UninstallSteps    = $uninstallsteps
                                        UpdateId          = $updateid
                                        Supersedes        = $supersedes
                                        SupersededBy      = $supersededby
                                        Link              = $link.matches.value
                                        InputObject       = $kb
                                    }))
                        }
                        $script:kbcollection[$hashkey]
                    }
                }
            } catch {
                Stop-PSFFunction -EnableException:$EnableException -Message "Failure" -ErrorRecord $_ -Continue
            }
        }

        $properties = "Title",
        "Id",
        "Description",
        "Architecture",
        "Language",
        "Classification",
        "SupportedProducts",
        "MSRCNumber",
        "MSRCSeverity",
        "Size",
        "UpdateId",
        "RebootBehavior",
        "RequestsUserInput",
        "ExclusiveInstall",
        "NetworkRequired",
        "UninstallNotes",
        "UninstallSteps",
        "SupersededBy",
        "Supersedes",
        "LastModified",
        "Link"

        if ($Simple) {
            $properties = "Title", "Architecture", "UpdateId", "Link"
        }

        if ($Source -eq "WSUS") {
            $properties = $properties | Where-Object { $PSItem -notin "Architecture", "Language", "Size", "ExclusiveInstall", "UninstallNotes", "UninstallSteps" }
        }
        # if latest is used, needs a collection
        $allkbs = @()

    }
    process {
        if ($Source -contains "Wsus" -and -not $script:ConnectedWsus) {
            Stop-PSFFunction -Message "Please use Connect-KbWsusServer before selecting WSUS as a Source" -EnableException:$EnableException
            return
        }

        if ($Latest -and $Simple) {
            Write-PSFMessage -Level Warning -Message "Simple is ignored when Latest is specified, as latest requires detailed data"
            $Simple = $false
        }

        if ($Latest -and $PSBoundParameters.Source -and $Source -eq "Database" -and -not $Force) {
            Write-PSFMessage -Level Verbose -Message "Source is ignored when Latest is specified, as latest requires the freshest data from the web. Use -Force to override this."
            $PSBoundParameters.Source = $null
            $Source = "Web"
        }

        foreach ($computer in $Computername) {
            # tempting to add language but for now I won't
            $results = $script:compcollection[$computer]
            if (-not $results) {
                try {
                    $results = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ScriptBlock {
                        $proc = $env:PROCESSOR_ARCHITECTURE
                        if ($proc -eq "AMD64") {
                            $proc = "x64"
                        }
                        $os = Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Caption
                        $os = $os.Replace("Standard", "").Replace("Microsoft ", "").Replace(" Pro", "").Replace("Professional", "").Replace("Home", "").Replace("Enterprise", "").Replace("Datacenter", "").Trim()
                        [pscustomobject]@{
                            Architecture    = $proc
                            OperatingSystem = $os
                        }
                    } -ErrorAction Stop
                } catch {
                    Stop-PSFFunction -Message "Failure" -ErrorRecord $_ -EnableException:$EnableException
                    return
                }
                $null = $script:compcollection.Add($computer, $results)
            }

            if ($results.Architecture) {
                if ($results.Architecture -notin $Architecture) {
                    Write-PSFMessage -Level Verbose -Message "Adding $($results.Architecture)"
                    $Architecture += $results.Architecture
                }
            }
            <#
                # This just makes it too strict because 21H2 is also Windows Server 2022
                if ($results.OperatingSystem) {
                    if ($results.OperatingSystem -notin $OperatingSystem) {
                        Write-PSFMessage -Level Verbose -Message "Adding $($results.OperatingSystem)"
                        $OperatingSystem += $results.OperatingSystem
                    }
                }
            #>
        }

        $boundparams = @{
            Source  = $Source
            Product = $PSBoundParameters.Product
        }

        if ($Source -ne "Database") {
            $boundparams.Architecture = $Architecture
            $boundparams.Language = $PSBoundParameters.Language
            $boundparams.OperatingSystem = $OperatingSystem
        }
        foreach ($kb in $Pattern) {
            if (-not $kb.Trim()) {
                continue
            }
            $results = @()

            if ($Latest) {
                if ($Source -contains "Wsus") {
                    $results += Get-KbItemFromWsusApi -kb $kb -exact $exact -exclude $exclude
                }

                if ($Source -contains "Database") {
                    $results += Get-KbItemFromDb -kb $kb -os $OperatingSystem -lang $Language -arch $Architecture -exclude $exclude -since $Since -customquery $CustomQuery
                }

                if ($Source -contains "Web") {
                    $results += Get-KbItemFromWeb -kb $kb -exact $exact -exclude $exclude
                }
                $allkbs += $results
            } elseif ($Source.Count -eq 1 -and $Source -eq "Database") {
                if ($Since -or $CustomQuery) {
                    Get-KbItemFromDb -kb $kb -os $OperatingSystem -lang $Language -arch $Architecture -exclude $exclude -since $Since -customquery $CustomQuery | Select-DefaultView -Property $properties
                } else {
                    Get-KbItemFromDb -kb $kb -os $OperatingSystem -lang $Language -arch $Architecture -exclude $exclude -since $Since -customquery $CustomQuery | Search-Kb @boundparams | Select-DefaultView -Property $properties
                }
            } else {
                if ($Source -contains "Wsus") {
                    $results += Get-KbItemFromWsusApi -kb $kb -exact $exact -exclude $exclude
                }

                if ($Source -contains "Database") {
                    $results += Get-KbItemFromDb -kb $kb -os $OperatingSystem -lang $Language -arch $Architecture -exclude $exclude -since $Since -customquery $CustomQuery
                }

                if ($Source -contains "Web") {
                    $results += Get-KbItemFromWeb -kb $kb -exact $exact -exclude $exclude
                }

                $allkbs += $results
            }
        }
    }
    end {
        # I'm not super awesome with the pipeline, and am open to suggestions if this is not the best way
        if ($Latest -and $allkbs) {
            $allkbs | Search-Kb @boundparams | Select-KbLatest | Select-DefaultView -Property $properties
        } elseif ($allkbs) {
            $allkbs | Search-Kb @boundparams | Select-DefaultView -Property $properties
        }
    }
}
