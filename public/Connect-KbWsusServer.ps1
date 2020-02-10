function Connect-KbWsusServer {
    <#
    .SYNOPSIS
        Creates a reusable connection to a WSUS Server.

    .DESCRIPTION
        Creates a reusable connection to a WSUS Server. Only one concurrent connection is allowed.

    .PARAMETER ComputerName
        Name of WSUS server. If not value is given, an attempt to read the value from registry will occur.

    .PARAMETER SecureConnection
        Determines if a secure connection will be used to connect to the WSUS server. If not used, then a non-secure
        connection will be used.

    .PARAMETER Port
        Port number to connect to. Default is Port "80" if not used. Accepted values are "80","443","8350" and "8351"

    .PARAMETER Credential
        The optional alternative credential to be used when connecting to ComputerName.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Author: Chrissy LeMaire (@cl), netnerds.net
        Copyright: (c) licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .EXAMPLE
        PS C:\> Connect-KbWsusServer -ComputerName server1

        This command will make the connection to the WSUS using an unsecure port (Default:80).

    .EXAMPLE
        PS C:\> Connect-KbWsusServer -ComputerName server1 -SecureConnection
        PS C:\> Get-KbUpdate -Pattern KB2764916

        This command will make a secure connection (Default: 443) to a WSUS server.

        Then use Wsus as a source for Get-KbUpdate.

    .EXAMPLE
        PS C:\> Connect-KbWsusServer -ComputerName server1 -port 8530

        This command will make the connection to the WSUS using a defined port 8530.
    #>
    [cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [Alias("WsusServer")]
        [PSFComputer]$ComputerName,
        [pscredential]$Credential,
        [switch]$SecureConnection,
        [ValidateSet("80", "443", "8530", "8531" )]
        [int]$Port = 80,
        [switch]$EnableException
    )
    begin {
        If ($IsLinux -or $IsMacOs) {
            return
        }
        try {
            Import-Module -Name PoshWSUS -ErrorAction Stop
        } catch {
            Import-Module "$script:ModuleRoot\library\PoshWSUS"
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
        try {
            $script:ConnectedWsus = Connect-PSWSUSServer -WSUSserver $ComputerName -SecureConnection:$SecureConnection -Port $Port -WarningAction SilentlyContinue -WarningVariable warning
            # Handle the way PoshWSUS deals with errors
            if ($warning) {
                $currenterror = (Get-Variable -Name Error -Scope 2 -ValueOnly) | Select-Object -First 1
                throw $currenterror
            } else {
                $script:ConnectedWsus
            }
        } catch {
            Stop-PSFFunction -Message "Failure" -EnableException:$EnableException -ErrorRecord $_
        }
    }
}