function Get-PSWSUSSubscription {
    <#  
    .SYNOPSIS  
        Displays WSUS subscription information.
        
    .DESCRIPTION
        Displays WSUS subscription information. You can view the next synchronization time, who last modified the schedule, etc...
        
    .NOTES  
        Name: Get-PSWSUSSubscription
        Author: Boe Prox
        DateCreated: 24SEPT2010 
               
    .LINK  
        https://learn-powershell.net
        
    .EXAMPLE  
    Get-PSWSUSSubscription      

    Description
    -----------  
    This command will list out the various subscription information on the WSUS server.
    #> 
    [cmdletbinding()]  
    Param () 
    
    Begin {
        if(-not $wsus)
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }
    }
    Process {
        $wsus.GetSubscription()     
    }
} 
