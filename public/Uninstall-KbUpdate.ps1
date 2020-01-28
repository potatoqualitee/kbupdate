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

    .PARAMETER InputObject
        Allows results to be piped in from Get-KbInstalledUpdate

    .PARAMETER NoQuiet
        By default, we add a /quiet switch to the argument list to ensure the command can run from the command line.

        Some commands may not support this switch, however, so to remove it use NoQuiet.

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
        PS C:\> Get-KbUpdate -Pattern 4498951 | Install-KbUpdate -Type SQL -ComputerName sql2017

        Installs KB4534273 from the C:\temp directory on sql2017
#>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    param (
        [string[]]$ComputerName = $env:ComputerName,
        [PSCredential]$Credential,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$HotfixId,
        [Parameter(ValueFromPipeline)]
        [pscustomobject]$InputObject,
        # PERHAPS ADD ARGUMENTLIST
        [switch]$NoQuiet,
        [switch]$EnableException
    )
    process {
        if (-not $PSBoundParameters.HotfixId -and -not $PSBoundParameters.InputObject.HotfixId) {
            Stop-Function -EnableException:$EnableException -Message "You must specify either HotfixId or pipe in the results from Get-KbInstalledUpdate"
            return
        }

        foreach ($hotfix in $HotfixId) {
            if (-not $hotfix.ToUpper().StartsWith("KB") -and $PSBoundParameters.HotfixId) {
                $hotfix = "KB$hotfix"
            }

            foreach ($computer in $ComputerName) {
                $exists = Get-KbInstalledUpdate -Pattern $hotfix -ComputerName $computer
                if (-not $exists) {
                    Stop-Function -EnableException:$EnableException -Message "$hotfix is not installed on $computer" -Continue
                } else {
                    $InputObject += $exists
                }
            }

            foreach ($update in $InputObject) {
                $computer = $update.ComputerName
                $hotfix = $update.HotfixId

                if (-not (Test-ElevationRequirement -ComputerName $computer)) {
                    Stop-Function -Message "To run this command locally, you must run as admin." -Continue -EnableException:$EnableException
                }

                if ($update.ProviderName -eq "Programs") {
                    $path = $update.UninstallString -match '^(".+") (/.+) (/.+)'

                    if ($path -match 'msiexec') {
                        $path -match '(\w+) (/i)({.*})'
                    }
                    $program = $matches[1]
                    $argumentlist = "$($matches[2, 3, 4, 5, 6, 7])".Trim()
                }

                if ($argumentlist -notmatch "/quiet" -and -not $NoQuiet) {
                    $argumentlist = "$argumentlist /quiet"
                }

                # I tried to get this working using DSC but in end end, Start-Process was it
                if ($PSCmdlet.ShouldProcess($computer, "Uninstalling Hotfix $hotfix by executing $program $argumentlist")) {
                    try {
                        Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ScriptBlock {
                            param (
                                $Program,
                                $ArgumentList,
                                $hotfix,
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
                                    $output = "$output`n`nThe exit code is -2068052310 which may mean that you need to mount the SQL Server ISO so the uninstaller can find the setup files."
                                }
                                0 {
                                    $output = "$output`n`nYou have successfully uninstalled $HotfixId"
                                }
                            }

                            [pscustomobject]@{
                                ComputerName = $env:ComputerName
                                HotfixID     = $hotfix
                                Results      = $output
                                ExitCode     = $results.ExitCode
                            }
                        } -ArgumentList $Program, $ArgumentList, $hotfix, $VerbosePreference -ErrorAction Stop | Select-Object -Property * -ExcludeProperty PSComputerName, RunspaceId
                    } catch {
                        Stop-Function -Message "Failure on $computer" -ErrorRecord $_ -EnableException:$EnableException
                    }
                }
            }
        }
    }
}