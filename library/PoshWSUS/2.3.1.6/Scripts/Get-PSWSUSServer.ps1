function Get-PSWSUSServer {
    <#  
    .SYNOPSIS  
        Retrieves connection and configuration information from the WSUS server.
        
    .DESCRIPTION
        Retrieves connection and configuration information from the WSUS server. 
        
    .PARAMETER ShowConfiguration
        Lists more configuration information from WSUS Server     
         
    .NOTES  
        Name: Get-PSWSUSServer
        Author: Boe Prox
        DateCreated: 24SEPT2010 
               
    .LINK  
        https://learn-powershell.net
        
    .EXAMPLE
    Get-PSWSUSServer

    Description
    -----------
    This command will display basic information regarding the WSUS server.
    .EXAMPLE
    Get-PSWSUSServer -ShowConfiguration      

    Description
    -----------
    This command will list out more detailed information regarding the configuration of the WSUS server.
           
    #> 
    [cmdletbinding()]
        Param(                         
            [Parameter(
                Position = 0,
                ValueFromPipeline = $False)]
                [switch]$ShowConfiguration                     
                )                    
    
    Begin {
        if(-not $wsus)
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }
    }
    Process {                
        If ($PSBoundParameters['ShowConfiguration']) {
            $wsus.GetConfiguration()
        } Else {
            $wsus
        }  
    }      
}
