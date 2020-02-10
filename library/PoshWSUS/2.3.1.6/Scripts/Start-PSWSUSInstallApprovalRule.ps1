Function Start-PSWSUSInstallApprovalRule {
    <#  
    .SYNOPSIS  
        Starts a given rule to process approvals
    .DESCRIPTION
        Starts a given rule to process approvals
    .PARAMETER Name
        Name of the Install Approval Rule to run
    .PARAMETER InputObject
        Rule object to run       
    .NOTES  
        Name: Start-PSWSUSInstallApprovalRule
        Author: Boe Prox
        DateCreated: 24JAN2011 
               
    .LINK  
        https://learn-powershell.net
    .EXAMPLE  
    Start-PSWSUSInstallApprovalRule -Name "Rule1"

    Description
    -----------      
    Rule1 will begin approving updates based on its configuration    

    .EXAMPLE
    $rule = Get-PSWSUSInstallApprovalRules | Where {$_.Name -eq "Rule1"}  
    $rule | Start-PSWSUSInstallApprovalRule

    Description
    -----------      
    Rule1 will begin approving updates based on its configuration   
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
    
    Process {
        Switch ($pscmdlet.parametersetname) {
            Name {
                if ($wsus) {
                    #Locate rule by name
                    Write-Verbose "Locating Rule by name"
                    $rule = $wsus.GetInstallApprovalRules() | Where {
                        $_.Name -eq $name
                    }
                    If ($rule -eq $Null) {
                        Write-Warning "No rules found by given name"
                        Continue
                    } Else {
                        If ($pscmdlet.ShouldProcess("$($rule.name)")) {
                            #Running approval rule
                            Write-Verbose "Running approval rule"
                            $rule.ApplyRule()
                        }                
                    }
                }
                else {
                    Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
                    Break
                }               
            }
            Object {
                #Rule is an object
                Write-Verbose "Rule is an object"
                If ($pscmdlet.ShouldProcess("$($rule.name)")) {
                    #Running approval rule
                    Write-Verbose "Running approval rule"
                    $rule.ApplyRule()
                }
            }
        }
    }
}
