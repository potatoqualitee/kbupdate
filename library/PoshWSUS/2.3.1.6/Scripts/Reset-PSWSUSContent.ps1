function Reset-PSWSUSContent {
    <#  
    .SYNOPSIS  
        Forces a synchronization of WSUS content and metadata.
    .DESCRIPTION
        Forces a synchronization of WSUS content and metadata.
    .NOTES  
        Name: Reset-PSWSUSContent
        Author: Boe Prox
        DateCreated: 04FEB2011 
               
    .LINK  
        https://learn-powershell.net
    .EXAMPLE
    Reset-PSWSUSContent

    Description
    -----------
    This command will force the synchronization of all update metadata on the WSUS server and verifies all update files on WSUS are valid.  
           
    #> 
    [cmdletbinding()]  
    Param () 
    
    Begin
    {
        if(-not $wsus)
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }
    }
    Process {
        #Reset the WSUS content and verify files   
        $wsus.ResetAndVerifyContentState()
    }
}
