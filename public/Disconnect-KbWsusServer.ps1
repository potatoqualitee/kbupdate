function Disconnect-KbWsusServer {
    <#
    .SYNOPSIS
        Disconnects from all connected WSUS Servers.

    .DESCRIPTION
        Disconnects from all connected WSUS Servers.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Author: Chrissy LeMaire (@cl), netnerds.net
        Copyright: (c) licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .EXAMPLE
        PS C:\> Disconnect-KbWsusServer

        Disconnects from all connected WSUS Servers.
    #>
    [cmdletbinding()]
    param(
        [switch]$EnableException
    )
    begin {
        If ($IsLinux -or $IsMacOs) {
            return
        }

        if (-not (Get-Command Disconnect-PSWSUSServer -ErrorAction Ignore)) {
            try {
                Import-Module -Name PoshWSUS -ErrorAction Stop
            } catch {
                Import-Module "$script:ModuleRoot\library\PoshWSUS"
            }
        }

        # load the DLLs, does not load properly by default
        $path = Split-Path -Path (Get-Module -Name PoshWSUS).Path
        $arch = "$env:PROCESSOR_ARCHITECTURE".Replace("AMD", "")
        $dir = "$path\Libraries\x$($arch)"
        if (Test-Path -Path $dir) {
            foreach ($file in Get-ChildItem -Path $dir) {
                try {
                    Add-Type -Path $file.Fullname -ErrorAction Stop
                } catch {
                    # nbd
                }
            }
        }
    }
    process {
        if (Test-PSFPowerShell -Edition Core) {
            Stop-PSFFunction -Message "Core not supported :( WSUS DLLs would have to support it, so doesn't seem likely." -EnableException:$EnableException
            return
        }

        if ($script:ConnectedWsus) {
            try {
                $null = Remove-Variable -Scope Script -Name ConnectedWsus
                $null = Disconnect-PSWSUSServer -WarningAction SilentlyContinue -WarningVariable warning
                if (-not $script:internet) {
                    Write-PSFMessage -Level Verbose -Message "Internet connection not detected. Setting source for Get-KbUpdate to Database."
                    $null = Set-PSFConfig -FullName kbupdate.app.source -Value Database
                } else {
                    Write-PSFMessage -Level Verbose -Message "Internet connection detected. Setting source for Get-KbUpdate to Web and Database."
                    $null = Set-PSFConfig -FullName kbupdate.app.source -Value Web, Database
                }

                # Handle the way PoshWSUS deals with errors
                if ($warning) {
                    $currenterror = (Get-Variable -Name Error -Scope 2 -ValueOnly) | Select-Object -First 1
                    throw $currenterror
                }
                Write-PSFMessage -Level Output -Message "Disconnected from all WSUS servers."
            } catch {
                Stop-PSFFunction -Message "Failure" -EnableException:$EnableException -ErrorRecord $_
            }
        } else {
            Write-PSFMessage -Level Output -Message "Not connected to any WSUS servers."
        }
    }
}