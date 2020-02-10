function Get-PSWSUSUpdateSource {
<#
	.SYNOPSIS
		Gets configuration server from which to synchronize updates.

	.EXAMPLE
		Get-PSWSUSUpdateSource

	.OUTPUTS
		Microsoft.UpdateServices.Internal.BaseApi.UpdateServerConfiguration

	.NOTES
		Name: Get-PSWSUSUpdateSource
        Author: Dubinsky Evgeny
        DateCreated: 1DEC2013

	.LINK
		http://blog.itstuff.in.ua/?p=62#Get-PSWSUSUpdateSource

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
        Write-Verbose "Getting WSUS update files configuration"
        $config | select SyncFromMicrosoftUpdate, `
                         UpstreamWsusServerName, `
                         UpstreamWsusServerPortNumber, `
                         UpstreamWsusServerUseSsl, `
                         IsReplicaServer
    }
    End{}
}
