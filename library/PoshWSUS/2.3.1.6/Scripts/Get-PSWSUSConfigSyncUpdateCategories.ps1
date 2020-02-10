function Get-PSWSUSConfigSyncUpdateCategories {
<#  
.SYNOPSIS  
    Displays update product categories that you will sync from Windows Server Update Services (WSUS).
        
.DESCRIPTION
    Displays update product categories that you will sync from Windows Server Update Services (WSUS).
        
.NOTES  
    Name: Get-PSWSUSConfigSyncUpdateCategories
    Author: Dubinsky Evgeny
    DateCreated: 10MAY2013
    Modified: 06 Feb 2014 -- Boe Prox
        -Updated If statement
        -Removed Process
        
.EXAMPLE  
    Get-PSWSUSConfigSyncUpdateCategories    

    Type                 Id                   Title                UpdateSource              ArrivalDate              
    ----                 --                   -----                ------------              -----------              
    Product              558f4bc3-4827-49e... Windows XP           MicrosoftUpdate           29.11.2009 9:48:01 

    Description
    -----------  
    This command will get list of categories that enabled and  will sync with Windows Server Update Services (WSUS).

.LINK
    http://blog.itstuff.in.ua/?p=62#Get-PSWSUSConfigSyncUpdateCategories
#> 
    [cmdletbinding()]  
    Param () 
        if (-NOT $wsus)
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }
        $wsus.GetSubscription().GetUpdateCategories()
}
