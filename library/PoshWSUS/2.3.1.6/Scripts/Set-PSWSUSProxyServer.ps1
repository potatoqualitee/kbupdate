function Set-PSWSUSProxyServer {
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

.PARAMETER ProxyCredential
    The user name and password to use when accessing the proxy server. The name must be less than 256 characters. 
        
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
    Set-PSWSUSProxyServer -UseProxy $false

.EXAMPLE
    Set-PSWSUSProxyServer -UseProxy $true -ProxyName "proxy.domain.local" -ProxyServerPort "3128"

.EXAMPLE
    Set-PSWSUSProxyServer -UseProxy $true -SslProxyName "SslProxy.domain.local" -SslProxyServerPort 443

.EXAMPLE
    Set-PSWSUSProxyServer -UseProxy $true -ProxyName "proxy.domain.local" -ProxyServerPort "3128" `
    -AnonymousProxyAccess $true -AllowProxyCredentialsOverNonSsl $false

.EXAMPLE
    Set-PSWSUSProxyServer -UseProxy $true -ProxyName "proxy.domain.local" -ProxyServerPort "3128" `
    -AnonymousProxyAccess $false -ProxyUserName "YourUserName" -ProxyUserDomain "domain" `
    -ProxyPassword 'Password' -AllowProxyCredentialsOverNonSsl $true

.NOTES
	Name: Set-PSWSUSProxyServer
    Author: Dubinsky Evgeny
    DateCreated: 1DEC2013

.LINK
	http://blog.itstuff.in.ua/?p=62#Set-PSWSUSProxyServer

#>

    [CmdletBinding()]
    Param
    (
        [Boolean]$UseProxy,
        [ValidateLength(1, 255)][alias("SslProxyName")][string]$ProxyName,
        [ValidateRange(0,65536)][alias("SslProxyServerPort")][int]$ProxyServerPort,
        [PSCredential]$ProxyCredential,
        # Gets or sets whether a separate proxy should be used for SSL communications with the upstream server. 
        [Boolean]$UseSeparateProxyForSsl,
        [Boolean]$AnonymousProxyAccess,
        [Boolean]$AllowProxyCredentialsOverNonSsl
    )

    Begin
    {
        if($wsus)
        {
            $config = $wsus.GetConfiguration()
            $config.ServerId = [System.Guid]::NewGuid()
            $config.Save()
        }#endif
        else
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }
    }
    Process
    {
        if ($PSBoundParameters['UseProxy'] -ne $null)
        {
            $config.UseProxy = $UseProxy
        }
        else
        {
            $config.UseProxy = $false
        }

        if ($PSBoundParameters['ProxyName'])
        {
            $config.ProxyName = $ProxyName
        }#endif
        
        if ($PSBoundParameters['ProxyServerPort'])
        {
            $config.ProxyServerPort = $ProxyServerPort
        }#endif
                
        if ($PSBoundParameters['ProxyCredential'] -ne $null)
        {
            $config.ProxyUserName = $ProxyCredential.GetNetworkCredential().UserName
        }#endif

        if ($PSBoundParameters['ProxyUserDomain'] -ne $null)
        {
            $config.ProxyUserDomain = $ProxyUserDomain
        }#endif
        else
        {
            $config.ProxyUserDomain = $null
        }

        if ($PSBoundParameters['AnonymousProxyAccess'] -ne $null)
        {
            $config.AnonymousProxyAccess = $AnonymousProxyAccess
        }#endif
        else
        {
            $config.AnonymousProxyAccess  = $true
        }

        if ($PSBoundParameters['AllowProxyCredentialsOverNonSsl'] -ne $null)
        {
            $config.AllowProxyCredentialsOverNonSsl = $AllowProxyCredentialsOverNonSsl
        }#endif
        else
        {
            $config.AllowProxyCredentialsOverNonSsl  = $false
        }
                
        if ($PSBoundParameters['UseSeparateProxyForSsl'] -ne $null)
        {
            $config.UseSeparateProxyForSsl = $UseSeparateProxyForSsl
        }#endif
        else
        {
            $config.UseSeparateProxyForSsl  = $false
        }
    }

    End
    {
        $config.Save()
    }
}
