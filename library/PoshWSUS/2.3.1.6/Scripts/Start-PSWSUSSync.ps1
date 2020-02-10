function Start-PSWSUSSync {
    <#  
    .SYNOPSIS  
        Start synchronization on WSUS server.
   
    .DESCRIPTION
        Start synchronization on WSUS server.
       
    .NOTES  
        Name: Start-PSWSUSSync
        Author: Boe Prox
        DateCreated: 24SEPT2010 
               
    .LINK  
        https://learn-powershell.net
        
    .EXAMPLE
    Start-PSWSUSSync

    Description
    -----------
    This command will begin a manual sychronization on WSUS with the defined update source.      
           
    #> 
    [cmdletbinding(
    	ConfirmImpact = 'low',
        SupportsShouldProcess = $True
    )] 
    Param ()
    
    Begin {
        if($wsus)
        {
            $sub = $wsus.GetSubscription()    
            $sync = $sub.GetSynchronizationProgress()
        }#endif
        else
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }  
    }
    Process {  
        #Start WSUS synchronization
        If ($pscmdlet.ShouldProcess($($wsus.name))) {
            $sub.StartSynchronization()  
            "Synchronization has been started on {0}." -f $wsus.name
        } 
    }
} 
