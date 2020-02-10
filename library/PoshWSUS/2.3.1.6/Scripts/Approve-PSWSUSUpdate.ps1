function Approve-PSWSUSUpdate {
    <#  
    .SYNOPSIS  
        Approves a WSUS update for a specific group with an optional deadline.
        
    .DESCRIPTION
        Approves a WSUS update for a specific group with an optional deadline.        
           
    .PARAMETER Update
        Update or Updates being approved.
        
    .PARAMETER Group
        Group which will receive the update.   
            
    .PARAMETER Deadline
        Optional deadline for client to install patch.
        
    .PARAMETER Action
        Type of approval action to take on update. Accepted values are Install, Approve, Uninstall and NotApproved 
        
    .PARAMETER PassThru
        Display output object of approval action 
         
            
    .NOTES  
        Name: Approve-PSWSUSUpdate
        Author: Boe Prox
        DateCreated: 24SEPT2010 
               
    .LINK  
        https://learn-powershell.net
        
    .EXAMPLE  
    $Groups = Get-PSWSUSGroup -Name 'Windows 2012','Testing'
    Get-PSWSUSUpdate -Update "KB979906" | Approve-PSWSUSUpdate -Group $Groups -Action Install

    Description
    ----------- 
    This command will take the collection of objects from the Get-PSWSUSUpdate command and then approve all updates for 
    the specified groups and the action command of 'Install'.
           
    #> 
    [cmdletbinding(
    	DefaultParameterSetName = 'collection',
        SupportsShouldProcess = $True
    )]
    Param(
        [Parameter(Mandatory = $True,ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.UpdateServices.Internal.BaseApi.Update[]]$Update,  
                  
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.UpdateServices.Administration.UpdateApprovalAction]$Action,
                      
        [Parameter(Mandatory = $True)]
        [Microsoft.UpdateServices.Internal.BaseApi.ComputerTargetGroup[]]$Group,

        [Parameter()]
        [datetime]$Deadline,

        [Parameter()]
        [switch]$PassThru                                   
        )
    Begin {}                    
    Process {
        ForEach ($Patch in $Update) {
            ForEach ($TargetGroup in $Group) {
                #Accept any licenses, if required
                If ($Patch.RequiresLicenseAgreementAcceptance -AND -NOT($PSBoundParameters.ContainsKey('WhatIf'))) {
                    #Approve License
                    Write-Verbose ("Accepting license aggreement for {0}" -f $Patch.title)
                    $Patch.AcceptLicenseAgreement()
                }
                #Determine if Deadline is required
                If ($PSBoundParameters['deadline']) {
                    Write-Verbose "Approving update with a deadline."
                    If ($pscmdlet.ShouldProcess($($Patch.title),"Approve update on $($Group.name)")) {
                        #Create the computer target group
                        $Data = $Patch.Approve($Action,$TargetGroup,$Deadline)
                        #Print out report of what was approved
                    }        
                } Else {    
                    #Approve the patch
                    Write-Verbose "Approving update without a deadline."                              
                    If ($pscmdlet.ShouldProcess($($Patch.title),"Approve update on $($Group.name)")) {
                        #Create the computer target group
                        $Data = $Patch.Approve($Action,$TargetGroup)
                        #Print out report of what was approved               
                    }
                }
                If ($PSBoundParameters['PassThru']) {
                    Write-Output $Data
                }
            }
        }
    }                
} 
