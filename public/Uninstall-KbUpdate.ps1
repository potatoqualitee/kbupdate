function Uninstall-KbUpdate {

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
        if (-not $PSBoundParameters.HotfixId -and -not $PSBoundParameters.InputObject) {
            Stop-Function -EnableException:$EnableException -Message "You must specify either HotfixId or pipe in the results from Get-KbInstalledUpdate"
            return
        }

        # moved this from begin because it can be piped in which can only be seen in process
        if (-not $HotfixId.ToUpper().StartsWith("KB") -and $PSBoundParameters.HotfixId) {
            $HotfixId = "KB$HotfixId"
        }

        if ($hotfixID) {
            $InputObject = Get-KbInstalledUpdate -Pattern $HotfixId -ComputerName $ComputerName
        }

        foreach ($update in $InputObject) {
            $computer = $update.ComputerName
            $HotfixId = $update.HotfixId

            if ($update.ProviderName -eq "Programs") {
                $path = $update.UninstallString -match '^(".+") (/.+) (/.+)'

                if ($path -match 'msiexec') {
                    $path -match '(\w+) (/i)({.*})'
                    write-warning hello
                }
                $program = $matches[1]
                $argumentlist = "$($matches[2, 3, 4, 5, 6, 7])".Trim()
            }

            if ($argumentlist -notmatch "/quiet" -and -not $NoQuiet) {
                $argumentlist = "$argumentlist /quiet"
            }

            if ($PSCmdlet.ShouldProcess($computer, "Uninstalling Hotfix $HotfixId")) {
                try {
                    Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ScriptBlock {
                        param (
                            $Program,
                            $ArgumentList,
                            $HotfixId,
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

                        [pscustomobject]@{
                            ComputerName = $env:ComputerName
                            HotfixID     = $HotfixId
                            Results      = $results.stdout.Trim()
                            ExitCode     = $results.ExitCode
                        }
                    } -ArgumentList $Program, $ArgumentList, $HotfixId, $VerbosePreference -ErrorAction Stop | Select-Object -Property * -ExcludeProperty PSComputerName, RunspaceId
                } catch {
                    Stop-Function -Message "Failure on $computer" -ErrorRecord $_ -EnableException:$EnableException
                }
            }
        }
    }
}