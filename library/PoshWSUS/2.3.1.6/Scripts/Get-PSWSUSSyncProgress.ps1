function Get-PSWSUSSyncProgress {
    <#  
    .SYNOPSIS  
        Displays the current progress of a WSUS synchronization.
        
    .DESCRIPTION
        Displays the current progress of a WSUS synchronization.   
          
    .NOTES  
        Name: Get-PSWSUSSyncProgress
        Author: Boe Prox
        DateCreated: 24SEPT2010 
               
    .LINK  
        https://learn-powershell.net
        
    .EXAMPLE
    Get-PSWSUSSyncProgress 

    Description
    -----------
    This command will show you the current status of the WSUS sync.
           
    #> 
    [cmdletbinding()]  
    Param ()
    Begin {    
        if($wsus)
        {
            $sub = $wsus.GetSubscription() 
        }#endif
        else
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }   
    }
    Process {
        #Gather all child servers in WSUS    
        $sub.GetSynchronizationProgress() 
    }   
}
