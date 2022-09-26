function Start-BitsJobProcess {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [Microsoft.BackgroundIntelligentTransfer.Management.BitsJob[]]$InputObject,
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
        $bs = $jobs | Where-Object BytesTotal -ne 18446744073709551615
        $bytestotal = ($bs.BytesTotal | Measure-Object -Sum).Sum
        $bstotal = [math]::Round(($bytestotal / 1MB),2)

        while ($bitsjobs = (Get-BitsTransfer | Where-Object Description -match kbupdate)) {
            $bjs = $bitsjobs | Where-Object BytesTotal -ne 18446744073709551615
            $bjbytestotal = ($bjs.BytesTransferred | Measure-Object -Sum).Sum
            $mbjtotal = [math]::Round(($bjbytestotal / 1MB),2)

            $currentcount = $bitsjobs.FileList.Count
            $completed = $totalfiles - $currentcount
            # I literally can't do math and have been working on this for an hour
            $percentcomplete = 100 - $(($currentcount / $totalfiles) * 100)
            if ($percentcomplete -gt 100 -or $percentcomplete -lt 0) {
                $percentcomplete = 0
            }
            $progressparms = @{
                Activity        = "Downloaded $mbjtotal MB of at least $bstotal MB total from $($bs.count) files in this batch."
                Status          = "$completed of $totalfiles files completed"
                PercentComplete = 100 - $(($currentcount / $totalfiles) * 100)
            }
            if ($oldmbjtotal -ne $mbjtotal) {
                Write-PSFMessage -Level Debug -Message "Current count: $currentcount files"
                Write-PSFMessage -Level Debug -Message "Processing $totalfiles total files"
                Write-PSFMessage -Level Debug -Message "$completed have been completed"
                Write-PSFMessage -Level Debug -Message "$(($currentcount / $totalfiles) * 100) percent left"
                $oldmbjtotal = $mbjtotal
                $bs = $jobs | Where-Object BytesTotal -ne 18446744073709551615
                $bytestotal = ($bs.BytesTotal | Measure-Object -Sum).Sum
                Write-Progress @progressparms
                Start-Sleep -Seconds 1
            }

            foreach ($bitsjob in $bitsjobs) {
                try {
                    $title = $bitsjob.Description.Replace("kbupdate - ", "")
                    switch ($bitsjob.JobState) {
                        "Transferred" {
                            foreach ($filename in $bitsjob.FileList.LocalName) {
                                $null = Complete-BitsTransfer -BitsJob $bitsjob
                                Write-PSFMessage -Level Verbose -Message "Sweet, $filename is done."
                                do {
                                    Start-Sleep -Milliseconds 200
                                } while (-not (Test-Path -Path $filename))
                                Get-ChildItem $filename
                            }
                        }
                        "Suspended" {
                            foreach ($filename in $bitsjob.FileList.LocalName) {
                                Write-PSFMessage -Level Verbose -Message "Oof, $filename is suspended. Retrying."
                            }
                            $null = $bitsjob | Resume-BitsTransfer
                        }
                        "Error" {
                            foreach ($file in $bitsjob.FileList.LocalName) {
                                Write-PSFMessage -Level Verbose -Message "Oh no, $filename has errored."
                                Stop-PSFFunction -Message "Failure downloading $title (file) | $($bitsjob.ErrorDescription)" -Continue
                            }
                            $null = $bitsjob | Complete-BitsTransfer -ErrorAction Ignore
                        }
                    }
                } catch {
                    Stop-PSFFunction -Message "Failure on $hostname" -Continue
                }
            }
        }
        Write-Progress -Activity "Downloading $totalfiles total files" -Completed
    }
}