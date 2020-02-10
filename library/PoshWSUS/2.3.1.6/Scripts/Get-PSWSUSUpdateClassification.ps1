Function Get-PSWSUSUpdateClassification {
    <#  
    .SYNOPSIS  
        Lists all update classifications under WSUS.
        
    .DESCRIPTION
        Lists all update classifications under WSUS.
        
    .NOTES  
        Name: Get-PSWSUSUpdateClassification
        Author: Boe Prox
        DateCreated: 24JAN2011 
               
    .LINK  
        https://learn-powershell.net
        
    .EXAMPLE 
    Get-PSWSUSUpdateClassification

    Description
    -----------  
    This command will display all update classifications available under WSUS.
    #> 
    [cmdletbinding()]  
    Param()
    
    Begin {
        if(-not $wsus)
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }
    }
    Process {
        $wsus.GetUpdateClassifications()        
    }
}
