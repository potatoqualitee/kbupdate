function Connect-KbWsusServer {
    <#
    .SYNOPSIS
        Make the initial connection to a WSUS Server.

    .DESCRIPTION
        Make the initial connection to a WSUS Server. Only one concurrent connection is allowed.

    .PARAMETER ComputerName
        Name of WSUS server to connect to. If not value is given, an attempt to read the value from registry will occur.

    .PARAMETER SecureConnection
        Determines if a secure connection will be used to connect to the WSUS server. If not used, then a non-secure
        connection will be used.

    .PARAMETER Port
        Port number to connect to. Default is Port "80" if not used. Accepted values are "80","443","8350" and "8351"

    .PARAMETER Type
        Use the Web API or Database. Defaults to Web. Database is a bit faster but may not be as accurate.

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

        This command will make a secure connection (Default: 443) to a WSUS server.

    .EXAMPLE
        PS C:\> Connect-KbWsusServer -ComputerName server1 -port 8530

        This command will make the connection to the WSUS using a defined port 8530.

    .EXAMPLE
        PS C:\> Connect-KbWsusServer -ComputerName server1 -Type Database

        Connect to WSUS' database

    #>
    [cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [Alias("WsusServer")]
        [string]$ComputerName,
        [pscredential]$Credential,
        [switch]$SecureConnection,
        [ValidateSet("80", "443", "8530", "8531" )]
        [int]$Port = 80,
        [ValidateSet("Web", "Database")]
        [string]$Type = "Web",
        [switch]$EnableException
    )
    begin {
        # load that shit, does not load properly by default
        if ($Type -eq "Web") {
            Import-Module -Name PoshWSUS
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
    }
    process {
        if ($ComputerName.Count -gt 0 -and $PSBoundParameters.FilePath) {
            Stop-PSFFunction -EnableException:$EnableException -Message "You can only specify one KB when using FilePath"
            return
        }

        if (-not $PSBoundParameters.InputObject -and -not $PSBoundParameters.ComputerName) {
            Stop-PSFFunction -EnableException:$EnableException -Message "You must specify a KB name or pipe in results from Get-KbUpdate"
            return
        }
        try {
            if ($Type -eq "Web") {
                Connect-PSWSUSServer -WSUSserver $ComputerName -SecureConnection:$SecureConnection -Port $Port -WarningAction SilentlyContinue -WarningVariable warning
                if ($warning) {
                    $currenterror = Get-Variable -Name Error -Scope 2 -ValueOnly
                    $currenterror = $currenterror | Select-Object -First 1
                    throw $currenterror
                }
            } else {
                $script:WsusServer = $ComputerName
                $script:WsusServerCredential = $Credential
                Invoke-WsusDbQuery -Pattern "Test-Connection" -EnableException:$EnableException -Verbose:$Verbose
            }
        } catch {
            Stop-Function -Message "Failure" -EnableException:$EnableException -ErrorRecord $_
        }
    }
}