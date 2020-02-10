function Set-PSWSUSEmailConfig {
    <#  
    .SYNOPSIS  
        Configures the email notifications on a WSUS server.
        
    .DESCRIPTION
        Configures the email notifications on a WSUS server. It is important to note that the email address to send
        the emails to is Read-Only and can only be configured from the WSUS Admin Console. After the settings have been
        changed, the new configuration will be displayed.
        
    .PARAMETER EmailLanguage
        What type of language to send the email in.   
               
    .PARAMETER SenderDisplayName
        The friendly name of where the email is coming from.   
         
    .PARAMETER SenderEmailAddress
        The senders email address
        
    .PARAMETER SendStatusNotification
        Determines if an email will be sent for a status notification 
           
    .PARAMETER SendSyncnotification
        Determines if an email will be sent after a sync by WSUS
        
    .PARAMETER SMTPHostname
        Server name of the smtp server to send email from
        
    .PARAMETER SMTPPort
        Port number to be used to connect to smtp server to send email
        
    .PARAMETER SmtpServerRequiresAuthentication
        Used if smtp server requires authentication

    .PARAMETER SMTPCredential  
        Credential to submit if required by smtp server        
        
    .PARAMETER StatusNotificationFrequency
        Frequency (Daily or Weekly) to send notifications
        
    .PARAMETER StatusNotificationTimeOfDay
        Date/Time to send notifications
        
    .PARAMETER UpdateServer
        Name of the WSUS update server        
    
    .PARAMETER PassThru
        Displays object after completion
           
    .NOTES  
        Name: Set-PSWSUSEmailConfig
        Author: Boe Prox
        DateCreated: 24SEPT2010 
               
    .LINK  
        https://learn-powershell.net
        
    .EXAMPLE  
    Set-PSWSUSEmailConfig -SenderDisplayName "WSUSAdmin" -SenderEmailAddress "wsusadmin@domain.com"

    Description
    -----------  
    This command will change the sender name and email address for email notifications and then display the new settings.      
    #> 
    [cmdletbinding(
    	DefaultParameterSetName = 'wsus',
    	ConfirmImpact = 'low'
    )]
    Param(
        [Parameter(
            Mandatory = $False, Position = 0,
            ParameterSetName = '', ValueFromPipeline = $False)]
            [string]$EmailLanguage,                     
        [Parameter(
            Mandatory = $False, Position = 1,
            ParameterSetName = '', ValueFromPipeline = $False)]
            [string]$SenderDisplayName,                          
        [Parameter(
            Mandatory = $False, Position = 2,
            ParameterSetName = '', ValueFromPipeline = $False)]
            [string]$SenderEmailAddress,   
        [Parameter(
            Mandatory = $False, Position = 3,
            ParameterSetName = '', ValueFromPipeline = $False)]
            [bool]$SendStatusNotification,
        [Parameter(
            Mandatory = $False, Position = 4,
            ParameterSetName = '',ValueFromPipeline = $False)]
            [switch]$SendSyncnotification,
        [Parameter(
            Mandatory = $False, Position = 5,
            ParameterSetName = '', ValueFromPipeline = $False)]
            [string]$SMTPHostname,
        [Parameter(
            Mandatory = $False, Position = 6,
            ParameterSetName = '', ValueFromPipeline = $False)]
            [int]$SMTPPort,
        [Parameter(
            Mandatory = $False, Position = 7,
            ParameterSetName = '', ValueFromPipeline = $False)]
            [switch]$SmtpServerRequiresAuthentication,    
        [Parameter(
            Mandatory = $False, Position = 8,
            ParameterSetName = 'account', ValueFromPipeline = $False)]
            [PSCredential]$SMTPCredential,
        [Parameter(
            Mandatory = $False, Position = 9,
            ParameterSetName = '', ValueFromPipeline = $False)]
            [string][ValidateSet("Daily","Weekly")]$StatusNotificationFrequency,
        [Parameter(
            Mandatory = $False, Position = 10,
            ParameterSetName = '', ValueFromPipeline = $False)]
            [string]$StatusNotificationTimeOfDay,
        [Parameter(
            Mandatory = $False,Position = 11,
            ParameterSetName = '',ValueFromPipeline = $False)]
            [string]$UpdateServer                                                                                                                                                           
    )
    Begin {   
        if($wsus)
        {
            #Configure Email Notifications
            $email = $wsus.GetEmailNotificationConfiguration()
            $ErrorActionPreference = 'stop'
        }#endif
        else
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }
    }
    Process {
        Try {
            If ($StatusNotificationTimeOfDay) {
                #Validate Notification Time of Day Parameter
                If (!([regex]::ismatch($StatusNotificationTimeOfDay,"^\d{2}:\d{2}$"))) {
                    Write-Error "$($StatusNotificationTimeOfDay) is not a valid time to use!`nMust be 'NN:NN'"
                } Else {                
                    $email.StatusNotificationTimeOfDay = $StatusNotificationTimeOfDay
                }
            }
            If ($UpdateServer) {$email.UpdateServer = $UpdateServer}
            If ($EmailLanguage) {$email.EmailLanguage = $EmailLanguage}
            If ($SenderDisplayName) {$email.SenderDisplayName = $SenderDisplayName}
            If ($SenderEmailAddress) {
                #Validate Email Address Parameter
                If (!([regex]::ismatch($SenderEmailAddress,"^\w+@\w+\.\w+$"))) {
                    Write-Error "$($SenderEmailAddress) is not a valid email address!`nMust be 'xxxx@xxxxx.xxx'"
                } Else {                    
                    $email.SenderEmailAddress = $SenderEmailAddress
                }
            }
            If ($SMTPHostname) {$email.SMTPHostname = $SMTPHostname}
            If ($SMTPPort) {$email.SMTPPort = $SMTPPort}
            If ($PSBoundParameters['SmtpServerRequiresAuthentication']) {
                $email.SmtpServerRequiresAuthentication = $True
            } Else {
                $email.SmtpServerRequiresAuthentication = $False
            }
            If ($SMTPCredential) {
                $email.SmtpUserName = $SMTPCredential.GetNetworkCredential().UserName
                $mail.SetSmtpUserPassword($SMTPCredential.GetNetworkCredential().Password)
            }
            Switch ($StatusNotificationFrequency) {
                "Daily" {$email.StatusNotificationFrequency = [Microsoft.UpdateServices.Administration.EmailStatusNotificationFrequency]::Daily}
                "Weekly" {$email.StatusNotificationFrequency = [Microsoft.UpdateServices.Administration.EmailStatusNotificationFrequency]::Weekly}
                Default {$Null}
            }
            If ($PSBoundParameters['SendStatusNotification']) {
                $email.SendStatusNotification = 1
            } Else {
                $email.SendStatusNotification = 0
            }        
            If ($PSBoundParameters['SendSyncNotification']) {
                $email.SendSyncNotification = 1
            } Else {
                $email.SendSyncNotification = 0
            }
        }    
        Catch {
            Write-Warning "$($error[0])"
            }
    }
    End {
        #Save Configuration Changes
        Try {
            $email.Save()
            Write-Host -fore Green "Email settings changed"
            If ($PSBoundParameters['PassThru']) {
                Write-Output $email
            }
        } Catch {
            Write-Warning "$($error[0])"
        }
    }    
}                 
