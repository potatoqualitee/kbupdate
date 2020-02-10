function Remove-PSWSUSClientFromGroup {
    <#  
    .SYNOPSIS  
        Removes a computer client to an existing WSUS group.
        
    .DESCRIPTION
        Removes a computer client to an existing WSUS group.
        
    .PARAMETER Group
        Name of group to remove client from.
        
    .PARAMETER Computer
        Name of computer being removed from group. 
               
    .NOTES  
        Name: Remove-PSWSUSClientToGroup
        Author: Boe Prox
        DateCreated: 24SEPT2010 
               
    .LINK  
        https://learn-powershell.net
        
    .EXAMPLE 
    Remove-PSWSUSClientFromGroup -group "Domain Servers" -computer "server1"

    Description
    -----------  
    This command will remove the client "server1" from the WSUS target group "Domain Servers".       
    #> 
    [cmdletbinding(
    	DefaultParameterSetName = 'group',
    	ConfirmImpact = 'low',
        SupportsShouldProcess = $True
    )]
        Param(
            [Parameter(
                Mandatory = $True,
                Position = 0,
                ParameterSetName = 'group',
                ValueFromPipeline = $True)]
                [string]$Group,
            [Parameter(
                Mandatory = $False,
                Position = 1,
                ParameterSetName = 'group',
                ValueFromPipeline = $True)]
                [string]$Computer                                             
                )
    
    if(-not $wsus)
    {
        Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
        Break
    }
    
    #Verify Computer is in WSUS
    $client = Get-PSWSUSClient -computername $computer
    If ($client) {
        #Get group object
        Write-Verbose "Retrieving group"
        $targetgroup = $wsus.getcomputertargetgroups() | Where {
            $_.Name -eq $group
        }
        If (-Not $targetgroup) {
            Write-Error "Group $group does not exist in WSUS!"
            Break
        }
        #Remove client from group
        Write-Verbose "Removing client to group"
        If ($pscmdlet.ShouldProcess($($client.fulldomainname))) {
            $targetgroup.RemoveComputerTarget($client)
            "$($client.fulldomainname) has been removed from $($group)"
        }
    } Else {
        Write-Error "Computer: $computer is not in WSUS!"
    }    
} 
