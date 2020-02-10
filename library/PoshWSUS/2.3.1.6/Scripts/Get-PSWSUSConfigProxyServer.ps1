function Get-PSWSUSConfigProxyServer {
<#
	.SYNOPSIS
		This cmdlet gets config settings of proxy to download updates.

	.EXAMPLE
		Get-PSWSUSConfigProxyServes
	
    	Description
        -----------  
        This command will show list of proxy configuration parameters.
	
	.OUTPUTS
		Microsoft.UpdateServices.Internal.BaseApi.UpdateServerConfiguration

	.NOTES
		Name: Get-PSWSUSConfigProxyServer
        Author: Dubinsky Evgeny
        DateCreated: 1DEC2013
        Modified: 06 Feb 2014 -- Boe Prox
            -Removed instances where set actions are occuring

	.LINK
        http://blog.itstuff.in.ua/?p=62#Get-PSWSUSConfigProxyServer
#>

    [CmdletBinding()]
    Param()

    Begin
    {
        if(-not $wsus)
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }
    }
    Process
    { 
        Write-Verbose "Getting proxy server configuration"
        $wsus.GetConfiguration() | select UseProxy, ProxyName, ProxyServerPort, `
                                          ProxyUserDomain, ProxyUserName, `
                                          HasProxyPassword, AllowProxyCredentialsOverNonSsl, `
                                          AnonymousProxyAccess, SslProxyName, `
                                          SslProxyServerPort, UseSeparateProxyForSsl
    }
    End{}
}
