function Get-KbUpdate {
    <#
    .SYNOPSIS
        Gets download links and detailed information for KB files (SPs/hotfixes/CUs, etc)

    .DESCRIPTION
        Parses catalog.update.microsoft.com and grabs details for KB files (SPs/hotfixes/CUs, etc)

        Because Microsoft's RSS feed does not work, the command has to parse a few webpages which can result in slowness.

        Use the Simple parameter for simplified output and faster results.

        The upside is that you can use this command to search the same way you'd use the search bar at catalog.update.microsoft.com.

    .PARAMETER Pattern
        Any pattern. Can be the KB name, number or even MSRC numbrer. For example, KB4057119, 4057119, or MS15-101.

    .PARAMETER Architecture
        Can be x64, x86, ia64, or ARM.

    .PARAMETER Language
        Specify one or more Language. Tab complete to see what's available. This is not an exact science, as the data itself is miscategorized.

    .PARAMETER OperatingSystem
        Specify one or more operating systems. Tab complete to see what's available. If anything is missing, please file an issue.

    .PARAMETER ComputerName
        Get the Operating System and architecture information automatically

    .PARAMETER Credential
        The optional alternative credential to be used when connecting to ComputerName

    .PARAMETER Product
        Specify one or more products (SharePoint, SQL Server, etc). Tab complete to see what's available. If anything is missing, please file an issue.

    .PARAMETER Latest
        Filters out any patches that have been superseded by other patches in the batch

    .PARAMETER Simple
        A lil faster. Returns, at the very least: Title, Architecture, Language, Hotfix, UpdateId and Link

    .PARAMETER MaxResults
        The number of results. catalog.update.microsoft.com returns 25 per page.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Update
        Author: Chrissy LeMaire (@cl), netnerds.net
        Copyright: (c) licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .EXAMPLE
        PS C:\> Get-KbUpdate KB4057119

        Gets detailed information about KB4057119. This works for SQL Server or any other KB.

    .EXAMPLE
        PS C:\> Get-KbUpdate -Pattern MS15-101

        Downloads KBs related to MSRC MS15-101 to the current directory.

    .EXAMPLE
        PS C:\> Get-KbUpdate -Pattern KB4057119, 4057114

        Gets detailed information about KB4057119 and KB4057114. This works for SQL Server or any other KB.

    .EXAMPLE
        PS C:\> Get-KbUpdate -Pattern KB4057119, 4057114 -Simple

        A lil faster. Returns, at the very least: Title, Architecture, Language, Hotfix, UpdateId and Link

    .EXAMPLE
        PS C:\> Get-KbUpdate -Pattern "KB2764916 Nederlands" -Simple

        An alternative way to search for language specific packages
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Alias("Name")]
        [string[]]$Pattern,
        [string[]]$Architecture,
        [string[]]$OperatingSystem,
        [string[]]$ComputerName,
        [pscredential]$Credential,
        [string[]]$Product,
        [string[]]$Language,
        [switch]$Simple,
        [switch]$Latest,
        [int]$MaxResults = 25,
        [switch]$EnableException
    )
    begin {
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

        function Get-KbItem ($kb) {
            try {
                Write-PSFMessage -Level Verbose -Message "$kb"
                Write-Progress -Activity "Searching catalog for $kb" -Id 1 -Status "Contacting catalog.update.microsoft.com"
                $results = Invoke-TlsWebRequest -Uri "https://www.catalog.update.microsoft.com/Search.aspx?q=$kb"
                Write-Progress -Activity "Searching catalog for $kb" -Id 1 -Completed
                $nextbutton = $results.InputFields | Where-Object id -match nextPageLinkButton
                if ($nextbutton) {
                    Write-PSFMessage -Level Verbose -Message "Next button found"
                } else {
                    Write-PSFMessage -Level Verbose -Message "Next button not found"
                }

                if ($MaxResults -gt 25 -and $nextbutton) {
                    # nothing yet, i cannot figure this out
                } else {
                    $kbids = $results.InputFields |
                        Where-Object { $_.type -eq 'Button' -and $_.Value -eq 'Download' } |
                        Select-Object -ExpandProperty  ID
                }

                if (-not $kbids) {
                    try {
                        $null = Invoke-TlsWebRequest -Uri "https://support.microsoft.com/app/content/api/content/help/en-us/$kb"
                        Stop-PSFFunction -EnableException:$EnableException -Message "Matches were found for $kb, but the results no longer exist in the catalog"
                        return
                    } catch {
                        Stop-PSFFunction -EnableException:$EnableException -Message "No results found for $kb"
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

                foreach ($item in $guids) {
                    $guid = $item.Guid
                    $itemtitle = $item.Title

                    # cacher
                    $hashkey = "$guid-$Simple"
                    if ($script:kbcollection.ContainsKey($hashkey)) {
                        $script:kbcollection[$hashkey]
                        continue
                    }

                    Write-ProgressHelper -Activity "Found up to $($guids.Count) results for $kb" -Message "Getting results for $itemtitle" -TotalSteps $guids.Guid.Count -StepNumber $guids.Guid.IndexOf($guid)
                    Write-PSFMessage -Level Verbose -Message "Downloading information for $itemtitle"
                    $post = @{ size = 0; updateID = $guid; uidInfo = $guid } | ConvertTo-Json -Compress
                    $body = @{ updateIDs = "[$post]" }
                    $downloaddialog = Invoke-TlsWebRequest -Uri 'https://www.catalog.update.microsoft.com/DownloadDialog.aspx' -Method Post -Body $body | Select-Object -ExpandProperty Content

                    $title = Get-Info -Text $downloaddialog -Pattern 'enTitle ='
                    $arch = Get-Info -Text $downloaddialog -Pattern 'architectures ='
                    $longlang = Get-Info -Text $downloaddialog -Pattern 'longLanguages ='
                    $updateid = Get-Info -Text $downloaddialog -Pattern 'updateID ='
                    $ishotfix = Get-Info -Text $downloaddialog -Pattern 'isHotFix ='

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

                    $links = $downloaddialog | Select-String -AllMatches -Pattern "(http[s]?\://download\.windowsupdate\.com\/[^\'\""]*)" | Select-Object -Unique

                    foreach ($link in $links) {
                        if ($kbnumbers -eq "n/a") {
                            $kbnumbers = $null
                        }
                        $properties = $baseproperties

                        if ($Simple) {
                            $properties = $properties | Where-Object { $PSItem -notin "LastModified", "Description", "Size", "Classification", "SupportedProducts", "MSRCNumber", "MSRCSeverity", "RebootBehavior", "RequestsUserInput", "ExclusiveInstall", "NetworkRequired", "UninstallNotes", "UninstallSteps", "SupersededBy", "Supersedes" }
                        }

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
        "Hotfix",
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

        # if latest is used, needs a collection
        $allkbs = @()

    }
    process {
        if ($MaxResults -gt 25) {
            Stop-PSFFunction -Message "Sorry! MaxResults greater than 25 is not supported yet. Try a stricter search for now." -EnableException:$EnableException
            return
        }
        if ($Latest -and $Simple) {
            Write-PSFMessage -Level Warning -Message "Simple is ignored when Latest is specified, as latest requires detailed data"
            $Simple = $false
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
                    Stop-PSFFunction -Message "Failure" -ErrorRecord $_ -Continue
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
            Architecture    = $Architecture
            OperatingSystem = $OperatingSystem
            Product         = $PSBoundParameters.Product
            Language        = $PSBoundParameters.Language
        }

        foreach ($kb in $Pattern) {
            if ($Latest) {
                $allkbs += Get-KbItem $kb | Search-Kb @boundparams
            } else {
                Get-KbItem $kb | Search-Kb @boundparams | Select-DefaultView -Property $properties
            }
        }
    }
    end {
        # I'm not super awesome with the pipeline, and am open to suggestions if this is not the best way
        if ($Latest -and $allkbs) {
            $allkbs | Select-Latest | Select-DefaultView -Property $properties
        }
    }
}