function Update-KbDatabase {
    [CmdletBinding()]
    param(
        [switch]$EnableException
    )
    begin {
        if ($EnableException) { $ee = $true } else { $ee = $false }
        $PSDefaultParameterValues["*:EnableException"] = $ee
        $PSDefaultParameterValues["Invoke-WebRequest:SkipHeaderValidation"] = $true
        $PSDefaultParameterValues["*:Confirm"] = $false
        # Bunch of functions are needed to help parallelization

        function Update-KbDb {
            [CmdletBinding()]
            param(
                $recent
            )
            begin {

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
                function ConvertTo-DataTable {
                    [OutputType([Data.DataTable])]
                    param(
                        # The input objects
                        [Parameter(Mandatory, ValueFromPipeline)]
                        [PSObject[]]$InputObject
                    )
                    begin {
                        $outputDataTable = New-Object System.Data.DataTable

                    }
                    process {
                        foreach ($object in $InputObject) {
                            $DataRow = $outputDataTable.NewRow()

                            foreach ($property in $object.PsObject.properties) {
                                $propName = $property.Name
                                $propValue = $property.Value

                                if (-not $outputDataTable.Columns.Contains($propName)) {
                                    $outputDataTable.Columns.Add((
                                            New-Object System.Data.DataColumn -Property @{
                                                ColumnName = $propName
                                                DataType   = 'System.Object'
                                            }
                                        ))
                                }

                                $DataRow.Item($propName) = if ($propValue) {
                                    [PSObject]$propValue
                                } else {
                                    [DBNull]::Value
                                }

                            }
                            $outputDataTable.Rows.Add($DataRow)
                        }
                    }
                    end {
                        ,$outputDataTable
                    }
                }

                function Get-KbItemFromWeb ($kb) {
                    try {
                        # long story
                        $guids = @()
                        $guids += [PSCustomObject]@{
                            Guid  = $kb
                            Title = $kb
                        }

                        $sb = {
                            $post = @{ size = 0
                                updateID    = $psitem.Guid
                                uidInfo     = $psitem.Guid
                            } | ConvertTo-Json -Compress

                            $parms = @{
                                Uri    = 'https://www.catalog.update.microsoft.com/DownloadDialog.aspx'
                                Method = "POST"
                                Body   = @{ updateIDs = "[$post]" }
                            }
                            Invoke-TlsWebRequest @parms | Select-Object -ExpandProperty Content
                        }

                        $downloaddialogs = $guids | ForEach-Object -Process $sb

                        foreach ($downloaddialog in $downloaddialogs) {
                            $title = Get-Info -Text $downloaddialog -Pattern 'enTitle ='
                            $arch = Get-Info -Text $downloaddialog -Pattern 'architectures ='
                            $longlang = Get-Info -Text $downloaddialog -Pattern 'longLanguages ='
                            if ($Pattern -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
                                $updateid = "$Pattern"
                            } else {
                                $updateid = Get-Info -Text $downloaddialog -Pattern 'updateID ='
                            }
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
                            # Thanks @klorgas! https://github.com/potatoqualitee/kbupdate/issues/131
                            $supersededby = Get-SuperInfo -Text $detaildialog -Pattern '<div id="supersededbyInfo".*>'
                            $supersedes = Get-SuperInfo -Text $detaildialog -Pattern '<div id="supersedesInfo".*>'

                            if ($uninstallsteps -eq "n/a") {
                                $uninstallsteps = $null
                            }

                            if ($msrcnumber -eq "n/a" -or $msrcnumber -eq "Unspecified") {
                                $msrcnumber = $null
                            }

                            $downloaddialog = $downloaddialog.Replace('www.download.windowsupdate', 'download.windowsupdate')

                            if ($kbnumbers -eq "n/a") {
                                $kbnumbers = $null
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

                            # find links that contain windowsupdate.com using regex

                            $downloaddialog = $downloaddialog.Replace('www.download.windowsupdate', 'download.windowsupdate')
                            $links = $downloaddialog | Select-String -AllMatches -Pattern "(http[s]?\://.*download\.windowsupdate\.com\/[^\'\""]*)" | Select-Object -Unique

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
                                Link              = $links.matches.value -join "|"
                                InputObject       = $kb
                            }
                        }
                    } catch {
                        throw $PSitem
                    }
                }

                $scriptblock = {
                    $PSDefaultParameterValues["Invoke-WebRequest:SkipHeaderValidation"] = $true
                    Import-Module PSSQLite -Verbose:$false
                    $update = $PSItem
                    $guid = $update.UpdateID

                    # Links

                    try {
                        # Adding 04f45522-c78e-45d8-82a1-5614e9ab8596 to kb table
                        Write-Verbose -Message "Getting fresh web data for $guid"
                        try {
                            $webupdate = Get-KbItemFromWeb $guid
                        } catch {
                            throw "Unable to get details for $guid | $PSItem"
                        }

                        if ($update.PayloadFiles.File) {
                            Write-Verbose -Message "Found $(($update.PayloadFiles.File).Count) link(s), deleting old ones from the db and adding updated links"
                            Invoke-SQLiteQuery -DataSource $db -Query "delete from Link where UpdateId = '$guid'"

                            foreach ($file in $update.PayloadFiles.File) {
                                $fileid = $file.id
                                $url = ($ds.Tables["FileLocation"].Select("Id = '$fileid'")).Url
                                $url = $url.Replace("http://download.windowsupdate.com", "https://catalog.s.download.windowsupdate.com")
                                $url = $url.Replace("http://www.download.windowsupdate.com", "https://catalog.s.download.windowsupdate.com")

                                if ($url) {
                                    Invoke-SQLiteBulkCopy -DataTable (
                                        [pscustomobject]@{
                                            UpdateId = $guid
                                            Link     = $url
                                        } | ConvertTo-DataTable) -DataSource $db -Table Link -Confirm:$false
                                }
                            }
                        } elseif ($webupdate.Link) {
                            Write-Warning "no link in xml but found in webupdate $guid"

                            Write-Verbose -Message "Found $(($update.PayloadFiles.File).Count) link(s), deleting old ones from the db and adding updated links"
                            Invoke-SQLiteQuery -DataSource $db -Query "delete from Link where UpdateId = '$guid'"

                            $links = $webupdate.Link -split "\|"
                            foreach ($link in $links) {
                                Invoke-SQLiteBulkCopy -DataTable (
                                    [pscustomobject]@{
                                        UpdateId = $guid
                                        Link     = $link
                                    } | ConvertTo-DataTable) -DataSource $db -Table Link -Confirm:$false
                            }
                        }


                        if (-not $webupdate.UpdateId) {
                            return
                        }

                        try {
                            Write-Verbose -Message "Deleting old entries from $db"
                            Invoke-SQLiteQuery -DataSource $db -Query "delete from Kb where UpdateId = '$guid'"
                            Invoke-SQLiteQuery -DataSource $db -Query "delete from SupersededBy where UpdateId = '$guid'"
                            Invoke-SQLiteQuery -DataSource $db -Query "delete from Supersedes where UpdateId = '$guid'"

                            $kb = $webupdate | Select-Object -Property * -ExcludeProperty SupersededBy, Supersedes, Link, InputObject
                        } catch {
                            throw "Unable to delete db entries for $guid | $PSItem"
                        }

                        # Saved to DB as a full string then split by pipe in PowerShell
                        if ($kb.SupportedProducts) {
                            $kb.SupportedProducts = $kb.SupportedProducts -join "|"
                        }

                        Write-Verbose -Message "Adding $guid to kb table"
                        $null = Add-Member -InputObject $kb -NotePropertyName DateAdded -NotePropertyValue (Get-Date) -Force
                        try {
                            Invoke-SQLiteBulkCopy -DataTable ($kb | ConvertTo-DataTable) -DataSource $db -Table Kb -Confirm:$false
                        } catch {
                            Write-Warning -Message "Failure on $guid | $PSItem"
                            continue
                        }

                        try {
                            if ($webupdate.SupersededBy) {
                                Write-Verbose -Message "Processing $(($webupdate.SupersededBy).Count) SupersededBy matches"
                                foreach ($item in $webupdate.SupersededBy) {
                                    if ($null -ne $item.Kb -and '' -ne $item.Kb) {
                                        if ($item.Kb) {
                                            Invoke-SQLiteBulkCopy -DataTable ([pscustomobject]@{
                                                    UpdateId    = $update.UpdateId
                                                    Kb          = $item.Kb
                                                    Description = $item.Description
                                                } | ConvertTo-DataTable) -DataSource $db -Table SupersededBy -Confirm:$false
                                        }
                                    }
                                }
                            }
                        } catch {
                            Write-Warning -Message $PSItem
                            continue
                        }

                        try {
                            Write-Verbose -Message "Processing $(($webupdate.Supersedes).Count) Supersedes matches"
                            if ($webupdate.Supersedes) {
                                foreach ($item in $webupdate.Supersedes) {
                                    if ($null -ne $item.Kb -and '' -ne $item.Kb) {
                                        if ($item.Kb) {
                                            Invoke-SQLiteBulkCopy -DataTable ([pscustomobject]@{ UpdateId = $update.UpdateId; Kb = $item.Kb; Description = $item.Description } | ConvertTo-DataTable) -DataSource $db -Table Supersedes -Confirm:$false
                                        }
                                    }
                                }
                            }

                        } catch {
                            Write-Warning -Message $PSItem
                            continue
                        }
                    } catch {
                        Write-Warning -Message "Failure for $guid | $PSItem"
                        continue
                    }
                }
            }
            process {
                $parm = @{
                    ImportVariables = $true
                    ImportFunctions = $true
                    Quiet           = $true
                    RunspaceTimeout = 180
                    ScriptBlock     = $scriptblock
                    ErrorAction     = "Stop"

                }
                try {
                    $recent | Invoke-Parallel @parm
                } catch {
                    Write-Warning "Error: $PSItem"
                    try {
                        $PSItem.UpdateId | ForEach-Object -Process $scriptblock
                    } catch {
                        Write-Warning "Error: $PSItem"
                        continue
                    }
                }
                # if going one-by-one is needed for debugging
                # $recent | ForEach-Object -Process $scriptblock
            }
        }
    }
    process {
        <#
        KB5013944

            $xml.OfflineSyncPackage.CreationDate
            MinimumClientVersion : 5.8.0.2678
            PackageId            : c837c786-be39-4f17-8ec5-ede03ad2c80a
            PackageVersion       : 1.1
            ProtocolVersion      : 1.0
            CreationDate         : 2022-05-10T16:25:52Z
            SourceId             : 802cb907-a558-4033-9844-bbf65cd3481e
            xmlns                : http://schemas.microsoft.com/msus/2004/02/OfflineSync
            Updates              : Updates
            FileLocations        : FileLocations
        #>
        Write-ProgressHelper -StepNumber 1 -Activity "Setting up prerequisites" -Message "Getting database details"

        try {
            $null = Import-Module kbupdate-library -ErrorAction Stop
        } catch {
            $null = Set-PSRepository PSGallery -InstallationPolicy Trusted
            $null = Install-Module kbupdate-library -ErrorAction Stop -Scope CurrentUser
            $null = Import-Module kbupdate-library -ErrorAction Stop
        }
        $modpath = Split-Path (Get-Module kbupdate-library).Path
        $kblib = Join-PSFPath -Path $modpath -Child library
        $db = Join-PSFPath -Path $kblib -Child kb.sqlite

        $size = [int]((Get-ChildItem -Path $db).Length / 1MB)
        "The db is $size MB" | Write-Warning

        Write-ProgressHelper -StepNumber 2 -Activity "Setting up prerequisites" -Message "Saving scanfile using Save-KbScanFile"

        Write-PSFMessage -Level Verbose -Message "Saving scanfile"
        $scanfile = Save-KbScanFile
        $basedir = Split-Path $scanfile
        $cabfile = Join-PSFPath $basedir -Child package.cab

        Write-ProgressHelper -StepNumber 3 -Activity "Setting up prerequisites" -Message "Unpacking $scanfile"

        Write-PSFMessage -Level Verbose -Message "Unpacking $scanfile"
        $cab = New-Object Microsoft.Deployment.Compression.Cab.Cabinfo $scanfile
        $null = $cab.UnpackFile("package.cab", $cabfile)
        $xmlfile = Join-PSFPath $basedir -Child package.xml

        Write-ProgressHelper -StepNumber 4 -Activity "Setting up prerequisites" -Message "Importing $xmlfile"

        $cab = New-Object Microsoft.Deployment.Compression.Cab.Cabinfo $cabfile
        $null = $cab.UnpackFile("package.xml", $xmlfile)
        $xml = [xml](Get-Content -Path $xmlfile)
        $updates = $xml.OfflineSyncPackage.Updates.Update

        Write-ProgressHelper -StepNumber 5 -Activity "Setting up prerequisites" -Message "Loading $xmlfile into dataset"

        Write-PSFMessage -Level Verbose -Message "Loading $xmlfile into dataset"
        # This takes 30 seconds but saves time in the long-run 200ms per execution X thousands
        if (-not $ds) {
            $ds = New-Object System.Data.DataSet
            $null = $ds.ReadXml($xmlfile)
        }

        Write-PSFMessage -Level Verbose -Message "$($updates.Count) total items in the database"

        Write-ProgressHelper -StepNumber 6 -Activity "Setting up prerequisites" -Message "Searching for recent updates"

        # Only process from the last 3 months, this is an arbitrary amount that will cover
        # since the last release of the offline wsus db which usually occurs every 30 days
        $recent = $updates.Where({ ([datetime]($PSItem.CreationDate)) -gt ((Get-Date).AddMonths(-3)) })
        Write-Warning "$($recent.Count) updates to process"
        Write-PSFMessage -Level Verbose -Message "Processing $($recent.Count) kbs"

        Write-ProgressHelper -StepNumber 7 -Activity "Setting up prerequisites" -Message "Processing $($recent.Count) kbs"
        Write-Progress -Activity "Setting up prerequisites" -Completed

        $output = Update-KbDb $recent

        if ($output.UpdateId) {
            $output.UpdateId | Write-Warning "Trying to grab $PSItem again"
            foreach ($object in $output) {
                $null = $object.UpdateId | ForEach-Object -Process $scriptblock -ErrorAction SilentlyContinue
            }
        }
    }
    end {
        if ($db) {
            $updatesfile = Resolve-Path -Path $script:ModuleRoot\build\updates.sql
            $null = Invoke-SQLiteQuery -DataSource $db -InputFile $updatesfile -Verbose

            $size = [int]((Get-ChildItem -Path $db).Length / 1MB)
            Write-ProgressHelper -StepNumber 1 -Activity "Compressing db" -Message "Compressing db"
            try {
                Write-PSFMessage -Level Verbose -Message "Compressing db ($size)"
                $null = Invoke-SqliteQuery -DataSource $db -Query "VACUUM;" -ErrorAction Stop
                $size = [int]((Get-ChildItem -Path $db).Length / 1MB)
                Write-PSFMessage -Level Verbose -Message "Done compressing db ($size)"
            } catch {
                Write-PSFMessage -Level Warning -Message "DB compression failed: $PSItem"
            }
            Write-Progress -Activity "Compressing db" -Completed
            "The db is $size MB" | Write-Warning
            Get-ChildItem -Path $db
        } else {
            Write-Warning "No db to compress"
        }
    }
}