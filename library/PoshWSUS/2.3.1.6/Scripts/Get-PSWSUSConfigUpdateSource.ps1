function Get-PSWSUSConfigUpdateSource {
<#
	.SYNOPSIS
		Gets configuration server from which to synchronize updates.

	.EXAMPLE
		Get-PSWSUSConfigUpdateSource

	.OUTPUTS
		Microsoft.UpdateServices.Internal.BaseApi.UpdateServerConfiguration

	.NOTES
		Name: Get-PSWSUSConfigUpdateSource
        Author: Dubinsky Evgeny
        DateCreated: 1DEC2013
        Modified: 05 Feb 2014 -- Boe Prox
            -Removed set actions on Get function
            -Removed Begin,Process, End as it does not support pipeline

	.LINK
		http://blog.itstuff.in.ua/?p=62#Get-PSWSUSConfigUpdateSource

#>

    [CmdletBinding()]
    Param()

        if(-not $wsus)
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }

        Write-Verbose "Getting WSUS update files configuration"
        $_wsusconfig | select SyncFromMicrosoftUpdate, `
                         UpstreamWsusServerName, `
                         UpstreamWsusServerPortNumber, `
                         UpstreamWsusServerUseSsl, `
                         IsReplicaServer

}
