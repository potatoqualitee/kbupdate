function Set-PSWSUSConfigUpdateFiles {
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
		Set-PSWSUSConfigUpdateFiles -HostBinariesOnMicrosoftUpdate:$false -DownloadExpressPackages -DownloadUpdateBinariesAsNeeded  -GetContentFromMU 

        Description
        -----------
        Updates are downloaded and stored on the local server. Download express installation packages. Update binaries are downloaded from Microsoft Update.

	.EXAMPLE
		Set-PSWSUSConfigUpdateFiles -HostBinariesOnMicrosoftUpdate:$false -DownloadUpdateBinariesAsNeeded

        Description
        -----------
        Updates are downloaded and stored on the local server. Don't download express packages. Only approved updates are downloaded.
        
    .EXAMPLE
        Set-PSWSUSConfigUpdateFiles -HostBinariesOnMicrosoftUpdate

        Description
        -----------
        updates are stored on Microsoft Update (WSUS downloads update metadata and license agreement only).
	
    .NOTES
        Name: Set-PSWSUSConfigUpdateFiles
        Author: Dubinsky Evgeny
        DateCreated: 1DEC2013
        Modified 05 Feb 2014 -- Boe Prox
            -Removed Begin, Process, End
            -Updated [bool] param types to [switch] to align with best practice
            -Added -WhatIf support

	.LINK
		http://blog.itstuff.in.ua/?p=62#Set-PSWSUSConfigUpdateFiles

#>

    [CmdletBinding(SupportsShouldProcess=$True)]
    Param
    (
        [Parameter(Mandatory=$True)]
        [switch]$HostBinariesOnMicrosoftUpdate,
        [switch]$DownloadExpressPackages,
        [switch]$DownloadUpdateBinariesAsNeeded,
        [switch]$GetContentFromMU
    )

    if(-NOT $wsus)
    {
        Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
        Break
    }
       
    If ($PSCmdlet.ShouldProcess($wsus.ServerName,'Update Config Update Files')) {        
        if(($PSBoundParameters['HostBinariesOnMicrosoftUpdate']) -or (-NOT $PSBoundParameters['HostBinariesOnMicrosoftUpdate']))
        {
            $_wsusconfig.HostBinariesOnMicrosoftUpdate = $True
        }#endif

        if(($PSBoundParameters['DownloadExpressPackages']) -or (-NOT $PSBoundParameters['DownloadExpressPackages']))
        {
            $_wsusconfig.DownloadExpressPackages = $True
        }#endif
        else
        {
            $_wsusconfig.DownloadExpressPackages = $false
        }
        
        if(($PSBoundParameters['DownloadUpdateBinariesAsNeeded']) -or (-NOT $PSBoundParameters['DownloadUpdateBinariesAsNeeded']))
        {
            $_wsusconfig.DownloadUpdateBinariesAsNeeded =$True
        }#endif
        else
        {
            $_wsusconfig.DownloadUpdateBinariesAsNeeded =$false
        }

        if(($PSBoundParameters['GetContentFromMU']) -or (-NOT $PSBoundParameters['GetContentFromMU']))
        {
            $_wsusconfig.GetContentFromMU = $True
        }#endif
        else
        {         
            $_wsusconfig.GetContentFromMU = $false
        }

        $_wsusconfig.Save()
    }
}
