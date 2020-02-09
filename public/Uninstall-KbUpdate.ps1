function Uninstall-KbUpdate {
    <#
    .SYNOPSIS
        Uninstalls KB updates on Windows-based systems

    .DESCRIPTION
        Uninstalls KB updates on Windows-based systems

        Note that sometimes, an uninstall will leave registry entries and Get-KbInstalledUpdate will report the product is installed. This is the behavior of some patches and happens even when using the Windows uninstall GUI.

    .PARAMETER ComputerName
        Used to connect to a remote host

    .PARAMETER Credential
        The optional alternative credential to be used when connecting to ComputerName

    .PARAMETER HotfixId
        The HotfixId of the patch

    .PARAMETER InputObject
        Allows results to be piped in from Get-KbInstalledUpdate

    .PARAMETER ArgumentList
        Allows you to override our automatically determined ArgumentList

    .PARAMETER NoQuiet
        By default, we add a /quiet switch to the argument list to ensure the command can run from the command line.

        Some commands may not support this switch, however, so to remove it use NoQuiet.

        Not required if you use ArgumentList.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Author: Chrissy LeMaire (@cl), Jess Pomfret (@jpomfret)
        Copyright: (c) licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .EXAMPLE
        PS C:\> Uninstall-KbUpdate -ComputerName sql2017 -HotfixId kb4498951

        Uninstalls kb4498951 on sql2017

    .EXAMPLE
        PS C:\> Uninstall-KbUpdate -ComputerName sql2017 -HotfixId kb4498951 -Confirm:$false

        Uninstalls kb4498951 on sql2017 without prompts

    .EXAMPLE
        PS C:\>  Get-KbInstalledUpdate -ComputerName server23, server24 -Pattern kb4498951 | Uninstall-KbUpdate

        Uninstalls kb4498951 from server23 and server24

    .EXAMPLE
        PS C:\> Uninstall-KbUpdate -ComputerName sql2017 -HotfixId KB4534273 -WhatIf

        Shows what would happen if the command were to run but does not execute any changes

    .EXAMPLE
        PS C:\> Install-KbUpdate -ComputerName sql2017 -FilePath \\dc\sql\windows10.0-kb4486129-x64_0b61d9a03db731562e0a0b49383342a4d8cbe36a.msu
        PS C:\> Get-KbInstalledUpdate -Pattern kb4486129 -ComputerName sql2017 | Uninstall-KbUpdate

        Quick lil example to show an install, followed by an uninstall
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
                -2068643839 {
                    $output = "$output`n`nThe exit code suggests that you need to mount the SQL Server ISO so the uninstaller can find the setup files."
                }
                -2068709375 {
                    $output = "$output`n`nYou likely need to reboot $env:ComputerName."
                }
                -2067919934 {
                    $output = "$output`n`nThe exit code suggests that something is corrupt. See if this tutorial helps:  http://www.sqlcoffee.com/Tips0026.htm"
                }
                3010 {
                    $output = "You have successfully uninstalled $Name. A restart is now required to finalize the uninstall."
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
                ExitCode     = $results.ExitCode
                Results      = $output
            }
        }
    }
    process {
        if (-not $PSBoundParameters.HotfixId -and -not $PSBoundParameters.InputObject.HotfixId) {
            # some just wont have hotfix i guess but you can pipe from the command and still get this error so fix the erorr
            Stop-PSFFunction -EnableException:$EnableException -Message "You must specify either HotfixId or pipe in the results from Get-KbInstalledUpdate"
            return
        }

        if ($IsLinux -or $IsMacOs) {
            Stop-PSFFunction -Message "This command using remoting and only supports Windows at this time" -EnableException:$EnableException
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
                    <#
                    I have so many notes from so many different attempts to address this flawlessly

                    GET-PACKAGE
                    Get-Package | Uninstall-Package is buggy per https://stackoverflow.com/questions/54740151/get-package-notepad-uninstall-package-force-not-working
                    The Uninstall-Package cmdlet won't work with these entries (i.e. ones where "ProviderName" is "Programs").

                    Another BIG gotcha with PackageManagement/PowerShellGet Modules that I ran into recently - if you uninstall a Program that was installed via PackageManagement via the Control Panel GUI,
                    the Get-Package cmdlet will still show it as installed until you run the Uninstall-Package cmdlet on the erroneous entry.

                    PKGMGR
                    http://msiworld.blogspot.com/2012/04/silent-install-and-uninstall-of-msu.html
                    pkgmgr = DISM
                    $ArgumentList = "/up:$installname"

                    WUSA
                    Newer versions of win10 doesnt support old-style wusa, go for DISM  /quiet /norestart
                    https://support.microsoft.com/en-us/help/934307/description-of-the-windows-update-standalone-installer-in-windows

                    MSIEXEC WITH PACKAGE GUID + GUID OF PATCH
                    Could never figure out how to get GUID-OF-PRODUCT
                    https://docs.microsoft.com/en-us/windows/win32/msi/uninstalling-patches?redirectedfrom=MSDN
                    Msiexec /i {installpath_of_product} MSIPATCHREMOVE={installpath_of_patch} /qb
                    Msiexec /package {GUID-OF-PRODUCT} /uninstall {GUID_OF_PATCH} /passive

                    WMIC
                    Took too long
                    wmic product where "name like 'Java 8%%'" and not name 'Java 8 Update 101%%'" call uninstall /nointeractive

                    VARIOUS ARTISTS
                    provides various ways from https://support.symantec.com/us/en/article.howto42396.html
                    introduced me to msipatchremove and how to reverse enginer guid
                    https://docs.microsoft.com/en-us/office/troubleshoot/installation/automate-uninstall-office-update

                    DISM
                    props for highlighting that the installversion is important for win10
                    this allowed me to find the InstallName
                    https://social.technet.microsoft.com/Forums/Lync/en-US/f6594e00-2400-4276-85a1-fb06485b53e6/issues-with-wusaexe-and-windows-10-enterprise?forum=win10itprogeneral
                    #>
                    $installname = $update.InstallName
                    if (-not $InstallName) {
                        Stop-PSFFunction -EnableException:$EnableException -Message "Couldn't figure out a way to install $hotfix. Please provide -FileName or reinstall." -Continue
                    }
                    $program = "dism"
                    $ArgumentList = "/Online /Remove-Package /PackageName:$installname /quiet /norestart"
                }

                # I tried to get this working using DSC but in end end, a Start-Process equivalent was it for the convenience of not having to specify a filename, tho that can be added as a backup
                if ($PSCmdlet.ShouldProcess($computer, "Uninstalling Hotfix $hotfix by executing $program $ArgumentList")) {
                    try {
                        Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ScriptBlock $programscriptblock -ArgumentList $Program, $ArgumentList, $hotfix, $update.Name, $VerbosePreference -ErrorAction Stop | Select-Object -Property * -ExcludeProperty PSComputerName, RunspaceId
                    } catch {
                        Stop-PSFFunction -Message "Failure on $computer" -ErrorRecord $_ -EnableException:$EnableException
                    }
                }
            }
        }
    }
}