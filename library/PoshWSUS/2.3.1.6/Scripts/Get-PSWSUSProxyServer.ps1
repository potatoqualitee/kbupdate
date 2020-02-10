function Get-PSWSUSProxyServer {
<#
	.SYNOPSIS
		This cmdlet gets config settings of proxy to download updates.

	.EXAMPLE
		Get-PSWSUSProxyServes
	
    	Description
        -----------  
        This command will show list of proxy configuration parameters.
	
	.OUTPUTS
		Microsoft.UpdateServices.Internal.BaseApi.UpdateServerConfiguration

	.NOTES
		Name: Get-PSWSUSProxyServer
        Author: Dubinsky Evgeny
        DateCreated: 1DEC2013

	.LINK
        http://blog.itstuff.in.ua/?p=62#Get-PSWSUSProxyServer
#>

    [CmdletBinding()]
    Param()

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
        Write-Verbose "Getting proxy server configuration"
        $wsus.GetConfiguration() | select UseProxy, ProxyName, ProxyServerPort, `
                                          ProxyUserDomain, ProxyUserName, `
                                          HasProxyPassword, AllowProxyCredentialsOverNonSsl, `
                                          AnonymousProxyAccess, SslProxyName, `
                                          SslProxyServerPort, UseSeparateProxyForSsl
    }
    End{}
}
