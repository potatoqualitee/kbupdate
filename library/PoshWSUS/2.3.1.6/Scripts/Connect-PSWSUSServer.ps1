Function Connect-PSWSUSServer {
    <#  
    .SYNOPSIS  
        Make the initial connection to a WSUS Server.
        
    .DESCRIPTION
        Make the initial connection to a WSUS Server. Only one concurrent connection is allowed.
        
    .PARAMETER WsusServer
        Name of WSUS server to connect to. If not value is given, an attempt to read the value from registry will occur.   
              
    .PARAMETER SecureConnection
        Determines if a secure connection will be used to connect to the WSUS server. If not used, then a non-secure
        connection will be used.   
         
    .PARAMETER Port
        Port number to connect to. Default is Port "80" if not used. Accepted values are "80","443","8350" and "8351" 
           
    .NOTES  
        Name: Connect-PSWSUSServer
        Author: Boe Prox
        Version History: 
            1.2 | 17 Feb 2015
                -Renamed to Connect-PSWSUSServer
                -Allow read of registry for WUServer and Port
            1.0 | 24 Sept 2010
                -Initial Version
               
    .LINK  
        https://learn-powershell.net

    .EXAMPLE
    Connect-PSWSUSServer -WSUSserver "server1"

    Description
    -----------
    This command will make the connection to the WSUS using an unsecure port (Default:80).
    .EXAMPLE
    Connect-PSWSUSServer -WSUSserver "server1"  -SecureConnection 

    Description
    -----------
    This command will make a secure connection (Default: 443) to a WSUS server.   
    .EXAMPLE
    Connect-PSWSUSServer -WSUSserver "server1" -port 8530

    Description
    -----------
    This command will make the connection to the WSUS using a defined port 8530.  
           
    #> 
    [cmdletbinding()]
        Param(
            [Parameter(ValueFromPipeline = $True)]
            [Alias('Computername')]
            [string]$WsusServer, 
                                
            [Parameter()]
            [switch]$SecureConnection, 
              
            [Parameter()]
            [ValidateSet("80","443","8530","8531" )] 
            [int]$Port = 80                                
        )   
    Begin {                         
        $ErrorActionPreference = 'Stop'
        If ($PSBoundParameters['SecureConnection']) {
            $Secure = $True
        } Else {
            $Secure = $False
        }
    }
    Process {
        If (-NOT $PSBoundParameters.ContainsKey('WSUSServer')) {
            #Attempt to pull WSUS server name from registry key to use            
            If ((Get-ItemProperty -Path HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate -Name WUServer).WUServer -match '(?<Protocol>^http(s)?)(?:://)(?<Computername>(?:(?:\w+(?:\.)?)+))(?::)?(?<Port>.*)') {
                $WsusServer = $Matches.Computername
                $Port = $Matches.Port
            }
        }
        #Make connection to WSUS server  
        Try {
            Write-Verbose "Connecting to $($WsusServer) <$($Port)>"
            $Script:Wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer($wsusserver,$Secure,$port)  
            $Script:_wsusconfig = $Wsus.GetConfiguration()
            Write-Output $Wsus  
        } Catch {
            Write-Warning "Unable to connect to $($wsusserver)!`n$($error[0])"
        } Finally {
            $ErrorActionPreference = 'Continue' 
        } 
    }          
}
