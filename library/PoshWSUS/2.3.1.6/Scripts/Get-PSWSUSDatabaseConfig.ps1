function Get-PSWSUSDatabaseConfig {
    <#  
    .SYNOPSIS  
        Displays the current WSUS database configuration.
    .DESCRIPTION
        Displays the current WSUS database configuration.
    .NOTES  
        Name: Get-PSWSUSDatabaseConfig
        Author: Boe Prox
        DateCreated: 24SEPT2010 
               
    .LINK  
        https://learn-powershell.net
    .EXAMPLE 
    Get-PSWSUSDatabaseConfig 

    Description
    -----------  
    This command will display the configuration information for the WSUS connection to a database.       
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
        $wsus.GetDatabaseConfiguration()      
    }
} 
