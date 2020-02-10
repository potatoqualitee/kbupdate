function Disconnect-PSWSUSServer {
    <#  
    .SYNOPSIS  
        Disconnects session against WSUS server.
    .DESCRIPTION
        Disconnects session against WSUS server.
    .NOTES  
        Name: Disconnect-PSWSUSServer
        Author: Boe Prox
        DateCreated: 27Oct2010 
               
    .LINK  
        https://learn-powershell.net
    .EXAMPLE
    Disconnect-PSWSUSServer

    Description
    -----------
    This command will disconnect the session to the WSUS server.  
           
    #> 
    [cmdletbinding()]  
    Param ()
    Process { 
        #Disconnect WSUS session by removing the variable   
        Remove-Variable -Name wsus -Force -Scope Script
        Remove-Variable -Name _wsusconfig -Force -Scope Script
    }
}
