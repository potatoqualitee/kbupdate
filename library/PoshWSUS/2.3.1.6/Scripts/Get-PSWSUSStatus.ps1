function Get-PSWSUSStatus {
    <#  
    .SYNOPSIS  
        Retrieves a list of all updates and their statuses along with computer statuses.
    .DESCRIPTION
        Retrieves a list of all updates and their statuses along with computer statuses.   
    .NOTES  
        Name: Get-PSWSUSStatus
        Author: Boe Prox
        DateCreated: 24SEPT2010 
               
    .LINK  
        https://learn-powershell.net
    .EXAMPLE 
    Get-PSWSUSStatus 

    Description
    -----------
    This command will display the status of the WSUS server along with update statuses.
           
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
        $wsus.getstatus()      
    }
} 
