function Get-PSWSUSCategory {
    <#  
    .SYNOPSIS  
        Retrieves the list of Update categories available from WSUS.
        
    .DESCRIPTION
        Retrieves the list of Update categories available from WSUS. 
        
    .PARAMETER Id
        Find update category by guid
    
    .PARAMETER Title
        Find update category by Title. Use of wildcards not allowed.
         
    .NOTES  
        Name: Get-PSWSUSCategory
        Author: Boe Prox
        DateCreated: 24SEPT2010 
               
    .LINK  
        https://learn-powershell.net
        
    .EXAMPLE
    Get-PSWSUSCategory  

    Description
    -----------
    This command will list all of the categories for updates in WSUS.
           
    #> 
    [cmdletbinding()]  
    Param (
        [Parameter(
            Position = 0,
            ValueFromPipeline = $True)]
            [string]$Id,
        [Parameter(
            Position = 1,
            ValueFromPipeline = $True)]
            [string]$Title            
    ) 
    
    Begin {
        if(-not $wsus)
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }
    }
    Process {
        If ($PSBoundParameters['Id']) {
            $Wsus.GetUpdateCategory($Id)
        } ElseIf ($PSBoundParameters['Title']) {
            $wsus.GetUpdateCategories() | Where {
                $_.Title -eq $Title
            }
        } Else { 
            $wsus.GetUpdateCategories()      
        }
    }
} 
