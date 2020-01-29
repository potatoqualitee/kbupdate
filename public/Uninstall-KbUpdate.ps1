function Uninstall-KbUpdate {
    <#
    .SYNOPSIS
        Uninstalls KB updates

    .DESCRIPTION
        Uninstalls KB updates

    .PARAMETER ComputerName
        Used to connect to a remote host

    .PARAMETER Credential
        The optional alternative credential to be used when connecting to ComputerName

    .PARAMETER HotfixId
        The HotfixId of the patch. This needs to be updated to be more in-depth.

    .PARAMETER ArgumentList
        Allows you to override our automatically determined ArgumentList

    .PARAMETER NoQuiet
        By default, we add a /quiet switch to the argument list to ensure the command can run from the command line.

        Some commands may not support this switch, however, so to remove it use NoQuiet.

        Not required if you use ArgumentList.

    .PARAMETER InputObject
        Allows results to be piped in from Get-KbInstalledUpdate

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Author: Chrissy LeMaire (@cl), netnerds.net
        Copyright: (c) licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .EXAMPLE
        PS C:\> Uninstall-KbUpdate -ComputerName sql2017 -HotfixId kb4498951

        Uninstalls kb4498951 on sql2017

    .EXAMPLE
        PS C:\>  Get-KbInstalledUpdate -ComputerName server23, server24 -Pattern kb4498951 | Uninstall-KbUpdate

        Uninstalls kb4498951 from server23 and server24

    .EXAMPLE
        PS C:\> Uninstall-KbUpdate -ComputerName sql2017 -HotfixId KB4534273 -WhatIf

        Shows what would happen if the command were to run but does not execute any changes
#>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    param (
        [string[]]$ComputerName = $env:ComputerName,
        [PSCredential]$Credential,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$HotfixId,
        [Parameter(ValueFromPipeline)]
        [pscustomobject]$InputObject,
        [string]$ArgumentList,
        [switch]$NoQuiet,
        [switch]$EnableException
    )
    process {
        if (-not $PSBoundParameters.HotfixId -and -not $PSBoundParameters.InputObject.HotfixId) {
            Stop-PSFFunction -EnableException:$EnableException -Message "You must specify either HotfixId or pipe in the results from Get-KbInstalledUpdate"
            return
        }

        foreach ($hotfix in $HotfixId) {
            if (-not $hotfix.ToUpper().StartsWith("KB") -and $PSBoundParameters.HotfixId) {
                $hotfix = "KB$hotfix"
            }

            foreach ($computer in $PSBoundParameters.ComputerName) {
                $exists = Get-KbInstalledUpdate -Pattern $hotfix -ComputerName $computer
                if (-not $exists) {
                    Stop-PSFFunction -EnableException:$EnableException -Message "$hotfix is not installed on $computer" -Continue
                } else {
                    $InputObject += $exists
                }
            }

            foreach ($update in $InputObject) {
                $computer = $update.ComputerName
                $hotfix = $update.HotfixId

                if (-not (Test-ElevationRequirement -ComputerName $computer)) {
                    Stop-PSFFunction -Message "To run this command locally, you must run as admin." -Continue -EnableException:$EnableException
                }
                # GOTTA ADD BACK THE SHIT

                if (-not $update.UninstallString) {
                    Stop-PSFFunction -Message "Uninstall string cannot be found, skipping $($update.Name) on $computername" -Continue -EnableException:$EnableException
                }

                if ($update.ProviderName -eq "Programs") {
                    $path = $update.UninstallString -match '^(".+") (/.+) (/.+)'
                    $program = $matches[1]
                    if (-not $path) {
                        $program = Split-Path $update.UninstallString
                    }
                    if (-not $PSBoundParameters.ArgumentList) {
                        $ArgumentList = $update.UninstallString.Replace($program, "")
                    }
                }

                if ($ArgumentList -notmatch "/quiet" -and -not $NoQuiet -and -not $PSBoundParameters.ArgumentList) {
                    $ArgumentList = "$ArgumentList /quiet"
                }

                # I tried to get this working using DSC but in end end, a Start-Process equivalent was it
                if ($PSCmdlet.ShouldProcess($computer, "Uninstalling Hotfix $hotfix by executing $program $ArgumentList")) {
                    try {
                        Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ScriptBlock {
                            param (
                                $Program,
                                $ArgumentList,
                                $hotfix,
                                $Name,
                                $VerbosePreference
                            )

                            Function Invoke-UninstallCommand ($Program, $ArgumentList) {
                                $pinfo = New-Object System.Diagnostics.ProcessStartInfo
                                $pinfo.FileName = $Program
                                $pinfo.RedirectStandardError = $true
                                $pinfo.RedirectStandardOutput = $true
                                $pinfo.UseShellExecute = $false
                                $pinfo.Arguments = $ArgumentList
                                $p = New-Object System.Diagnostics.Process
                                $p.StartInfo = $pinfo
                                $null = $p.Start()
                                $p.WaitForExit()
                                [pscustomobject]@{
                                    stdout   = $p.StandardOutput.ReadToEnd()
                                    stderr   = $p.StandardError.ReadToEnd()
                                    ExitCode = $p.ExitCode
                                }
                            }

                            Write-Verbose -Message "Program = $Program"
                            Write-Verbose -Message "ArgumentList = $ArgumentList"

                            $results = Invoke-UninstallCommand -Program $Program -ArgumentList $ArgumentList
                            $output = $results.stdout.Trim()

                            # -2067919934 is reboot needed but the output already tells you to reboot
                            switch ($results.ExitCode) {
                                -2068052310 {
                                    $output = "$output`n`nThe exit code suggests that you need to mount the SQL Server ISO so the uninstaller can find the setup files."
                                }
                                0 {
                                    if ($output.Trim()) {
                                        $output = "$output`n`nYou have successfully uninstalled $Name"
                                    } else {
                                        if ($Name) {
                                            $output = "$Name has been successfully uninstalled"
                                        }
                                    }
                                }
                            }

                            [pscustomobject]@{
                                ComputerName = $env:ComputerName
                                Name         = $Name
                                HotfixID     = $hotfix
                                Results      = $output
                                ExitCode     = $results.ExitCode
                            }
                        } -ArgumentList $Program, $ArgumentList, $hotfix, $update.Name $VerbosePreference -ErrorAction Stop | Select-Object -Property * -ExcludeProperty PSComputerName, RunspaceId
                    } catch {
                        Stop-PSFFunction -Message "Failure on $computer" -ErrorRecord $_ -EnableException:$EnableException
                    }
                }
            }
        }
    }
}