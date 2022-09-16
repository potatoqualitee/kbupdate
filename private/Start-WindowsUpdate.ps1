
function Start-WindowsUpdate {
    [CmdletBinding()]
    param (
        [psobject[]]$ComputerName = $env:ComputerName,
        [PSCredential]$Credential,
        [PSCredential]$PSDscRunAsCredential,
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias("Name", "KBUpdate", "Id")]
        [string]$HotfixId,
        [Alias("Path")]
        [string]$FilePath,
        [string]$RepositoryPath,
        [ValidateSet("WindowsUpdate", "DSC")]
        [string]$Method,
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias("UpdateId")]
        [string]$Guid,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Title,
        [string]$ArgumentList,
        [Parameter(ValueFromPipeline)]
        [pscustomobject[]]$InputObject,
        [switch]$EnableException
    )
    try {
        Write-PSFMessage -Level Verbose -Message "Using the Windows Update method"
        $sessiontype = [type]::GetTypeFromProgID("Microsoft.Update.Session")
        $session = [activator]::CreateInstance($sessiontype)
        $session.ClientApplicationID = "kbupdate installer"

        if ($InputObject.UpdateId) {
            Write-PSFMessage -Level Verbose -Message "Got an UpdateId"
            $searchresult = $session.CreateUpdateSearcher().Search("UpdateId = '$($InputObject.UpdateId)'")
        } else {
            Write-PSFMessage -Level Verbose -Message "Build needed updates"
            $searchresult = $session.CreateUpdateSearcher().Search("Type='Software' and IsInstalled=0 and IsHidden=0")
        }
    } catch {
        Stop-PSFFunction -EnableException:$EnableException -Message "Failed to create update searcher" -ErrorRecord $_ -Continue
    }

    # iterate the updates in searchresult
    # it must be force iterated like this
    if ($searchresult.Updates) {
        Write-PSFMessage -Level Verbose -Message "Processing $($searchresult.Updates.Count) updates"
        foreach ($update in $searchresult.Updates) {
            $updateinstall = New-Object -ComObject 'Microsoft.Update.UpdateColl'
            Write-PSFMessage -Level Verbose -Message "Accepting EULA for $($update.Title)"
            $null = $update.AcceptEula()
            foreach ($bundle in $update.BundledUpdates) {
                $files = New-Object -ComObject "Microsoft.Update.StringColl.1"
                foreach ($file in $bundle.DownloadContents.DownloadUrl) {
                    if ($RepositoryPath) {
                        $filename = Split-Path -Path $file.DownloadUrl -Leaf
                        Write-PSFMessage -Level Verbose -Message "Adding $filename"
                        $fullpath = Join-Path -Path $RepositoryPath -ChildPath $filename
                        Write-PSFMessage -Level Verbose -Message $fullpath
                        $null = $files.Add($fullpath)
                    }
                }
            }
            Write-PSFMessage -Level Verbose -Message "Checking to see if IsDownloaded ($($update.IsDownloaded)) is true"
            if ($update.IsDownloaded) {
                Write-PSFMessage -Level Verbose -Message "Updates for $($update.Title) do not need to be downloaded"
            } else {
                Write-PSFMessage -Level Verbose -Message "Update for $($update.Title) needs to be downloaded"
                try {
                    Write-PSFMessage -Level Verbose -Message "Creating update downloader"
                    $downloader = $session.CreateUpdateDownloader()
                    Write-PSFMessage -Level Verbose -Message "Adding Updates"
                    $downloader.Updates = $searchresult.Updates
                    Write-PSFMessage -Level Verbose -Message "Executing download"
                    $null = $downloader.Download()
                } catch {
                    Stop-PSFFunction -EnableException:$EnableException -Message "Failure on $env:ComputerName" -ErrorRecord $PSItem -Continue
                }
            }
            $updateinstall.Add($update) | Out-Null

            try {
                Write-PSFMessage -Level Verbose -Message "Creating installer object for $($update.Title)"
                $installer = $session.CreateUpdateInstaller()
                if ($updateinstall) {
                    Write-PSFMessage -Level Verbose -Message "Adding updates via updateinstall"
                    $installer.Updates = $updateinstall
                } else {
                    Write-PSFMessage -Level Verbose -Message "Adding updates via .Updates"
                    $installer.Updates = $searchresult.Updates
                }

                Write-PSFMessage -Level Verbose -Message "Installing updates"

                Write-ProgressHelper -Activity "Installing updates on $computer" -Message "Installing $($update.Title)" -ExcludePercent
                $results = $installer.Install()

                if ($results.RebootRequired -and $HResult -eq 0) {
                    $status = "Success - Reboot required"
                } else {
                    switch ($results.ResultCode) {
                        1 {
                            $status = "In Progress"
                        }
                        2 {
                            $status = "Succeeded"
                        }
                        3 {
                            $status = "Succeeded with errors"
                        }
                        4 {
                            $status = "Failed"
                        }
                        5 {
                            $status = "Aborted"
                        }
                        default {
                            $status = "Failure"
                        }
                    }
                }
                if ($update.BundledUpdates.DownloadContents.DownloadUrl) {
                    $filename = Split-Path -Path $update.BundledUpdates.DownloadContents.DownloadUrl -Leaf
                } else {
                    $filename = $null
                }

                [pscustomobject]@{
                    ComputerName = $computer
                    Title        = $update.Title
                    ID           = $update.Identity.UpdateID
                    Status       = $status
                    HotFixId     = ($update.KBArticleIDs | Select-Object -First 1)
                    Update       = $update
                } | Select-DefaultView -Property ComputerName, Title, HotFixId, Id, Status
            } catch {
                Stop-PSFFunction -EnableException:$EnableException -Message "Failure on $env:ComputerName" -ErrorRecord $PSItem -Continue
            }
        }
    } else {
        $files = New-Object -ComObject "Microsoft.Update.StringColl.1"
        $updateinstall = New-Object -ComObject 'Microsoft.Update.UpdateColl'

        Write-PSFMessage -Level Verbose -Message "Link"
        foreach ($link in $searchresult.Link) {
            if ($link -and $RepositoryPath) {
                $filename = Split-Path -Path $link -Leaf
                $fullpath = Join-Path -Path $RepositoryPath -ChildPath $filename
                Write-PSFMessage -Level Verbose -Message "Adding $fullpath"
                $null = $files.Add($fullpath)
            }
        }

        # load into Windows Update API
        try {
            Write-PSFMessage -Level Verbose -Message "Copying files to cache"
            $bundle.CopyToCache($files)
        } catch {
            Stop-PSFFunction -EnableException:$EnableException -Message "Failure on $env:ComputerName" -ErrorRecord $PSItem -Continue
        }

        try {
            Write-PSFMessage -Level Verbose -Message "Creating installer object"
            $installer = $session.CreateUpdateInstaller()
            if ($updateinstall) {
                Write-PSFMessage -Level Verbose -Message "Adding updates via updateinstall"
                $installer.Updates = $updateinstall
            } else {
                Write-PSFMessage -Level Verbose -Message "Adding updates via .Updates"
                $installer.Updates = $searchresult.Updates
            }

            Write-PSFMessage -Level Verbose -Message "Installing updates"

            Write-ProgressHelper -Activity "Installing updates on $computer" -Message "Installing $($update.Title)" -ExcludePercent
            $results = $installer.Install()

            if ($results.RebootRequired -and $HResult -eq 0) {
                $status = "Success - Reboot required"
            } else {
                switch ($results.ResultCode) {
                    1 {
                        $status = "In Progress"
                    }
                    2 {
                        $status = "Succeeded"
                    }
                    3 {
                        $status = "Succeeded with errors"
                    }
                    4 {
                        $status = "Failed"
                    }
                    5 {
                        $status = "Aborted"
                    }
                    default {
                        $status = "Failure"
                    }
                }
                if ($update.BundledUpdates.DownloadContents.DownloadUrl) {
                    $filename = Split-Path -Path $update.BundledUpdates.DownloadContents.DownloadUrl -Leaf
                } else {
                    $filename = $null
                }

                [pscustomobject]@{
                    ComputerName = $computer
                    Title        = $update.Title
                    ID           = $update.Identity.UpdateID
                    Status       = $status
                    HotFixId     = ($update.KBArticleIDs | Select-Object -First 1)
                    Update       = $update
                } | Select-DefaultView -Property ComputerName, Title, HotFixId, Id, Status
            }
        } catch {
            Stop-PSFFunction -EnableException:$EnableException -Message "Failure on $env:ComputerName" -ErrorRecord $PSItem -Continue
        }
    }
}