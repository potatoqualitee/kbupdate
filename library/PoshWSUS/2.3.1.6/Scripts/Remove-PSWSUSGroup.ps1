function Remove-PSWSUSGroup {
    <#  
    .SYNOPSIS  
        Creates a new WSUS Target group.
    .DESCRIPTION
        Creates a new WSUS Target group.
    .PARAMETER Name
        Name of group being deleted.
    .PARAMETER Id
        Id of group being deleted.       
    .NOTES  
        Name: Remove-PSWSUSGroup
        Author: Boe Prox
        DateCreated: 24SEPT2010 
               
    .LINK  
        https://learn-powershell.net
    .EXAMPLE 
    Remove-PSWSUSGroup  -name "Domain Servers"

    Description
    -----------  
    This command will remove the Domain Servers WSUS Target group.  
    .EXAMPLE 
    Remove-PSWSUSGroup  -id "fc93e74e-ba59-4593-9ff7-690af1be695f"

    Description
    -----------  
    This command will remove the Target group with ID 'fc93e74e-ba59-4593-9ff7-690af1be695f' from WSUS.       
    #> 
    [cmdletbinding(
    	DefaultParameterSetName = 'name',
    	ConfirmImpact = 'low',
        SupportsShouldProcess = $True
    )]
    Param(
        [Parameter(
            Mandatory = $False,
            Position = 0,
            ParameterSetName = 'name',
            ValueFromPipeline = $True
            )]
            [string]$Name,
        [Parameter(
            Mandatory = $False,
            Position = 0,
            ParameterSetName = 'id',
            ValueFromPipeline = $True
            )]
            [string]$Id,
        [Parameter(
            Mandatory = $False,
            Position = 0,
            ParameterSetName = 'object',
            ValueFromPipeline = $True
            )]
            [Microsoft.UpdateServices.Internal.BaseApi.ComputerTargetGroup]$InputObject
        )            
    
    Process {
        if ($pscmdlet.ParameterSetName -ne 'object') {
            if(-not $wsus)
            {
                Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
                Break
            }
        }

        #Determine action based on Parameter Set Name
        Switch ($pscmdlet.ParameterSetName) {            
            "name" {
                Write-Verbose "Querying for computer group"
                $group = $wsus.getcomputertargetgroups() | Where {
                    $_.Name -eq $name
                }
                If (-Not $group) {
                    Write-Error "Group $name does not exist in WSUS!"
                    Break
                } Else {                               
                    If ($pscmdlet.ShouldProcess($name)) {
                        #Create the computer target group
                        $group.Delete()
                    }
                }                    
            }                
            "id" {
                Write-Verbose "Querying for computer group"
                $group = $wsus.getcomputertargetgroups() | Where {$_.id -eq $id}
                If (-Not $group) {
                    Write-Error "Group $id does not exist in WSUS!"
                    Break
                }                                       
                If ($pscmdlet.ShouldProcess($id)) {
                    #Create the computer target group
                    $group.Delete()
                }            
            } 
            "Object" {
                Write-Verbose "Checking Group Object"  
                ForEach ($group in $InputObject) {                                    
                    If ($pscmdlet.ShouldProcess($group.Name)) {
                        #Create the computer target group
                        $group.Delete()
                    } 
                }           
            }                           
        }
    }                
} 
