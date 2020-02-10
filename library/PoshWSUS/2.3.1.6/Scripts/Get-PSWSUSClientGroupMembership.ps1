function Get-PSWSUSClientGroupMembership {
    <#  
    .SYNOPSIS  
        Lists all Target Groups that a client is a member of in WSUS.
        
    .DESCRIPTION
        Lists all Target Groups that a client is a member of in WSUS.
        
    .PARAMETER Computer
        Name of the client to check group membership.
        
    .PARAMETER InputObject
        Computer object being used to check group membership.   
          
    .NOTES  
        Name: Get-PSWSUSClientGroupMembership
        Author: Boe Prox
        DateCreated: 12NOV2010 
               
    .LINK  
        https://learn-powershell.net
        
    .EXAMPLE  
    Get-PSWSUSClientGroupMembership -computer "server1"

    Description
    -----------      
    This command will retrieve the group membership/s of 'server1'. 
    
    .EXAMPLE  
    Get-PSWSUSClient -computername "server1" | Get-PSWSUSClientGroupMembership

    Description
    -----------      
    This command will retrieve the group membership/s of 'server1'. 
    
    .EXAMPLE  
    Get-PSWSUSClient -computername "servers" | Get-PSWSUSClientGroupMembership

    Description
    -----------      
    This command will retrieve the group membership/s of each server. 
           
    #> 
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory = $True,ValueFromPipeline = $True)]
        [Alias('CN')]
        [ValidateNotNullOrEmpty()]
        $Computername                                          
    )   
    Process {  
        ForEach ($Computer in $Computername) {
            If (($Computer -is [Microsoft.UpdateServices.Internal.BaseApi.ComputerTarget])) {
                $Client = $Computer
            } Else {
                $Client = Get-PSWSUSClient -Computername $Computer                
            }
            #List group membership of client
            $client | ForEach {
                $Data = $_.GetComputerTargetGroups()
                $data | Add-Member -MemberType NoteProperty -Name FullDomainName -Value $_.fulldomainname -PassThru 
            }                   
        } 
    }
}
