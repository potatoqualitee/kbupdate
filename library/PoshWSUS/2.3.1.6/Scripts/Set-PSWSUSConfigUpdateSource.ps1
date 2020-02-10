function Set-PSWSUSConfigUpdateSource {
<#
	.SYNOPSIS
		Sets source from where you will synchronize updates.

	.DESCRIPTION
		Sets source from where you will synchronize updates.

	.PARAMETER SyncFromMicrosoftUpdate
		Sets whether the WSUS server synchronizes updates from Microsoft Update or a local WSUS server.
        $true if the WSUS server synchronizes updates from Microsoft Update, $false if the WSUS server
        synchronizes updates from a local WSUS server. 

	.PARAMETER UpstreamWsusServerName
		Sets the name of a local server from which to synchronize updates.
        The name of the server from which to synchronize updates. You can specify a server name or an IP address. 
	
    .PARAMETER UpstreamWsusServerPortNumber 
        Sets the port number to use to communicate with the upstream WSUS server.
        Port number to use to communicate with the upstream WSUS server. The default is port 80.
        The port number must be greater than zero and less than 65536. 

    .PARAMETER UpstreamWsusServerUseSsl
         Sets whether the WSUS server should use SSL (HTTPS) to communicate with an upstream server.
         $true to use SSL (HTTPS) to communicate with an upstream server. Default $false for use HTTP. 

    .PARAMETER IsReplicaServer
        Sets whether the WSUS server is a replica server. $true if the WSUS server is a replica server, otherwise $false. 

	.EXAMPLE
		Set-PSWSUSConfigUpdateSource -SyncFromMicrosoftUpdate $false -UpstreamWsusServerName "windowsupdate.corp.local" -UpstreamWsusServerPortNumber "8530"

        Description
        -----------
        Download update from upstream wsus server.
	
    .EXAMPLE
        Set-PSWSUSConfigUpdateSource -SyncFromMicrosoftUpdate $false -UpstreamWsusServerName "windowsupdate.corp.local" -UpstreamWsusServerPortNumber "8531" -UpstreamWsusServerUseSsl $true -IsReplicaServer $true
        
        Description
        -----------
        Sets windowsupdate.corp.local the WSUS server is a replica server. Plus upstream server support SSL.

    .EXAMPLE
        Set-PSWSUSConfigUpdateSource -SyncFromMicrosoftUpdate $false -UpstreamWsusServerName "windowsupdate.corp.local" -UpstreamWsusServerPortNumber "8530" -IsReplicaServer $true

        Description
        -----------
        Sets windowsupdate.corp.local the WSUS server is a replica server. Sync Without SSL.

    .EXAMPLE
        Set-PSWSUSConfigUpdateSource -SyncFromMicrosoftUpdate $true 
        
        Description
        -----------
        Download updates from microsoft update.

	.NOTES
		Name: Set-PSWSUSConfigUpdateSource
        Author: Dubinsky Evgeny
        DateCreated: 1DEC2013
        Modified 05 Feb 2014 -- Boe Prox
            -Switched [bool] parameter types to [switch] to align with best practices
            -Removed Begin,Process, End as no params support pipeline
            -Added -WhatIf support

    .LINK
        http://blog.itstuff.in.ua/?p=62#Set-PSWSUSConfigUpdateSource

	.LINK
		http://msdn.microsoft.com/en-us/library/windows/desktop/microsoft.updateservices.administration.iupdateserverconfiguration.syncfrommicrosoftupdate(v=vs.85).aspx
	
    .LINK
        http://msdn.microsoft.com/en-us/library/windows/desktop/microsoft.updateservices.administration.iupdateserverconfiguration.isreplicaserver(v=vs.85).aspx

	.LINK
        http://msdn.microsoft.com/en-us/library/windows/desktop/microsoft.updateservices.administration.iupdateserverconfiguration.upstreamwsusservername(v=vs.85).aspx

	.LINK
        http://msdn.microsoft.com/en-us/library/windows/desktop/microsoft.updateservices.administration.iupdateserverconfiguration.upstreamwsusserverportnumber(v=vs.85).aspx

    .LINK
        http://msdn.microsoft.com/en-us/library/windows/desktop/microsoft.updateservices.administration.iupdateserverconfiguration.upstreamwsusserverusessl(v=vs.85).aspx

#>

    [CmdletBinding(SupportsShouldProcess=$True)]
    Param
    (
        [Switch]$SyncFromMicrosoftUpdate,
        [string]$UpstreamWsusServerName,
        [ValidateRange(0, 65536)]
        [int]$UpstreamWsusServerPortNumber,
        [Switch]$UpstreamWsusServerUseSsl,
        [Switch]$IsReplicaServer
    )

    if(-NOT $wsus)
    {
        Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
        Break
    }
    If ($PSCmdlet.ShouldProcess($wsus.ServerName,'UpdateConfigSource')) {
        if($PSBoundParameters['SyncFromMicrosoftUpdate']) {
            $_wsusconfig.SyncFromMicrosoftUpdate = $True
        }
        
        if($PSBoundParameters['SyncFromMicrosoftUpdate'])
        {
            $_wsusconfig.IsReplicaServer = $false
        }#endif

        if($PSBoundParameters['UpstreamWsusServerName'] -and $PSBoundParameters['UpstreamWsusServerPortNumber'])
        {
            $_wsusconfig.UpstreamWsusServerName = $UpstreamWsusServerName
            $_wsusconfig.UpstreamWsusServerPortNumber = $UpstreamWsusServerPortNumber
        }#endif
        
        # Default UpstreamWsusServerUseSsl equals $false
        if($PSBoundParameters['UpstreamWsusServerUseSsl']) {
            $_wsusconfig.UpstreamWsusServerUseSsl = $True
        }
        
        # Default IsReplicaServer equals $false
        if($PSBoundParameters['IsReplicaServer']) {
            $_wsusconfig.IsReplicaServer = $True
        }
        
        $_wsusconfig.Save()
    }
}
