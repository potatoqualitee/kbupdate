function Start-JobProcess {
    [CmdletBinding()]
    param(
        $ComputerName,
        [PSCredential]$Credential,
        [scriptblock]$ScriptBlock,
        $ArgumentList,
        [Parameter(ValueFromPipeline)]
        [System.Management.Automation.Job[]]$Job,
        [string]$Activity = "Processing jobs",
        [string]$Status = "making progress"
    )
    begin {
        if ($Credential.UserName) {
            $null = $PSDefaultParameterValues["*:Credential"] = $Credential
        }
    }
    process {
        $jobs += $InputObject
        if ($ComputerName -and $ScriptBlock) {
            Write-PSFMessage -Level Verbose -Message "Processing computers and starting jobs"
            foreach ($computer in $ComputerName) {
                if ($ArgumentList["ComputerName"]) {
                    $ArgumentList.Remove("ComputerName")
                }
                $ArgumentList["ComputerName"] = $computer
                $jobs += Start-Job -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
            }
        } elseif ($ScriptBlock) {
            $jobs += Start-Job -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
        }
    }
    end {
        try {
            Write-PSFMessage -Level Verbose -Message "Processing jobs"
            while ($kbjobs = Get-Job | Where-Object Name -in $jobs.Name) {
                # People really just want to know that it's still going and DSC doesn't give us a proper status
                # Just shoooooooooooooooooow a progress bar
                if ($added -eq 100) {
                    $added = 0
                }
                $added++
                $percentcomplete = ($added / 100 * 100)
                if ($percentcomplete -lt 0 -or $percentcomplete -gt 100) {
                    $percentcomplete = 0
                }
                $progressparms = @{
                    Activity        = $Activity
                    Status          = "Still $Status on $($kbjobs.Name -join ', '). Please enjoy the progress bar."
                    PercentComplete = $percentcomplete
                }
                Write-Progress @progressparms
                foreach ($item in $kbjobs) {
                    try {
                        $item | Receive-Job -OutVariable kbjob 4>$verboseoutput | Select-Object -Property * -ExcludeProperty RunspaceId
                    } catch {
                        Stop-PSFFunction -Message "Failure on $($item.Name)" -ErrorRecord $PSItem -EnableException:$EnableException -Continue
                    }

                    if ($kbjob.Output) {
                        foreach ($msg in $kbjob.Output) {
                            Write-PSFMessage -Level Debug -Message "$msg"
                        }
                    }
                    if ($kbjob.Warning) {
                        foreach ($msg in $kbjob.Warning) {
                            if ($msg) {
                                # too many extra spaces, baw
                                while ("$msg" -match "  ") {
                                    $msg = "$msg" -replace "  ", " "
                                }
                            }
                        }
                        if ($msg) {
                            Write-PSFMessage -Level Warning -Message "$msg"
                        }
                    }
                    if ($kbjob.Verbose) {
                        foreach ($msg in $kbjob.Verbose) {
                            if ($msg) {
                                # too many extra spaces, baw
                                while ("$msg" -match "  ") {
                                    $msg = "$msg" -replace "  ", " "
                                }
                            }
                        }

                        if ($msg) {
                            Write-PSFMessage -Level Verbose -Message "$msg"
                        }
                    }


                    if ($verboseoutput) {
                        foreach ($msg in $verboseoutput) {
                            if ($msg) {
                                # too many extra spaces, baw
                                while ("$msg" -match "  ") {
                                    $msg = "$msg" -replace "  ", " "
                                }
                            }
                        }
                        if ($msg) {
                            Write-PSFMessage -Level Verbose -Message "$msg"
                        }
                    }

                    if ($kbjob.Debug) {
                        foreach ($msg in $kbjob.Debug) {
                            Write-PSFMessage -Level Debug -Message "$msg"
                        }
                    }

                    if ($kbjob.Information) {
                        foreach ($msg in $kbjob.Information) {
                            if ($msg) {
                                Write-PSFMessage -Level Verbose -Message "$msg"
                            }
                        }
                    }
                }
                $null = Remove-Variable -Name kbjob
                foreach ($kbjob in ($kbjobs | Where-Object State -ne 'Running')) {
                    Write-PSFMessage -Level Verbose -Message "Finished $Status on $($kbjob.Name)"
                    if ($added -eq 100) {
                        $added = 0
                    }
                    $null = $added++
                    $done = $kbjobs | Where-Object Name -ne $kbjob.Name
                    if (-not $done) {
                        $done = $kbjobs
                    }

                $percentcomplete = ($added / 100 * 100)
                if ($percentcomplete -lt 0 -or $percentcomplete -gt 100) {
                    $percentcomplete = 0
                }

                    $progressparms = @{
                        Activity        = $Activity
                        Status          = "Still $Status on $($done.Name -join ', '). Please enjoy the progress bar."
                        PercentComplete = $percentcomplete
                    }

                    Write-Progress @progressparms
                    $jorbs | Where-Object Name -eq $kbjob.name
                    $kbjob | Remove-Job
                }
                Start-Sleep -Seconds 1
            }
            Write-Progress -Activity $Activity -Completed
        } catch {
            Stop-PSFFunction -Message "Failure on $hostname" -ErrorRecord $PSItem -EnableException:$EnableException
        }
    }
}