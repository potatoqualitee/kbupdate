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
        Specify one or more Language. Tab complete to see what's available. This is not an exact science, as the data itself is miscategorized.

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
        When using Latest, the Web is required to get the freshest data unless Force is used.

    .PARAMETER Simple
        A lil faster. Returns, at the very least: Title, Architecture, Language, UpdateId and Link

    .PARAMETER Source
        Search source. By default, Database is searched first, then if no matches are found, it tries finding it on the web.

    .PARAMETER NoMultithreading
        Get results one-by-one if three or more matches are returned

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
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Alias("Name", "HotfixId", "KBUpdate", "Id")]
        [string[]]$Pattern,
        [string[]]$Architecture,
        [string[]]$OperatingSystem,
        [PSFComputer[]]$ComputerName,
        [pscredential]$Credential,
        [string[]]$Product,
        [string[]]$Language,
        [switch]$Simple,
        [switch]$Latest,
        [switch]$Force,
        [switch]$NoMultithreading,
        [ValidateSet("Wsus", "Web", "Database")]
        [string[]]$Source = @("Web", "Database"),
        [switch]$EnableException
    )
    begin {
        if ($script:ConnectedWsus -and -not $PSBoundParameters.Source) {
            $Source = "Wsus"
        }

        $script:allresults = @()
        function Get-KbItemFromDb {
            [CmdletBinding()]
            param($kb)
            process {
                # Join to dupe and check dupe
                $kb = $kb.ToLower()
                $newitems = Invoke-SqliteQuery -DataSource $script:dailydb  -Query "select *, NULL AS SupersededBy, NULL AS Supersedes, NULL AS Link from kb where UpdateId in (select UpdateId from kb where UpdateId = '$kb' or Title like '%$kb%' or Id like '%$kb%' or Description like '%$kb%' or MSRCNumber like '%$kb%')"
                if ($newitems.UpdateId) {
                    Write-PSFMessage -Level Verbose -Message "Found $([array]($newitems.UpdateId).count)  in the daily database"
                }
                foreach ($item in $newitems) {
                    $script:allresults += $item.UpdateId
                    # I do wish my import didn't return empties but sometimes it does so check for length of 3
                    $item.SupersededBy = Invoke-SqliteQuery -DataSource $script:dailydb -Query "select KB, Description from SupersededBy where UpdateId = '$($item.UpdateId)' and LENGTH(kb) > 3"

                    # I do wish my import didn't return empties but sometimes it does so check for length of 3
                    $item.Supersedes = Invoke-SqliteQuery -DataSource $script:dailydb -Query "select KB, Description from Supersedes where UpdateId = '$($item.UpdateId)' and LENGTH(kb) > 3"
                    $item.Link = (Invoke-SqliteQuery -DataSource $script:dailydb -Query "select Link from Link where UpdateId = '$($item.UpdateId)'").Link
                    $item
                }

                $olditems = Invoke-SqliteQuery -DataSource $script:basedb  -Query "select *, NULL AS SupersededBy, NULL AS Supersedes, NULL AS Link from kb where UpdateId in (select UpdateId from kb where UpdateId = '$kb' or Title like '%$kb%' or Id like '%$kb%' or Description like '%$kb%' or MSRCNumber like '%$kb%')" |
                Where-Object UpdateId -notin $script:allresults

                if ($olditems.UpdateId) {
                    Write-PSFMessage -Level Verbose -Message "Found $([array]($olditems.UpdateId).count) in the archive database"
                }

                foreach ($item in $olditems) {
                    $script:allresults += $item.UpdateId
                    # I do wish my import didn't return empties but sometimes it does so check for length of 3
                    $item.SupersededBy = Invoke-SqliteQuery -DataSource $script:basedb -Query "select KB, Description from SupersededBy where UpdateId = '$($item.UpdateId)' and LENGTH(kb) > 3"

                    # I do wish my import didn't return empties but sometimes it does so check for length of 3
                    $item.Supersedes = Invoke-SqliteQuery -DataSource $script:basedb -Query "select KB, Description from Supersedes where UpdateId = '$($item.UpdateId)' and LENGTH(kb) > 3"
                    $item.Link = (Invoke-SqliteQuery -DataSource $script:basedb -Query "select Link from Link where UpdateId = '$($item.UpdateId)'").Link
                    $item
                }

                if (-not $item -and $Source -eq "Database") {
                    Write-PSFMessage -Level Verbose -Message "No results found for $kb in the local database"
                }
            }
        }

        function Get-KbItemFromWsusApi ($kb) {
            $results = Get-PSWSUSUpdate -Update $kb
            foreach ($wsuskb in $results) {
                # cacher
                $guid = $wsuskb.UpdateID
                $script:allresults += $guid
                $hashkey = "$guid-$Simple"
                if ($script:kbcollection.ContainsKey($hashkey)) {
                    $script:kbcollection[$hashkey]
                    continue
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

                $null = $script:kbcollection.Add($hashkey, (
                        [pscustomobject]@{
                            Title             = $wsuskb.Title
                            Id                = ($wsuskb.KnowledgebaseArticles | Select-Object -First 1)
                            Architecture      = $null
                            Language          = $null
                            Hotfix            = $null
                            Description       = $wsuskb.Description
                            LastModified      = $wsuskb.ArrivalDate
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
                            Supersedes        = $null #TODO
                            SupersededBy      = $null #TODO
                            Link              = $link
                            InputObject       = $kb
                        }))
                $script:kbcollection[$hashkey]
            }
        }
        function Get-GuidsFromWeb ($kb) {
            Write-PSFMessage -Level Verbose -Message "$kb"
            Write-Progress -Activity "Searching catalog for $kb" -Id 1 -Status "Contacting catalog.update.microsoft.com"
            if ($OperatingSystem) {
                $url = "https://www.catalog.update.microsoft.com/Search.aspx?q=$kb+$OperatingSystem"
                Write-PSFMessage -Level Verbose -Message "Accessing $url"
                $results = Invoke-TlsWebRequest -Uri $url
                $kbids = $results.InputFields |
                Where-Object { $_.type -eq 'Button' -and $_.Value -eq 'Download' } |
                Select-Object -ExpandProperty  ID
            }
            if (-not $kbids) {
                $url = "https://www.catalog.update.microsoft.com/Search.aspx?q=$kb"
                $boundparams.OperatingSystem = $OperatingSystem
                Write-PSFMessage -Level Verbose -Message "Failing back to $url"
                $results = Invoke-TlsWebRequest -Uri $url
                $kbids = $results.InputFields |
                Where-Object { $_.type -eq 'Button' -and $_.Value -eq 'Download' } |
                Select-Object -ExpandProperty  ID
            }
            Write-Progress -Activity "Searching catalog for $kb" -Id 1 -Completed

            if (-not $kbids) {
                try {
                    $null = Invoke-TlsWebRequest -Uri "https://support.microsoft.com/app/content/api/content/help/en-us/$kb"
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
            $guids | Where-Object Guid -notin $script:allresults
        }

        function Get-KbItemFromWeb ($kb) {
            # Wishing Microsoft offered an RSS feed. Since they don't, we are forced to parse webpages.
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
                $guids = Get-GuidsFromWeb -kb $kb

                foreach ($item in $guids) {
                    $guid = $item.Guid
                    $itemtitle = $item.Title
                    $hashkey = "$guid-$Simple"
                    if ($script:kbcollection.ContainsKey($hashkey)) {
                        $guids = $guids | Where-Object Guid -notin $guid
                        $script:kbcollection[$hashkey]
                        continue
                    }
                }

                $scriptblock = {
                    $guid = $psitem.Guid
                    $itemtitle = $psitem.Title
                    Write-Verbose -Message "Downloading information for $itemtitle"
                    $post = @{ size = 0; updateID = $guid; uidInfo = $guid } | ConvertTo-Json -Compress
                    $body = @{ updateIDs = "[$post]" }
                    Invoke-TlsWebRequest -Uri 'https://www.catalog.update.microsoft.com/DownloadDialog.aspx' -Method Post -Body $body | Select-Object -ExpandProperty Content
                }


                if ($guids.Count -gt 2 -and -not $NoMultithreading) {
                    $downloaddialogs = $guids | Invoke-Parallel -ImportVariables -ImportFunctions -ScriptBlock $scriptblock -ErrorAction Stop -RunspaceTimeout 60
                } else {
                    $downloaddialogs = $guids | ForEach-Object -Process $scriptblock
                }

                foreach ($downloaddialog in $downloaddialogs) {
                    $title = Get-Info -Text $downloaddialog -Pattern 'enTitle ='
                    $arch = Get-Info -Text $downloaddialog -Pattern 'architectures ='
                    $longlang = Get-Info -Text $downloaddialog -Pattern 'longLanguages ='
                    $updateid = Get-Info -Text $downloaddialog -Pattern 'updateID ='
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
                    if ($arch -eq "") {
                        $arch = $null
                    }
                    if ($arch -eq "AMD64") {
                        $arch = "x64"
                    }
                    if ($title -match '64-Bit' -and $title -notmatch '32-Bit' -and -not $arch) {
                        $arch = "x64"
                    }
                    if ($title -notmatch '64-Bit' -and $title -match '32-Bit' -and -not $arch) {
                        $arch = "x86"
                    }

                    if (-not $Simple) {
                        $detaildialog = Invoke-TlsWebRequest -Uri "https://www.catalog.update.microsoft.com/ScopedViewInline.aspx?updateid=$updateid"
                        $description = Get-Info -Text $detaildialog -Pattern '<span id="ScopedViewHandler_desc">'
                        $lastmodified = Get-Info -Text $detaildialog -Pattern '<span id="ScopedViewHandler_date">'
                        $size = Get-Info -Text $detaildialog -Pattern '<span id="ScopedViewHandler_size">'
                        $classification = Get-Info -Text $detaildialog -Pattern '<span id="ScopedViewHandler_labelClassification_Separator" class="labelTitle">'
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
                        $supersededby = Get-SuperInfo -Text $detaildialog -Pattern '<div id="supersededbyInfo" TABINDEX="1" >'
                        $supersedes = Get-SuperInfo -Text $detaildialog -Pattern '<div id="supersedesInfo" TABINDEX="1">'

                        if ($uninstallsteps -eq "n/a") {
                            $uninstallsteps = $null
                        }

                        if ($msrcnumber -eq "n/a") {
                            $msrcnumber = $null
                        }

                        $products = $supportedproducts -split ","
                        if ($products.Count -gt 1) {
                            $supportedproducts = @()
                            foreach ($line in $products) {
                                $clean = $line.Trim()
                                if ($clean) { $supportedproducts += $clean }
                            }
                        }
                    }

                    $downloaddialog = $downloaddialog.Replace('www.download.windowsupdate', 'download.windowsupdate')
                    $links = $downloaddialog | Select-String -AllMatches -Pattern "(http[s]?\://download\.windowsupdate\.com\/[^\'\""]*)" | Select-Object -Unique

                    foreach ($link in $links) {
                        if ($kbnumbers -eq "n/a") {
                            $kbnumbers = $null
                        }
                        $properties = $baseproperties

                        if ($Simple) {
                            $properties = $properties | Where-Object { $PSItem -notin "LastModified", "Description", "Size", "Classification", "SupportedProducts", "MSRCNumber", "MSRCSeverity", "RebootBehavior", "RequestsUserInput", "ExclusiveInstall", "NetworkRequired", "UninstallNotes", "UninstallSteps", "SupersededBy", "Supersedes" }
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
                        $null = $script:kbcollection.Add($hashkey, (
                                [pscustomobject]@{
                                    Title             = $title
                                    Id                = $kbnumbers
                                    Architecture      = $arch
                                    Language          = $longlang
                                    Hotfix            = $ishotfix
                                    Description       = $description
                                    LastModified      = $lastmodified
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
            $properties = $properties | Where-Object { $PSItem -notin "ID", "LastModified", "Description", "Size", "Classification", "SupportedProducts", "MSRCNumber", "MSRCSeverity", "RebootBehavior", "RequestsUserInput", "ExclusiveInstall", "NetworkRequired", "UninstallNotes", "UninstallSteps", "SupersededBy", "Supersedes" }
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

        if ($Latest -and $PSBoundParameters.Source -and $Source -contains "Database" -and -not $Force) {
            Write-PSFMessage -Level Warning -Message "Source is ignored when Latest is specified, as latest requires the freshest data"
            $PSBoundParameters.Source = $null
            $Source = "Web"
        }

        if (Test-PSFPowerShell -Edition Core) {
            if (Was-Bound -Not -ParameterName Source) {
                Write-PSFMessage -Level Verbose -Message "Core detected. Switching source to Web."
                $Source = "Web"
            } else {
                if ($Source -ne "Web") {
                    Stop-PSFFunction -Message "Core ony supports web scraping :(" -EnableException:$EnableException
                    return
                }
            }
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
            if ($results.OperatingSystem) {
                if ($results.OperatingSystem -notin $OperatingSystem) {
                    Write-PSFMessage -Level Verbose -Message "Adding $($results.OperatingSystem)"
                    $OperatingSystem += $results.OperatingSystem
                }
            }
        }

        $boundparams = @{
            OperatingSystem = $OperatingSystem
            Architecture    = $Architecture
            Product         = $PSBoundParameters.Product
            Language        = $PSBoundParameters.Language
            Source          = $Source
        }

        foreach ($kb in $Pattern) {
            $results = @()
            if ($Source -contains "Wsus") {
                $results += Get-KbItemFromWsusApi $kb
            }

            if ($Source -contains "Database") {
                $results += Get-KbItemFromDb $kb
            }

            if ($Source -contains "Web") {
                $results += Get-KbItemFromWeb $kb
            }
            $allkbs += $results
        }
    }
    end {
        # I'm not super awesome with the pipeline, and am open to suggestions if this is not the best way
        if ($Latest -and $allkbs) {
            $allkbs | Search-Kb @boundparams | Select-KbLatest | Select-DefaultView -Property $properties
        } else {
            $allkbs | Search-Kb @boundparams | Select-DefaultView -Property $properties
        }
    }
}