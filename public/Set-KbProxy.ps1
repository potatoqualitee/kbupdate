function Set-KbProxy {
    <#
    .SYNOPSIS
        Configures proxy behavior for kbupdate web requests.

    .DESCRIPTION
        Configures a custom proxy or automatic system-proxy detection for Get-KbUpdate and Save-KbUpdate. An alternate proxy credential can be kept in memory for the current PowerShell session. This command does not write the credential to disk.

        Per-command Proxy and ProxyCredential parameters override these settings for one call.

    .PARAMETER Proxy
        Custom proxy server URI used for catalog lookups and downloads.

    .PARAMETER AutoDetect
        Uses the operating system proxy configuration automatically. Supply ProxyCredential when the detected proxy requires a different account.

    .PARAMETER ProxyCredential
        Alternate credential used to authenticate to the custom or automatically detected proxy. The credential remains in memory only for the current PowerShell session.

    .EXAMPLE
        PS C:\> Set-KbProxy -Proxy http://proxy.contoso.com:8080 -ProxyCredential (Get-Credential)

        Uses a custom proxy and alternate credential for later kbupdate commands in this PowerShell session.

    .EXAMPLE
        PS C:\> Set-KbProxy -AutoDetect -ProxyCredential (Get-Credential)

        Detects the system proxy automatically and uses an alternate credential for it.

    .EXAMPLE
        PS C:\> Set-KbProxy -AutoDetect

        Returns to automatic system-proxy detection with the current user's default credentials.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Manual', SupportsShouldProcess, ConfirmImpact = 'Low')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Manual')]
        [uri]$Proxy,
        [Parameter(Mandatory, ParameterSetName = 'Automatic')]
        [switch]$AutoDetect,
        [Parameter(ParameterSetName = 'Manual')]
        [Parameter(ParameterSetName = 'Automatic')]
        [pscredential]$ProxyCredential
    )

    if (-not $PSCmdlet.ShouldProcess('kbupdate proxy configuration', "Use $($PSCmdlet.ParameterSetName.ToLowerInvariant()) proxy settings")) {
        return
    }

    if ($PSCmdlet.ParameterSetName -eq 'Manual') {
        $configuredProxy = $Proxy
    } else {
        $configuredProxy = $null
    }

    $null = Set-PSFConfig -FullName kbupdate.app.proxy -Value $configuredProxy
    $null = Set-PSFConfig -FullName kbupdate.app.proxycredential -Value $ProxyCredential

    Get-KbProxy
}
