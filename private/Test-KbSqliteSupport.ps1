function Test-KbSqliteSupport {
    <#
    .SYNOPSIS
        Determines whether the bundled native SQLite provider can be loaded on the current system.

    .DESCRIPTION
        kbupdate reads its local update database through PSSQLite, which loads a native
        SQLite.Interop.dll matching the running process architecture. PSSQLite ships native
        libraries for win-x64, win-x86, linux-x64, and osx-x64 but not for ARM64, so on a
        native ARM64 PowerShell process the provider fails to load with
        "An attempt was made to load a program with an incorrect format" (HRESULT 0x8007000B).

        This helper probes the provider once with a trivial query and caches the result in
        $script:sqlitesupport so callers can degrade gracefully instead of surfacing the raw
        provider error. It performs no writes and is safe to call repeatedly.

    .EXAMPLE
        PS C:\> Test-KbSqliteSupport

        Returns $true when the local database can be queried, otherwise $false.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -ne $script:sqlitesupport) {
        return $script:sqlitesupport
    }

    try {
        $null = Invoke-SqliteQuery -DataSource $script:basedb -Query "SELECT 1 AS Probe" -ErrorAction Stop
        $script:sqlitesupport = $true
    } catch {
        Write-PSFMessage -Level Verbose -Message "Native SQLite provider is unavailable on this system: $($PSItem.Exception.Message)"
        $script:sqlitesupport = $false
    }

    $script:sqlitesupport
}
