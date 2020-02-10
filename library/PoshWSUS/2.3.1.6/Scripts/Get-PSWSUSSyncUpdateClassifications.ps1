function Get-PoshWSUSSyncUpdateClassifications {
    <#
    .Synopsis
       The Get-PoshWSUSSyncUpdateClassifications cmdlet gets the list of Windows Server Update Services (WSUS) classifications that will be synchronized.
    
    .DESCRIPTION
       ??????? ????????
    
    .NOTES  
        Name: Get-PoshWSUSSyncUpdateCategories
        Author: Dubinsky Evgeny
        DateCreated: 10MAY2013

    .EXAMPLE
       Get-PoshWSUSSyncUpdateClassifications

       Description
       -----------
       This command gets classification that sync with  Windows Server Update Services (WSUS).
    #>
    [CmdletBinding(DefaultParameterSetName = 'Null')]
    Param()

    Begin {}
    Process
    {
        if ($wsus)
        {
            $wsus.GetSubscription().GetUpdateClassifications()
        }
        else
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }
    }
    End{}
}
