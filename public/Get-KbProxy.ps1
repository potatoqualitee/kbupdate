function Get-KbProxy {
    <#
    .SYNOPSIS
        Gets the proxy configuration used by kbupdate.

    .DESCRIPTION
        Shows whether kbupdate uses a custom proxy or automatic system-proxy detection and whether an alternate proxy credential is configured for the current PowerShell session. The credential itself is never returned.

    .EXAMPLE
        PS C:\> Get-KbProxy

        Shows the active kbupdate proxy configuration without exposing the credential.
    #>
    [CmdletBinding()]
    param()

    $proxy = Get-PSFConfigValue -FullName kbupdate.app.proxy
    $proxyCredential = Get-PSFConfigValue -FullName kbupdate.app.proxycredential

    if ($proxy) {
        $mode = 'Custom'
    } else {
        $mode = 'Automatic'
    }

    [pscustomobject]@{
        Mode                     = $mode
        Proxy                    = $proxy
        CredentialConfigured     = [bool]$proxyCredential
        CredentialUserName       = if ($proxyCredential) { $proxyCredential.UserName } else { $null }
    }
}
