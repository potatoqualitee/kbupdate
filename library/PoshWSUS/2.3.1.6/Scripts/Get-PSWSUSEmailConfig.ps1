function Get-PSWSUSEmailConfig {
    <#  
    .SYNOPSIS  
        Retrieves the email notification configuration from WSUS.
        
    .DESCRIPTION
        Retrieves the email notification configuration from WSUS.
        
    .PARAMETER SendTestEmail
        Optional switch that will send a test email to the configured email addresses    
            
    .NOTES  
        Name: Get-PSWSUSEmailConfig
        Author: Boe Prox
        DateCreated: 24SEPT2010 
               
    .LINK  
        https://learn-powershell.net
        
    .EXAMPLE 
     Get-PSWSUSEmailConfig 
     
     Description
    -----------
    This command will display the configuration of the email notifications.
    
    .EXAMPLE 
    Get-PSWSUSEmailConfig -SendTestEmail    

    Description
    -----------
    This command will send a test email to the address or addresses in the To field.
           
    #> 
    [cmdletbinding()]
        Param(                          
            [Parameter(
                Position = 0,
                ValueFromPipeline = $False)]
                [switch]$SendTestEmail                   
                )     
    Begin {              
        if($wsus)
        {
            $email = $wsus.GetEmailNotificationConfiguration()
        }#endif
        else
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }
    }
    Process {
        If ($PSBoundParameters['SendTestEmail']) {
            $email.SendTestEmail()
            Write-Output"Test email sent."
        } Else {
            $email
        } 
    }   
} 
