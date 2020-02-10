function Get-PSWSUSChildServer {
    <#  
    .SYNOPSIS  
        Retrieves all WSUS child servers.
    .DESCRIPTION
        Retrieves all WSUS child servers.
    .NOTES  
        Name: Get-PSWSUSChildServer
        Author: Boe Prox
        DateCreated: 24SEPT2010 
               
    .LINK  
        https://learn-powershell.net
    .EXAMPLE  
    Get-PSWSUSChildServer

    Description
    ----------- 
    This command will display all of the Child WSUS servers.
           
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
        #Gather all child servers in WSUS    
        $wsus.GetChildServers()
    }
}
