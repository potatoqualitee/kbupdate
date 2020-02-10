function Set-PSWsusConfigProxyServer {
<#
.SYNOPSIS
	This cmdlet sets whether to use a proxy to download updates.
	
.PARAMETER UseProxy
    Sets whether to use a proxy to download updates. 
    $true to use a proxy to download updates, otherwise $false.
    To use a proxy you must specify the proxy server name and port number to use, as well as the user credentials if necessary.

.PARAMETER ProxyName
    The name of the proxy server to use to download updates. The name must be less than 256 characters. 
    You can specify a host name or an IP address. 
	
.PARAMETER ProxyServerPort
    The port number that is used to connect to the proxy server. The default is port 80. 
    The port number must be greater than zero and less than 65536. 

.PARAMETER ProxyUserName
    The user name to use when accessing the proxy server. The name must be less than 256 characters. 

.PARAMETER ProxyUserDomain
    The name of the domain that contains the user's logon account. The name must be less than 256 characters.
	
.PARAMETER ProxyPassword
    Password to use when accessing the proxy.
        
.PARAMETER UseSeparateProxyForSsl
        Sets whether a separate proxy should be used for SSL communications with the upstream server.
        If $true, a separate proxy will be used when communicating with the upstream server.
        If $false, the same proxy will be used for both HTTP and HTTPS when communicating with the upstream server.

.PARAMETER SslProxyName
    The name of the proxy server for SSL communications.

.PARAMETER SslProxyServerPort
    The port number used to connect with the proxy server for SSL communications. 

.PARAMETER AnonymousProxyAccess
    Sets whether anonymous proxy server connections are allowed.
	$true to connect to the proxy server anonymously, $false to connect using user credentials.
    
.PARAMETER AllowProxyCredentialsOverNonSsl
	Sets whether user credentials can be sent to the proxy server using HTTP instead of HTTPS.
    If true, allows user credentials to be sent to the proxy server using HTTP; otherwise, the 
    user credentials are sent to the proxy server using HTTPS. 

    By default, WSUS uses HTTPS to access the proxy server. If HTTPS is not available and AllowProxyCredentialsOverNonSsl
    is $true, WSUS will use HTTP. Otherwise, WSUS will fail. Note that if WSUS uses HTTP to access the proxy server, the
    credentials are sent in plaintext.

.EXAMPLE
    Set-PSWsusConfigProxyServer -UseProxy $false

.EXAMPLE
    Set-PSWsusConfigProxyServer -UseProxy $true -ProxyName "proxy.domain.local" -ProxyServerPort "3128"

.EXAMPLE
    Set-PSWsusConfigProxyServer -UseProxy $true -SslProxyName "SslProxy.domain.local" -SslProxyServerPort 443

.EXAMPLE
    Set-PSWsusConfigProxyServer -UseProxy $true -ProxyName "proxy.domain.local" -ProxyServerPort "3128" `
    -AnonymousProxyAccess $true -AllowProxyCredentialsOverNonSsl $false

.EXAMPLE
    Set-PSWsusConfigProxyServer -UseProxy $true -ProxyName "proxy.domain.local" -ProxyServerPort "3128" `
    -AnonymousProxyAccess $false -ProxyUserName "YourUserName" -ProxyUserDomain "domain" `
    -ProxyPassword 'Password' -AllowProxyCredentialsOverNonSsl $true

.NOTES
	Name: Set-PSWsusConfigProxyServer
    Author: Dubinsky Evgeny
    DateCreated: 1DEC2013
    Modified 05 Feb 2014 - Boe Prox
        -Remove Begin, Process, End as function does not support pipeline input
        -Added -WhatIf support
        -Changed [boolean] param types to [switch] to align with best practices

.LINK
	http://blog.itstuff.in.ua/?p=62#Set-PSWSUSConfigProxyServer

#>

    [CmdletBinding(SupportsShouldProcess=$True)]
    Param
    (
        [switch]$UseProxy,
        [ValidateLength(1, 255)]
        [alias("SslProxyName")]
        [string]$ProxyName,
        [ValidateRange(0,65536)]
        [alias("SslProxyServerPort")]
        [int]$ProxyServerPort,
        [System.Management.Automation.Credential()]$ProxyCredential = [System.Management.Automation.PSCredential]::Empty,
        [ValidateLength(1, 255)]
        [string]$ProxyUserDomain,
        # Gets or sets whether a separate proxy should be used for SSL communications with the upstream server. 
        [switch]$UseSeparateProxyForSsl,
        [switch]$AnonymousProxyAccess,
        [switch]$AllowProxyCredentialsOverNonSsl
    )

        if(-NOT $wsus)
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }
        If ($PSCmdlet.ShouldProcess($wsus.ServerName,'Set Proxy Server')) {
            if ($PSBoundParameters['UseProxy'])
            {
                $_wsusconfig.UseProxy = $True
            }
            else
            {
                $_wsusconfig.UseProxy = $false
            }

            if ($PSBoundParameters['ProxyName'])
            {
                $_wsusconfig.ProxyName = $ProxyName
            }#endif
        
            if ($PSBoundParameters['ProxyServerPort'])
            {
                $_wsusconfig.ProxyServerPort = $ProxyServerPort
            }#endif
                
            if ($PSBoundParameters['ProxyCredential'] -ne $null)
            {
                $_wsusconfig.ProxyUserName = $ProxyCredential.GetNetworkCredential().username
            }#endif
            else
            {
                $_wsusconfig.ProxyUserName = $null
            }

            if ($PSBoundParameters['ProxyUserDomain'] -ne $null)
            {
                $_wsusconfig.ProxyUserDomain = $ProxyUserDomain
            }#endif
            else
            {
                $_wsusconfig.ProxyUserDomain = $null
            }
         
            if ($PSBoundParameters['ProxyCredential'])
            {
                # TO DO. Why Password dosen't set?
                # Need secure connection with wsus
                #$ProxyPassword = Read-Host -Prompt 'Enter Password' -AsSecureString
                #$wsus.GetConfiguration().SetProxyPassword($ProxyCredential.getnetworkcredential().password)
            
                Write-Warning "You need to specify password manually in console `n This issue we will fix in next release"
            }#endif
            elseif($PSBoundParameters['ProxyPassword'] -eq $null)
            {
                # if not SSL connection, ProxyPassword is read only
                #$_wsusconfig.ProxyPassword  = $null
            }

            if ($PSBoundParameters['AnonymousProxyAccess'])
            {
                $_wsusconfig.AnonymousProxyAccess = $True
            }#endif
            else
            {
                $_wsusconfig.AnonymousProxyAccess  = $true
            }

            if ($PSBoundParameters['AllowProxyCredentialsOverNonSsl'])
            {
                $_wsusconfig.AllowProxyCredentialsOverNonSsl = $True
            }#endif
            else
            {
                $_wsusconfig.AllowProxyCredentialsOverNonSsl  = $false
            }
                
            if ($PSBoundParameters['UseSeparateProxyForSsl'])
            {
                $_wsusconfig.UseSeparateProxyForSsl = $True
            }#endif
            else
            {
                $_wsusconfig.UseSeparateProxyForSsl  = $false
            }

            $_wsusconfig.Save()
        }
}

<#
Set-PSWSUSConfigProxyServer.ps1

Function 'Set-PSWsusConfigProxyServer' has both Username and Password parameters. 
Either set the type of the Password parameter to SecureString or replace the Username and Password parameters with a Credential parameter of type PSCredential. 
If using a Credential parameter in PowerShell 4.0 or earlier, please define a credential transformation attribute after the PSCredential type attribute.
#>