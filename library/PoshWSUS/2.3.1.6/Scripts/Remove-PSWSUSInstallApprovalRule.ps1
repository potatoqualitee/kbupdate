Function Remove-PSWSUSInstallApprovalRule {
    <#  
    .SYNOPSIS  
        Removes Install Approval Rule from WSUS
    .DESCRIPTION
        Removes Install Approval Rule from WSUS
    .PARAMETER Name
        Name of the Install Approval Rule to remove
    .PARAMETER InputObject
        Rule object to be removed       
    .NOTES  
        Name: Remove-PSWSUSInstallApprovalRule
        Author: Boe Prox
        DateCreated: 24JAN2011 
               
    .LINK  
        https://learn-powershell.net
    .EXAMPLE  
    Remove-PSWSUSInstallApprovalRule -name "Rule1"

    Description
    -----------      
    Removes Rule1 from WSUS      
    .EXAMPLE  
    $rule = Get-PSWSUSInstallApprovalRule | Where {$_.Name -eq "Rule1"}
    $rule | Remove-PSWSUSInstallApprovalRule

    Description
    -----------      
    Removes Rule1 from WSUS   
    #> 
    [cmdletbinding(
    	DefaultParameterSetName = '',
    	ConfirmImpact = 'low',
        SupportsShouldProcess = $True    
    )]
        Param(
            [Parameter(
                Mandatory = $True,
                Position = 0,
                ParameterSetName = 'name',
                ValueFromPipeline = $True)]
                [string]$Name,
            [Parameter(
                Mandatory = $True,
                Position = 0,
                ParameterSetName = 'object',
                ValueFromPipeline = $True)]
                [system.object]$InputObject                                                                                                                                
                )
    
    Begin
    {
        if(-not $wsus)
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }
    }
    Process {
        Switch ($pscmdlet.parametersetname) {
            Name {
                #Locate rule by name
                Write-Verbose "Locating Rule by name"
                $rule = $wsus.GetInstallApprovalRules() | Where {
                    $_.Name -eq $name
                }
                If ($rule -eq $Null) {
                    Write-Warning "No rules found by given name"
                }
                Else {
                    If ($pscmdlet.ShouldProcess("$($rule.name)")) {
                        #Removing rule
                        Write-Verbose "Removing rule"
                        $wsus.DeleteInstallApprovalRule($rule.id)
                        Write-Output "Rule $($rule.name) removed"
                    }                
                }                
            }
            Object {
                #Rule is an object
                Write-Verbose "Rule is an object"
                $rule = $inputobject
                If ($pscmdlet.ShouldProcess("$($rule.name)")) {
                    #Removing rule
                    Write-Verbose "Removing rule"
                    $wsus.DeleteInstallApprovalRule($rule.id)
                    Write-Output "Rule $($rule.name) removed"
                }
            }
        }
    }                    
}
