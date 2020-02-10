function Get-PSWSUSSyncHistory {
    <#  
    .SYNOPSIS  
        Retrieves the synchronization history of the WSUS server.
    .DESCRIPTION
        Retrieves the synchronization history of the WSUS server.    
    .NOTES  
        Name: Get-PSWSUSSyncHistory 
        Author: Boe Prox
        DateCreated: 24SEPT2010 
               
    .LINK  
        https://learn-powershell.net
    .EXAMPLE
    Get-PSWSUSSyncHistory

    Description
    -----------
    This command will list out the entire synchronization history of the WSUS server.  
           
    #> 
    [cmdletbinding()]  
    Param () 
    
    if($wsus)
    {
        $Subscription = $wsus.GetSubscription()
        $Subscription.GetSynchronizationHistory()
    }#endif
    else
    {
        Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
        Break
    }
} 
