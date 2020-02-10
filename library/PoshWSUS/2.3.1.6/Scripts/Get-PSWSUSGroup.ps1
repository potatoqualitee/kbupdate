function Get-PSWSUSGroup {
    <#  
    .SYNOPSIS  
        Retrieves specific WSUS target group.
    .DESCRIPTION
        Retrieves specific WSUS target group.
    .PARAMETER Name
        Name of group to search for. No wildcards allowed. 
    .PARAMETER Id
        GUID of group to search for. No wildcards allowed.       
    .NOTES  
        Name: Get-PSWSUSGroups
        Author: Boe Prox
        DateCreated: 24SEPT2010 
               
    .LINK  
        https://learn-powershell.net
    .EXAMPLE  
    Get-PSWSUSGroup -name "Domain Servers"

    Description
    ----------- 
    This command will search for the group and display the information for Domain Servers"

    .EXAMPLE  
    Get-PSWSUSGroup -ID "0b5ba818-021e-4238-8098-7245b0f90557"

    Description
    ----------- 
    This command will search for the group and display the information for the WSUS 
    group guid 0b5ba818-021e-4238-8098-7245b0f90557"
    
    .EXAMPLE
    Get-PSWSUSGroup

    Description
    -----------
    This command will list out all of the WSUS Target groups and their respective IDs.    
           
    #> 
    [cmdletbinding(
        DefaultParameterSetName = 'All'
    )]
        Param(
            [Parameter(ParameterSetName = 'Name')]
            [string[]]$Name,
            [Parameter(ParameterSetName = 'Id')]
            [string]$Id            
            )
    
    Begin {
        if(-not $wsus)
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }
    }
    Process {            
        Switch ($PSCmdlet.ParameterSetName) {
            'Name' {
                ForEach ($Item in $Name) {
                    $wsus.GetComputerTargetGroups() | Where {
                        $_.name -eq $Item
                    }
                }
            }
            'ID' {
                $wsus.GetComputerTargetGroup($Id)
            }
            'All' {
                $wsus.GetComputerTargetGroups()
            }
        }
    }
} 
