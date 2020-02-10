function Resume-PSWSUSDownload {
    <#  
    .SYNOPSIS  
        Resumes all current WSUS downloads.
    .DESCRIPTION
        Resumes all current WSUS downloads that had been cancelled.
    .NOTES  
        Name: Resume-PSWSUSDownloads
        Author: Boe Prox
        DateCreated: 24SEPT2010 
               
    .LINK  
        https://learn-powershell.net
    .EXAMPLE 
    Resume-PSWSUSDownload

    Description
    ----------- 
    This command will resume the downloading of updates to the WSUS server. 
           
    #> 
    [cmdletbinding()]
        Param() 
    
    Begin
    {
        if(-not $wsus)
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }
    }
    Process {    
        #Resume all downloads running on WSUS       
        If ($pscmdlet.ShouldProcess($($wsus.name))) {
            $wsus.ResumeAllDownloads()
            "Downloads have been resumed on {0}." -f $wsus.name
        }
    }
}
