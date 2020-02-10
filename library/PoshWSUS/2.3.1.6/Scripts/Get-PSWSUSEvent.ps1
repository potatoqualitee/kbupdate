function Get-PSWSUSEvent {
    <#  
    .SYNOPSIS  
        Retrieves all WSUS events.
    .DESCRIPTION
        Retrieves all WSUS events from the WSUS server.  
    .NOTES  
        Name: Get-PSWSUSEvent
        Author: Boe Prox
        DateCreated: 24SEPT2010 
               
    .LINK  
        https://learn-powershell.net
    .EXAMPLE
    Get-PSWSUSEvent  

    Description
    -----------
    This command will show you all of the WSUS events.
           
    #> 
    [cmdletbinding()]  
    Param () 
    
    if(-not $wsus)
    {
        Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
        Break
    }

    $Subscription = $wsus.GetSubscription()
    $Subscription.GetEventHistory() | ForEach {
        $_ | Add-Member -MemberType NoteProperty -Name EventID -Value ($_.Row.EventID) -PassThru |
        Add-Member -MemberType NoteProperty -Name SourceID -Value ($_.Row.SourceID) -PassThru |
        Add-Member -MemberType NoteProperty -Name SeverityId -Value ($_.Row.SeverityId) -PassThru         
    }       
}
