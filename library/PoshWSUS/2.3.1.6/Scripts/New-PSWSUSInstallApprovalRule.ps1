Function New-PSWSUSInstallApprovalRule {
    <#  
    .SYNOPSIS  
        Creates a new Install Approval Rule in WSUS.
        
    .DESCRIPTION
        Creates a new Install Approval Rule in WSUS.
        
    .PARAMETER Name
        Name of the new Install Approval Rule
        
    .PARAMETER Enable
        Enables the approval rule after created
        
    .PARAMETER Categories
        Collection of categories that will be applied to the rule. Use Get-PSWSUSUpdateCategories to gather the collection.
        
    .PARAMETER Group
        Collection of Computer Target Groups that will be applied to the rule.  Use Get-PSWSUSGroups to gather the collection.
        
    .PARAMETER Classifications 
        Collection of Update Classifications that will be applied to the rule.  Use Get-PSWSUSUpdateClassifications for the collection.
        
    .PARAMETER PassThru  
         
    .NOTES  
        Name: New-PSWSUSInstallApprovalRule
        Author: Boe Prox
        DateCreated: 08DEC2010 
               
    .LINK  
        https://learn-powershell.net
        
    .EXAMPLE  
    New-PSWSUSInstallApprovalRule -Name 'NewApproval'

    Description
    -----------
    Creates a new rule with nothing configured named 'NewApproval'

    .EXAMPLE  
    $cat = Get-PSWSUSUpdateCategory | ? {$_.Title -eq "Windows Server 2008"}
    $group = Get-PSWSUSGroup | ? {$_.Name -eq "Test"}
    $class = Get-PSWSUSUpdateClassification | ? {$_.Title -eq "Updates"}
    New-PSWSUSInstallApprovalRule -Name "Rule1" -Category $cat -Classification $class -Group $group -Enable

    Description
    -----------
    Creates a new rule named 'NewApproval' with groups, categories and classifications configured and enables the rule.
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
            ParameterSetName = '',
            ValueFromPipeline = $True)]
            [string]$Name,  
        [Parameter(
            Mandatory = $False,
            Position = 2,
            ParameterSetName = '',
            ValueFromPipeline = $False)]
            [switch]$Enable, 
        [Parameter(
            Mandatory = $False,
            Position = 3,
            ParameterSetName = 'Properties',
            ValueFromPipeline = $False)]
            [System.Object]$Category,  
        [Parameter(
            Mandatory = $False,
            Position = 4,
            ParameterSetName = 'Properties',
            ValueFromPipeline = $False)]
            [System.Object]$Group, 
        [Parameter(
            Mandatory = $False,
            Position = 5,
            ParameterSetName = 'Properties',
            ValueFromPipeline = $False)]
            [System.Object]$Classification,
        [Parameter(
            Mandatory = $False,
            Position = 6,
            ParameterSetName = '',
            ValueFromPipeline = $False)]
            [Switch]$PassThru                                                                                                                                 
    )
    Begin {
        #Define the required action for the rule
        Write-Verbose "Setting the Action to 'Install'"
        $install = [Microsoft.UpdateServices.Administration.AutomaticUpdateApprovalAction]::Install       
    }
    Process {
        If ($pscmdlet.ShouldProcess($Name)) {
            #Create the Rule
            Write-Verbose "Creating Approval Rule"
            $rule = $wsus.CreateInstallApprovalRule($Name)
        }
        #Begin setting the properties of the Rule
        If ($psboundparameters["Category"]) {
            #Create the update collections object
            Write-Verbose "Creating collection of categories"
            $cat_coll = New-Object Microsoft.UpdateServices.Administration.UpdateCategoryCollection
            #Add categories to collection
            Write-Verbose "Adding categories to collection"
            $cat_coll.AddRange($Category)
            #Set the categories for rule
            If ($pscmdlet.ShouldProcess($Name)) {        
                Write-Verbose "Setting categories on rule"
                $rule.SetCategories($cat_coll)
            }
        }
        If ($psboundparameters["Group"]) {
            #Create the update collections object
            Write-Verbose "Creating collection of groups"
            $group_coll = New-Object Microsoft.UpdateServices.Administration.ComputerTargetGroupCollection
            #Add groups to collection
            Write-Verbose "Adding groups to collection"
            $group_coll.AddRange($group)
            If ($pscmdlet.ShouldProcess($Name)) {        
                #Set the groups for rule
                Write-Verbose "Setting groups on rule"
                $rule.SetComputerTargetGroups($group_coll)
            }
        }
        If ($psboundparameters["Classification"]) {
            #Create the update collections object
            Write-Verbose "Creating collection of classifications"
            $class_coll = New-Object Microsoft.UpdateServices.Administration.UpdateClassificationCollection
            #Add classifications to collection
            Write-Verbose "Adding classifications to collection"
            $class_coll.AddRange($classification)
            If ($pscmdlet.ShouldProcess($Name)) {        
                #Set the classification for rule
                Write-Verbose "Setting Classification on rule"
                $rule.SetUpdateClassifications($class_coll)
            }
        } 
        If ($Enable) {
            If ($pscmdlet.ShouldProcess($Name)) {        
                #Enable the rule for use
                Write-Verbose "Enabling Rule"
                $rule.Enabled = $True
            }
        }
    }        
    End{ 
        If ($pscmdlet.ShouldProcess($Name)) {        
            #Save the Rule
            Write-Verbose "Saving new rule"
            $rule.Save()
            Write-Output "Rule $($name) has been created."
        }
                    
        If ($PassThru) {
            Write-Output $rule
        }  
    }                                                               
}
