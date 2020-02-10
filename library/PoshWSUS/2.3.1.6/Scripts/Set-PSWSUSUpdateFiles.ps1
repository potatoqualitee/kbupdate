function Set-PSWSUSUpdateFiles {
<#
	.SYNOPSIS
		Sets whether updates are stored locally or whether clients download approved updates directly from Microsoft Update.

	.DESCRIPTION
		Storing update files locally on the WSUS server can save bandwidth on your Internet connection, because clients download
        updates directly from a WSUS server. This option requires enough disk space to store the updates that you intend to download.
        A minimum of 30GB of hard disk space is recommended. Storing update files on Microsoft Update and having clients download 
        only approved updates is useful if you have mobile clients, branch offices, or any situation in which clients have a direct
        connection to the Internet, and downloading updates over a WAN connection would introduce additional complexity. With this
        option, only approvals are distributed over the WAN link. Also, when you synchronize with Microsoft Update, you will get only
        update metadata, which describes each of the available updates. The update files themselves are never downloaded and stored on
        the WSUS server.

	.PARAMETER HostBinariesOnMicrosoftUpdate
        Sets whether updates are stored locally or whether clients download approved updates directly from Microsoft Update. 
        
        If $true, updates are stored on Microsoft Update (WSUS downloads update metadata and license agreement only); 
        if $false, updates are downloaded and stored on the local server.

	.PARAMETER DownloadExpressPackages
        Sets whether express installation packages should be downloaded.
        
        $true to download express installation packages, otherwise $false.

	.PARAMETER DownloadUpdateBinariesAsNeeded
        Sets whether updates are downloaded only when they are approved.
        
        If $true, only approved updates are downloaded. If $false, all updates are downloaded after
        the WSUS server synchronizes with Microsoft Update.
        
        WSUS ignores this property if HostBinariesOnMicrosoftUpdate is $true.
        
        Setting DownloadUpdateBinariesAsNeeded to false saves disk space on the WSUS server, but may delay deployment to the clients.

    .PARAMETER GetContentFromMU
        Sets whether update binaries are downloaded from Microsoft Update or from the upstream server.

        If true, the server will download update binaries from Microsoft Update. If false, the server will download update binaries
        from its upstream server. 

        This option applies only if the server is a downstream server and content is downloaded locally.

	.EXAMPLE
		Set-PSWSUSUpdateFiles -HostBinariesOnMicrosoftUpdate $false -DownloadExpressPackages $true -DownloadUpdateBinariesAsNeeded $true -GetContentFromMU $true

        Description
        -----------
        Updates are downloaded and stored on the local server. Download express installation packages. Update binaries are downloaded from Microsoft Update.

	.EXAMPLE
		Set-PSWSUSUpdateFiles -HostBinariesOnMicrosoftUpdate $false -DownloadUpdateBinariesAsNeeded $true -DownloadExpressPackages $false

        Description
        -----------
        Updates are downloaded and stored on the local server. Don't download express packages. Only approved updates are downloaded.
        
    .EXAMPLE
        Set-PSWSUSUpdateFiles -HostBinariesOnMicrosoftUpdate $true

        Description
        -----------
        updates are stored on Microsoft Update (WSUS downloads update metadata and license agreement only).
	
    .NOTES
        Name: Set-PSWSUSUpdateFiles
        Author: Dubinsky Evgeny
        DateCreated: 1DEC2013

	.LINK
		http://blog.itstuff.in.ua/?p=62#Set-PSWSUSUpdateFiles

#>

    [CmdletBinding()]
    Param
    (
        [Parameter(Position = 0,Mandatory=$true)]
        [Boolean]$HostBinariesOnMicrosoftUpdate,
        [Boolean]$DownloadExpressPackages,
        [Boolean]$DownloadUpdateBinariesAsNeeded,
        [Boolean]$GetContentFromMU
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
        
        if(($PSBoundParameters['HostBinariesOnMicrosoftUpdate'] -eq $true) -or `
           ($PSBoundParameters['HostBinariesOnMicrosoftUpdate'] -eq $false))
        {
            $config.HostBinariesOnMicrosoftUpdate = $HostBinariesOnMicrosoftUpdate
        }#endif

        if(($PSBoundParameters['DownloadExpressPackages'] -eq $true) -or `
           ($PSBoundParameters['DownloadExpressPackages'] -eq $false))
        {
            $config.DownloadExpressPackages = $DownloadExpressPackages
        }#endif
        else
        {
            $config.DownloadExpressPackages = $false
        }
        
        if(($PSBoundParameters['DownloadUpdateBinariesAsNeeded'] -eq $true) -or `
           ($PSBoundParameters['DownloadUpdateBinariesAsNeeded'] -eq $false))
        {
            $config.DownloadUpdateBinariesAsNeeded =$DownloadUpdateBinariesAsNeeded
        }#endif
        else
        {
            $config.DownloadUpdateBinariesAsNeeded =$false
        }

        if(($PSBoundParameters['GetContentFromMU'] -eq $true) -or `
           ($PSBoundParameters['GetContentFromMU'] -eq $false))
        {
            $config.GetContentFromMU = $GetContentFromMU
        }#endif
        else
        {         
            $config.GetContentFromMU = $false
        }
    }
    End
    {
        $config.Save()
    }
}
