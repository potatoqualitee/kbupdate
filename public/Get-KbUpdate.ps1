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

    .PARAMETER Simple
        A lil faster. Returns, at the very least: Title, Architecture, Language, UpdateId and Link

    .PARAMETER Source
        Search source. By default, Database is searched first, then if no matches are found, it tries finding it on the web.

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
                $items = Invoke-SqliteQuery -DataSource $db  -Query "select *, NULL AS SupersededBy, NULL AS Supersedes, NULL AS Link from kb where UpdateId in (select UpdateId from kb where UpdateId = '$kb' or Title like '%$kb%' or Id like '%$kb%' or Description like '%$kb%' or MSRCNumber like '%$kb%')"

                if (-not $items -and $Source -eq "Database") {
                    Write-PSFMessage -Level Verbose -Message "No results found for $kb in the local database"
                }

                foreach ($item in $items) {
                    $script:allresults += $item.UpdateId
                    $item.SupersededBy = Invoke-SqliteQuery -DataSource $db -Query "select KB, Description from SupersededBy where UpdateId = '$($item.UpdateId)'"
                    $item.Supersedes = Invoke-SqliteQuery -DataSource $db -Query "select KB, Description from Supersedes where UpdateId = '$($item.UpdateId)'"
                    $item.Link = (Invoke-SqliteQuery -DataSource $db -Query "select Link from Link where UpdateId = '$($item.UpdateId)'").Link
                    $item
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
            $runspaces = $results = @()
            try {
                $guids = Get-GuidsFromWeb -kb $kb

                # The script block is huge so let's import it
                . "$script:ModuleRoot\library\runspaces-scriptblock.ps1"

                # add each guid to a runspace
                foreach ($item in $guids) {
                    $guid = $item.Guid
                    $title = $item.Title
                    $paramhash = [pscustomobject]@{
                        Guid       = $guid
                        Title      = $title
                        Simple     = $Simple
                        ModuleRoot = $script:ModuleRoot
                    }
                    Write-Progress -Activity "Found up to $($guids.Count) results for $kb" -Status "Getting results for $title"
                    $runspacefactory = [runspacefactory]::CreateRunspace()
                    $null = $runspacefactory.Open()
                    $null = $runspacefactory.SessionStateProxy.SetVariable("kbcollection", $script:kbcollection)
                    $runspace = [powershell]::Create()
                    $null = $runspace.Runspace = $runspacefactory
                    $null = $runspace.AddScript($scriptblock)
                    $null = $runspace.AddArgument($paramhash)

                    # BLOCK 4: Add runspace to runspaces collection and "start" it
                    # Asynchronously runs the commands of the PowerShell object pipeline
                    $runspaces += [pscustomobject]@{
                        Pipe   = $runspace
                        Status = $runspace.BeginInvoke()
                        Guid   = "$guiditem-$Simple"
                    }
                }

                # BLOCK 5: Wait for runspaces to finish
                while ($runspaces.Status.IsCompleted -notcontains $true) { }

                # BLOCK 6: Clean up
                foreach ($runspace in $runspaces ) {
                    # EndInvoke method retrieves the results of the asynchronous call
                    $runspace.Pipe.EndInvoke($runspace.Status)
                    $runspace.Pipe.Dispose()
                }
                $script:kbcollection

                $pool.Close()
                $pool.Dispose()
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

        if ($Latest -and $PSBoundParameters.Source -and $Source -contains "Database") {
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
            Architecture = $Architecture
            Product      = $PSBoundParameters.Product
            Language     = $PSBoundParameters.Language
            Source       = $Source
        }

        foreach ($kb in $Pattern) {
            if ($Latest) {
                $result = $null
                if ($Source -contains "Wsus") {
                    $result = Get-KbItemFromWsusApi $kb
                }

                if (-not $result -and $Source -contains "Database") {
                    $result = Get-KbItemFromDb $kb
                }

                if (-not $result -and $Source -contains "Web") {
                    $result = Get-KbItemFromWeb $kb
                }
                $allkbs += $result | Search-Kb @boundparams
            } else {
                if ($Source -contains "Wsus") {
                    Get-KbItemFromWsusApi $kb | Search-Kb @boundparams | Select-DefaultView -Property $properties
                }

                if (-not $result -and $Source -contains "Database") {
                    Get-KbItemFromDb $kb | Search-Kb @boundparams | Select-DefaultView -Property $properties
                }

                if (-not $result -and $Source -contains "Web") {
                    Get-KbItemFromWeb $kb | Search-Kb @boundparams | Select-DefaultView -Property $properties
                }
            }
        }
    }
    end {
        # I'm not super awesome with the pipeline, and am open to suggestions if this is not the best way
        if ($Latest -and $allkbs) {
            $allkbs | Select-KbLatest | Select-DefaultView -Property $properties
        }
    }
}