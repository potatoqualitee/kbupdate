function Start-BitsJobProcess {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [object[]]$InputObject,
        [switch]$EnableException
    )
    begin {
        if ($EnableException) {
            $PSDefaultParameterValues["*:EnableException"] = $true
        } else {
            $PSDefaultParameterValues["*:EnableException"] = $false
        }
        $jobs = @()
    }
    process {
        $jobs += $InputObject
    }
    end {
        $totalfiles = $jobs.FileList.Count
        $localnames = $jobs.FileList.LocalName
        $bs = $jobs | Where-Object BytesTotal -ne 18446744073709551615
        $bytestotal = ($bs.BytesTotal | Measure-Object -Sum).Sum
        $bstotal = [math]::Round(($bytestotal / 1MB),2)
        $jobIds = @($jobs | Select-Object -ExpandProperty JobId)
        $retryCounts = @{}
        $maximumRetries = 3

        while ($bitsjobs = @(Get-BitsTransfer | Where-Object { $PSItem.JobId -in $jobIds })) {
            $bytesjob = @($bitsjobs | Where-Object BytesTotal -ne 18446744073709551615)
            $bjbytestotal = ($bytesjob.BytesTransferred | Measure-Object -Sum).Sum
            $mbjtotal = [math]::Round(($bjbytestotal / 1MB),2)
            $bytestotal = ($bytesjob.BytesTotal | Measure-Object -Sum).Sum
            $bstotal = [math]::Round(($bytestotal / 1MB),2)

            $currentcount = $bitsjobs.FileList.Count
            $completed = $totalfiles - $currentcount
            # I literally can't do math and have been working on this for an hour
            $percentcomplete = 100 - $(($currentcount / $totalfiles) * 100)
            if ($percentcomplete -gt 100 -or $percentcomplete -lt 0) {
                $percentcomplete = 0
            }

            $progressparms = @{
                Activity        = "Downloaded $mbjtotal MB of at least $bstotal MB total from $($bytesjob.Count) files in this batch."
                Status          = "$completed of $totalfiles files completed"
                PercentComplete = $percentcomplete
            }
            if ($oldmbjtotal -ne $mbjtotal) {
                Write-PSFMessage -Level Debug -Message "Current count: $currentcount files"
                Write-PSFMessage -Level Debug -Message "Processing $totalfiles total files"
                Write-PSFMessage -Level Debug -Message "$completed have been completed"
                Write-PSFMessage -Level Debug -Message "$(($currentcount / $totalfiles) * 100) percent left"
                $oldmbjtotal = $mbjtotal
                Write-Progress @progressparms
                Start-Sleep -Seconds 1
            }

            foreach ($bitsjob in $bitsjobs) {
                try {
                    $title = $bitsjob.Description.Replace("kbupdate - ", "")
                    switch ($bitsjob.JobState) {
                        "Transferred" {
                            $null = Complete-BitsTransfer -BitsJob $bitsjob
                            foreach ($filename in $bitsjob.FileList.LocalName) {
                                Write-PSFMessage -Level Verbose -Message "Sweet, $filename is done."
                                do {
                                    Start-Sleep -Milliseconds 200
                                } while (-not (Test-Path -Path $filename))
                                Get-ChildItem $filename
                            }
                        }
                        { $PSItem -in "Suspended", "TransientError" } {
                            $retryKey = "$($bitsjob.JobId)"
                            if (-not $retryCounts.ContainsKey($retryKey)) {
                                $retryCounts[$retryKey] = 0
                            }
                            $retryCounts[$retryKey]++
                            foreach ($filename in $bitsjob.FileList.LocalName) {
                                Write-PSFMessage -Level Verbose -Message "Oof, $filename is $($bitsjob.JobState). Retry $($retryCounts[$retryKey]) of $maximumRetries."
                            }
                            if ($retryCounts[$retryKey] -ge $maximumRetries) {
                                $null = Remove-BitsTransfer -BitsJob $bitsjob -Confirm:$false -ErrorAction Ignore
                                Stop-PSFFunction -Message "Failure downloading $title after $maximumRetries retries | $($bitsjob.ErrorDescription)" -Continue
                            } else {
                                $null = Resume-BitsTransfer -BitsJob $bitsjob -Asynchronous -ErrorAction Ignore
                            }
                        }
                        { $PSItem -in "Error", "Cancelled" } {
                            $null = Remove-BitsTransfer -BitsJob $bitsjob -Confirm:$false -ErrorAction Ignore
                            foreach ($file in $bitsjob.FileList.LocalName) {
                                Write-PSFMessage -Level Verbose -Message "Oh no, $file has errored."
                                Stop-PSFFunction -Message "Failure downloading $title (file) | $($bitsjob.ErrorDescription)" -Continue
                            }
                        }
                    }
                } catch {
                    $null = Remove-BitsTransfer -BitsJob $bitsjob -Confirm:$false -ErrorAction Ignore
                    Stop-PSFFunction -Message "Failure for $title | $PSItem" -Continue
                }
            }
        }
        Write-Progress -Activity "Downloading $totalfiles total files" -Completed
        Get-ChildItem -Path $localnames -ErrorAction Ignore
    }
}