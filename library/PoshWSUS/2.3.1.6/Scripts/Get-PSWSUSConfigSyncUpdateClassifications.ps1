function Get-PSWSUSConfigSyncUpdateClassifications {
    <#
    .Synopsis
       The Get-PSWSUSSyncUpdateClassifications cmdlet gets the list of Windows Server Update Services (WSUS) classifications that will be synchronized.
    
    .DESCRIPTION
       ??????? ????????
    
    .NOTES  
        Name: Get-PSWSUSConfigSyncUpdateCategories
        Author: Dubinsky Evgeny
        DateCreated: 10MAY2013
        Modified: 05 Feb 2014 -- Boe Prox
            -Modified If statement
            -Removed Begin, Process, End

    .EXAMPLE
       Get-PSWSUSConfigSyncUpdateClassifications

       Description
       -----------
       This command gets classification that sync with  Windows Server Update Services (WSUS).

    .LINK
        http://blog.itstuff.in.ua/?p=62#Get-PSWSUSConfigSyncUpdateClassifications
    #>
    [CmdletBinding(DefaultParameterSetName = 'Null')]
    Param()


    if (-not $wsus)
    {
        Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
        Break
    }
    $wsus.GetSubscription().GetUpdateClassifications()


}
