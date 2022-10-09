function Get-Needed {
    param (
        $Computer,
        $ScanFilePath,
        $VerbosePreference
    )

    if ($ScanFilePath) {
        try {
            If (-not (Test-Path $ScanFilePath -ErrorAction Stop)) {
                Write-Warning "Windows Update offline scan file, $ScanFilePath, cannot be found on $Computer"
                return
            }
        } catch {
            if (($ScanFilePath).StartsWith("\\") -and $PSItem -match "Denied") {
                throw "$PSItem. This may be a Kerberos issue caused by the ScanFilePath being on a remote system. Use -Force to copy the catalog to a temporary directory on the remote system."
            } else {
                throw $PSItem
            }
        }
    }

    try {
        Write-Verbose -Message "Processing $computer"
        $session = [type]::GetTypeFromProgID("Microsoft.Update.Session")
        $wua = [activator]::CreateInstance($session)
        if ($ScanFilePath) {
            Write-Verbose -Message "Registering $ScanFilePath on $computer"
            try {
                $progid = [type]::GetTypeFromProgID("Microsoft.Update.ServiceManager")
                $sm = [activator]::CreateInstance($progid)
                $packageservice = $sm.AddScanPackageService("Offline Sync Service", $ScanFilePath)
            } catch {
                if (($ScanFilePath).StartsWith("\\") -and $PSItem -match "Denied") {
                    throw "$PSItem. This may be ca Kerberos issue. Consider using a Credential in order to avoid a double-hop."
                } else {
                    throw $PSItem
                }
            }

            Write-Verbose -Message "Creating update searcher"
            $searcher = $wua.CreateUpdateSearcher()
            $searcher.ServerSelection = 3
            $searcher.ServiceID = $packageservice.ServiceID.ToString()
        } else {
            Write-Verbose -Message "Creating update searcher"
            $searcher = $wua.CreateUpdateSearcher()
        }
        Write-Verbose -Message "Searching for needed updates"
        $wsuskbs = $searcher.Search("Type='Software' and IsHidden=0")
        Write-Verbose -Message "Found $($wsuskbs.Updates.Count) updates"

        foreach ($wsu in $wsuskbs) {
            foreach ($wsuskb in $wsu.Updates) {
                #isinstalled didnt work as expected for me in the searcher
                if ($wsuskb.IsInstalled) {
                    continue
                }
                # iterate the updates in searchresult
                # it must be force iterated like this
                $links = @()
                foreach ($bundle in $wsuskb.BundledUpdates) {
                    foreach ($file in $bundle.DownloadContents) {
                        if ($file.DownloadUrl) {
                            $links += $file.DownloadUrl.Replace("http://download.windowsupdate.com", "https://catalog.s.download.windowsupdate.com")
                        }
                    }
                }

                [pscustomobject]@{
                    ComputerName      = $Computer
                    Title             = $wsuskb.Title
                    Id                = ($wsuskb.KBArticleIDs | Select-Object -First 1)
                    UpdateId          = $wsuskb.Identity.UpdateID
                    Description       = $wsuskb.Description
                    LastModified      = $wsuskb.ArrivalDate
                    Size              = $wsuskb.Size
                    Classification    = $wsuskb.UpdateClassificationTitle
                    KBUpdate          = "KB$($wsuskb.KBArticleIDs | Select-Object -First 1)"
                    SupportedProducts = $wsuskb.ProductTitles
                    MSRCNumber        = $alert
                    MSRCSeverity      = $wsuskb.MsrcSeverity
                    RebootBehavior    = $wsuskb.InstallationBehavior.RebootBehavior -eq $true
                    RequestsUserInput = $wsuskb.InstallationBehavior.CanRequestUserInput
                    ExclusiveInstall  = $null
                    NetworkRequired   = $wsuskb.InstallationBehavior.RequiresNetworkConnectivity
                    UninstallNotes    = $wsuskb.UninstallNotes
                    UninstallSteps    = $wsuskb.UninstallSteps
                    Supersedes        = $null # not needed because WUA already figures this out
                    SupersededBy      = $null # not needed because WUA already figures this out
                    Link              = $links
                    InputObject       = $wsuskb
                }
            }
        }
        try {
            if ($ScanFilePath -and $packageservice) {
                Write-Verbose "Unregistering $ScanFilePath ($id) from WUA"
                $id = $packageservice.ServiceID
                $null = $sm.RemoveService($id)
            }
        } catch {
            Write-Verbose "Failed to unregister $id from WUA"
        }
    } catch {
        if ($PSItem -match "HRESULT: 0x80070005") {
            Write-Warning "You must run this command as administator in order to perform the task"
        } else {
            throw $_
        }
    }
}