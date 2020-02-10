Function Set-PSWSUSInstallApprovalRule {
    <#  
    .SYNOPSIS  
        Configures an existing Approval Rule in WSUS
        
    .DESCRIPTION
        Configures an existing Approval Rule in WSUS
        
    .PARAMETER Name
        Name of the Install Approval Rule
        
    .PARAMETER Enable
        Enables the approval rule
        
    .PARAMETER Categories
        Collection of categories that will be applied to the rule. Use Get-PSWSUSUpdateCategories to gather the collection.
        
    .PARAMETER Group
        Collection of Computer Target Groups that will be applied to the rule.  Use Get-PSWSUSGroups to gather the collection.
        
    .PARAMETER Classifications 
        Collection of Update Classifications that will be applied to the rule.  Use Get-PSWSUSUpdateClassifications for the collection.
        
    .PARAMETER Disable
        Disable the rule  
    
    .PARAMETER PassThru  
           
    .NOTES  
        Name: New-PSWSUSInstallApprovalRule
        Author: Boe Prox
        DateCreated: 08DEC2010 
               
    .LINK  
        https://learn-powershell.net
        
    .EXAMPLE  
    Set-PSWSUSInstallApprovalRule -Name "Rule1" -Enable

    Description
    -----------      
    Enables Rule1 to run on WSUS   
    
    .EXAMPLE  
    Set-PSWSUSInstallApprovalRule -Name "Rule1" -Disable

    Description
    -----------      
    Disables Rule1 on WSUS 
     
    .EXAMPLE  
    $cat = Get-PSWSUSUpdateCategories | ? {$_.Title -eq "Windows Server 2008"}
    $group = Get-PSWSUSGroups | ? {$_.Name -eq "Test"}
    $class = Get-PSWSUSUpdateClassifications | ? {$_.Title -eq "Updates"}
    Set-PSWSUSInstallApprovalRule -Name "Rule1" -Category $cat -Classification $class -Group $group

    Description
    -----------      
    Configures existing Approval Rule1 with classification, group and categories on rule. First the holders for the category, group and classification 
    collections are created to be supplied to the command. Then the command is run.
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
        [system.object]$InputObject,               
        [Parameter(
            Mandatory = $False,
            Position = 2,
            ParameterSetName = '',
            ValueFromPipeline = $False)]
        [switch]$Enable, 
        [Parameter(
            Mandatory = $False,
            Position = 3,
            ParameterSetName = '',
            ValueFromPipeline = $False)]
        [System.Object]$Category,  
        [Parameter(
            Mandatory = $False,
            Position = 4,
            ParameterSetName = '',
            ValueFromPipeline = $False)]
        [System.Object]$Group, 
        [Parameter(
            Mandatory = $False,
            Position = 5,
            ParameterSetName = '',
            ValueFromPipeline = $False)]
        [System.Object]$Classification,
        [Parameter(
            Mandatory = $False,
            Position = 6,
            ParameterSetName = '',
            ValueFromPipeline = $False)]
        [Switch]$Disable,
        [Parameter(Position=7)]
        [Switch]$PassThru
    )

    Process {
        If ($pscmdlet.parametersetname -eq "Name") {
            if ($wsus) {
                #Locate rule by name
                Write-Verbose "Locating Rule by name"
                $rule = $wsus.GetInstallApprovalRules() | Where {
                    $_.Name -eq $name
                }
                If ($rule -eq $Null) {
                    Write-Warning "No rules found by given name"
                    Continue
                }
            }
            else {
                Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
                Break
            }
        } Else {
            #Rule is coming in as an object
            Write-Verbose "Rule is an object"
            $rule = $inputobject
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
        If ($Disable) {
            If ($pscmdlet.ShouldProcess($Name)) {        
                #Disable the rule for use
                Write-Verbose "Disabling Rule"
                $rule.Enabled = $False
            }
        }        
    }        
    End{ 
        If ($pscmdlet.ShouldProcess($Name)) {        
            #Save the Rule
            Write-Verbose "Saving rule"
            $rule.Save()
            Write-Output ("Rule: {0} has been updated." -f $Rule.name)
        }
        If ($PSBoundParameters["PassThru"]) {
            Write-Output $Rule
        }
    } 
}
