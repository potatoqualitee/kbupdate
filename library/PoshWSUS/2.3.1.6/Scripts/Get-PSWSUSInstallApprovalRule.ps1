Function Get-PSWSUSInstallApprovalRule {
<#  
.SYNOPSIS  
    Lists the currently configured Automatic Install Approval Rules on WSUS.
    
.DESCRIPTION
    Lists the currently configured Automatic Install Approval Rules on WSUS.
    
.NOTES  
    Name: Get-PSWSUSInstallApprovalRule
    Author: Boe Prox
    DateCreated: 08DEC2010 
           
.LINK  
    https://learn-powershell.net
    
.EXAMPLE 
Get-PSWSUSInstallApprovalRule

Description
-----------  
This command will display the configuration information for the WSUS connection to a database.       
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
        $wsus.GetInstallApprovalRules()        
    }
}
