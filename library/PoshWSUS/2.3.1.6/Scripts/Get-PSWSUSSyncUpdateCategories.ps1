function Get-PoshWSUSSyncUpdateCategories {
    <#  
    .SYNOPSIS  
        Displays update product categories that you will sync from Windows Server Update Services (WSUS).
        
    .DESCRIPTION
        Displays update product categories that you will sync from Windows Server Update Services (WSUS).
        
    .NOTES  
        Name: Get-PoshWSUSSyncUpdateCategories
        Author: Dubinsky Evgeny
        DateCreated: 10MAY2013
        
    .EXAMPLE  
        Get-PoshWSUSSyncUpdateCategories    

        Type                 Id                   Title                UpdateSource              ArrivalDate              
        ----                 --                   -----                ------------              -----------              
        Product              558f4bc3-4827-49e... Windows XP           MicrosoftUpdate           29.11.2009 9:48:01 

        Description
        -----------  
        This command will get list of categories that enabled and  will sync with Windows Server Update Services (WSUS).
    #> 
    [cmdletbinding(DefaultParameterSetName = 'Null')]  
    Param () 
    Process {
        if ($wsus)
        {
            $wsus.GetSubscription().GetUpdateCategories()
        }
        else
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }
    }
}
