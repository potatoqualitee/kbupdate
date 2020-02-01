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


    .EXAMPLE
        PS C:\> Uninstall-KbUpdate -ComputerName sql2017 -HotfixId KB4534273 -Confirm:$false

        Without prompts...
#>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param (
        [PSFComputer[]]$ComputerName = $env:ComputerName,
        [PSCredential]$Credential,
        [Alias("Name", "KBUpdate", "Id")]
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$HotfixId,
        [Parameter(ValueFromPipeline)]
        [pscustomobject]$InputObject,
        [string]$ArgumentList,
        [switch]$NoQuiet,
        [switch]$EnableException
    )
    begin {
        $programscriptblock = {
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
            # Perhaps suggest people check out C:\Windows\Logs\CBS\CBS.log
            # Only package owners can remove package: Package_10_for_KB4532947~31bf3856ad364e35~amd64~~10.0.1.2565 [HRESULT = 0x80070005 - E_ACCESSDENIED]

            <#
            0 { "Uninstallation command triggered successfully" }
            2 { "You don't have sufficient permissions to trigger the command on $Computer" }
            3 { "You don't have sufficient permissions to trigger the command on $Computer" }
            8 { "An unknown error has occurred" }
            9 { "Path Not Found" }
            9 { "Invalid Parameter"}
            #>
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
        }
    }
    process {
        if (-not $PSBoundParameters.HotfixId -and -not $PSBoundParameters.InputObject.HotfixId) {
            # some just wont have hotfix i guess but you can pipe from the command and still get this error so fix the erorr
            Stop-PSFFunction -EnableException:$EnableException -Message "You must specify either HotfixId or pipe in the results from Get-KbInstalledUpdate"
            return
        }

        foreach ($hotfix in $HotfixId) {
            if (-not $hotfix.ToUpper().StartsWith("KB") -and $PSBoundParameters.HotfixId) {
                $hotfix = "KB$hotfix"
            }

            foreach ($computer in $PSBoundParameters.ComputerName) {
                $exists = Get-KbInstalledUpdate -Pattern $hotfix -ComputerName $computer -IncludeHidden
                if (-not $exists) {
                    Stop-PSFFunction -EnableException:$EnableException -Message "$hotfix is not installed on $computer" -Continue
                } else {
                    if ($exists.Summary -match "restart") {
                        Stop-PSFFunction -EnableException:$EnableException -Message "You must restart before you can uninstall $hotfix on $computer" -Continue
                    } else {
                        $InputObject += $exists
                    }
                }
            }

            foreach ($update in $InputObject) {
                $computer = $update.ComputerName
                $hotfix = $update.HotfixId

                if (-not (Test-ElevationRequirement -ComputerName $computer)) {
                    Stop-PSFFunction -Message "To run this command locally, you must run as admin." -Continue -EnableException:$EnableException
                }

                if ($update.UninstallString) {
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
                } else {
                    # props for highlighting that the installversion is important for win10
                    # this allowed me to find the InstallName
                    # https://social.technet.microsoft.com/Forums/Lync/en-US/f6594e00-2400-4276-85a1-fb06485b53e6/issues-with-wusaexe-and-windows-10-enterprise?forum=win10itprogeneral
                    $installname = $update.InstallName

                    # this can be done in PowerShell but I'm just gonna reuse that scriptblock
                    $program = "dism.exe"
                    $ArgumentList = "/Online /Remove-Package /PackageName:$installname /quiet /norestart"
                }

                # I tried to get this working using DSC but in end end, a Start-Process equivalent was it
                if ($PSCmdlet.ShouldProcess($computer, "Uninstalling Hotfix $hotfix by executing $program $ArgumentList")) {
                    try {
                        Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ScriptBlock $programscriptblock -ArgumentList $Program, $ArgumentList, $hotfix, $update.Name $VerbosePreference -ErrorAction Stop | Select-Object -Property * -ExcludeProperty PSComputerName, RunspaceId
                    } catch {
                        Stop-PSFFunction -Message "Failure on $computer" -ErrorRecord $_ -EnableException:$EnableException
                    }
                }
            }
        }
    }
}