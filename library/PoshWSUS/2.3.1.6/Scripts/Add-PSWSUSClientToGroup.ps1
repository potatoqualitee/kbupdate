function Add-PSWSUSClientToGroup {
    <#  
    .SYNOPSIS  
        Adds a computer client to an existing WSUS group.
    .DESCRIPTION
        Adds a computer client to an existing WSUS group.
    .PARAMETER Group
        Name of group to add client to.
    .PARAMETER Computer
        Name of computer being added to group.        
    .NOTES  
        Name: Add-PSWSUSClientToGroup
        Author: Boe Prox
        DateCreated: 24SEPT2010 
               
    .LINK  
        https://learn-powershell.net
    .EXAMPLE 
    Add-PSWSUSClientToGroup -group "Domain Servers" -computer "server1"

    Description
    -----------  
    This command will add the client "server1" to the WSUS target group "Domain Servers".       
    #> 
    [cmdletbinding(
    	DefaultParameterSetName = 'Name',
    	ConfirmImpact = 'low',
        SupportsShouldProcess = $True
    )]
        Param(
            [Parameter(
                Mandatory = $True,
                Position = 0,
                ValueFromPipeline = $True)]
                [string]$Group,
            [Parameter(
                Mandatory = $False,
                Position = 1,
                ParameterSetName = 'Name',
                ValueFromPipeline = $True)]
                [System.Object]$Computername                                             
                )
    Process {
        #Verify Computer is in WSUS
        If ($Computername -is [string]) {
            Write-Verbose "Validating client in WSUS"
            $client = Get-PSWSUSClient -computername $Computername
        } ElseIf ($Computername -is [Microsoft.UpdateServices.Internal.BaseApi.ComputerTarget]) {
            Write-Verbose "Collection of clients"
            $Client = $Computername
        }
        If ($client) {
            if($wsus)
            {
                #Get group object
                Write-Verbose "Retrieving group"
                $targetgroup = $wsus.getcomputertargetgroups() | Where {
                    $_.Name -eq $group
                }
                If (-Not $targetgroup) {
                    Write-Error "Group $group does not exist in WSUS!"
                    Break
                }
                ForEach ($C in $Client) {    
                    #Add client to group
                    Write-Verbose ("Adding {0} to {1}" -f $c.fulldomainname,$Group)
                    If ($pscmdlet.ShouldProcess($($c.fulldomainname))) {
                        $targetgroup.AddComputerTarget($c)
                    }
                }
            }#endif
            else
            {
                Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
                Break
            }
        } Else {
            Write-Warning ("{0}: Unable to locate!`n{1}" -f $Computername,$_.Exception.Message)
        } 
    }   
} 
