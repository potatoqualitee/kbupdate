Function Connect-PSWSUSDatabaseServer {
    <#  
    .SYNOPSIS  
        Makes a database connection to the server hosting the WSUS database.
    .DESCRIPTION
        Makes a database connection to the server hosting the WSUS database.
    .NOTES  
        Name: Connect-PSWSUSDatabaseServer
        Author: Boe Prox
        DateCreated: 06DEC2010 
               
    .LINK  
        https://learn-powershell.net
    .EXAMPLE 
    Connect-PSWSUSDatabaseServer

    Description
    -----------  
    This command will display the configuration information for the WSUS connection to a database.       
    #> 
    [cmdletbinding()]  
        Param(
            [Parameter(
                Mandatory = $False,
                Position = 0,
                ValueFromPipeline = $False)]
                [switch]$Passthru
            )
    
    Begin {
        if(-not $wsus)
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }
    }
    Process { 
        #Create database connection
        Write-Verbose "Creating the database connection to the database hosting WSUS"
        $Global:wsusdb = ($wsus.GetDatabaseConfiguration()).CreateConnection()
    }
    End {
        #Display connection information if passthru is used
        If ($PSBoundParameters['passthru']) {
            $Global:wsusdb
        }
    }
}
