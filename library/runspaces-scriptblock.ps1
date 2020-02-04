# BLOCK 2: Create reusable scriptblock. This is the workhorse of the runspace. Think of it as a function.
$scriptblock = {
    Param (
        [pscustomobject]$paramhash
    )

    $guid = $paramhash.guid
    $title = $paramhash.$Title
    $simple = $paramhash.$Simple
    $moduleroot = $paramhash.Moduleroot

    . "$ModuleRoot\private\Get-Info.ps1"
    . "$ModuleRoot\private\Get-SuperInfo.ps1"
    . "$ModuleRoot\private\Invoke-TlsWebRequest.ps1"
    . "$ModuleRoot\private\Write-ProgressHelper.ps1"

    # cacher
    $hashkey = "$guid-$Simple"

    if ($kbcollection.ContainsKey($hashkey)) {
        $kbcollection[$hashkey]
        continue
    }

    Write-Verbose -Message "Downloading information for $Title"
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

        $null = $kbcollection.Add($hashkey, (
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
    }
}

