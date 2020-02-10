Function Test-PSWSUSDatabaseServerConnection {
    <#  
    .SYNOPSIS  
        Tests the database connection from the console to the SQL database hosting the WSUS database.
    .DESCRIPTION
        Tests the database connection from the console to the SQL database hosting the WSUS database.
    .NOTES  
        Name: Test-PSWSUSDatabaseServerConnection
        Author: Boe Prox
        DateCreated: 06DEC2010 
               
    .LINK  
        https://learn-powershell.net
    .EXAMPLE 
    Test-PSWSUSDatabaseServerConnection

    Description
    -----------  
    This command will test the database connection and return a boolean value based on the connection status.
    #> 
    [cmdletbinding()]  
    Param () 
    Process {
        If ($wsusdb) {
            Try {
                #Test the connection to the database
                Write-Verbose "Testing the database connection to the WSUS database server."
                $wsusdb.ConnectToDatabase()
                Write-Output $True
            } Catch {
                Write-Output $False
            } 
        } Else {
            Write-Warning "Please connect to the database first using Connect-PSWSUSDatabaseServer"
        }
    }   
}
