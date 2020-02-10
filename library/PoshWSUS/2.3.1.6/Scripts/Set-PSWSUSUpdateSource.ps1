function Set-PSWSUSUpdateSource {
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
		Set-PSWSUSUpdateSource -SyncFromMicrosoftUpdate $false -UpstreamWsusServerName "windowsupdate.corp.local" -UpstreamWsusServerPortNumber "8530"

        Description
        -----------
        Download update from upstream wsus server.
	
    .EXAMPLE
        Set-PSWSUSUpdateSource -SyncFromMicrosoftUpdate $false -UpstreamWsusServerName "windowsupdate.corp.local" -UpstreamWsusServerPortNumber "8531" -UpstreamWsusServerUseSsl $true -IsReplicaServer $true
        
        Description
        -----------
        Sets windowsupdate.corp.local the WSUS server is a replica server. Plus upstream server support SSL.

    .EXAMPLE
        Set-PSWSUSUpdateSource -SyncFromMicrosoftUpdate $false -UpstreamWsusServerName "windowsupdate.corp.local" -UpstreamWsusServerPortNumber "8530" -IsReplicaServer $true

        Description
        -----------
        Sets windowsupdate.corp.local the WSUS server is a replica server. Sync Without SSL.

    .EXAMPLE
        Set-PSWSUSUpdateSource -SyncFromMicrosoftUpdate $true 
        
        Description
        -----------
        Download updates from microsoft update.

	.NOTES
		Name: Set-PSWSUSUpdateSource
        Author: Dubinsky Evgeny
        DateCreated: 1DEC2013

    .LINK
        http://blog.itstuff.in.ua/?p=62#Set-PSWSUSUpdateSource

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

	.LINK
		http://blog.itstuff.in.ua

#>

    [CmdletBinding()]
    Param
    (
        [Parameter(Position = 0,Mandatory=$true)][Boolean]$SyncFromMicrosoftUpdate,
        [string]$UpstreamWsusServerName,
        [ValidateRange(0, 65536)]
        [int]$UpstreamWsusServerPortNumber,
        [Boolean]$UpstreamWsusServerUseSsl = $false,
        [Boolean]$IsReplicaServer = $false
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
        $config.SyncFromMicrosoftUpdate = $SyncFromMicrosoftUpdate
        
        if($PSBoundParameters['SyncFromMicrosoftUpdate'] -eq $true)
        {
            $config.IsReplicaServer = $false
        }#endif
        if($PSBoundParameters['UpstreamWsusServerName'] -and $PSBoundParameters['UpstreamWsusServerPortNumber'])
        {
            $config.UpstreamWsusServerName = $UpstreamWsusServerName
            $config.UpstreamWsusServerPortNumber = $UpstreamWsusServerPortNumber
        }#endif
        
        # Default UpstreamWsusServerUseSsl equels $false
        $config.UpstreamWsusServerUseSsl = $UpstreamWsusServerUseSsl
        
        # Default IsReplicaServer equels $false
        $config.IsReplicaServer = $IsReplicaServer
        
    }
    End
    {
        $config.Save()
    }
}
