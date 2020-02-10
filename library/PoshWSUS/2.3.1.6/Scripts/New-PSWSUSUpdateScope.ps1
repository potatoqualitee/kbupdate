Function New-PSWSUSUpdateScope {
    <#  
    .SYNOPSIS  
        Creates a new Update scope object        
        
    .DESCRIPTION        
        Creates a new Update scope object
        
    .PARAMETER ApprovedStates
        Sets the approval states to search for. An update will be included only if it matches at least one of the specified states. 
        This value may be a combination of any number of values from ApprovedStates. Defaults to Any.
        Accepted values are: "Any","Declined","HasStaleUpdateApprovals","LatestRevisionApproved","NotApproved"
        
    .PARAMETER ExcludedInstallationStates
        Sets the installation states to exclude. An update will be included only if it does not have any computers in any of the specified states. 
        This value may be a combination of any number of values from UpdateInstallationStates. Defaults to 0.
        Accepted values are: "All","Downloaded","Failed","Installed","InstalledPendingReboot","NotApplicable","NotInstalled","Unknown"

    .PARAMETER ExcludeOptionalUpdates
        Sets whether to exclude optional updates from the list.

    .PARAMETER FromArrivalDate
        Sets the minimum arrival date to search for. An update will be included only if its arrival date is greater than or equal to this value.

    .PARAMETER FromCreationDate
        Sets the minimum creation date to search for. An update will be included only if its creation date is greater than or equal to this value. 

    .PARAMETER IncludedInstallationStates
        Sets the installation states to search for. An update will be included only if it has at least one computer in one of the specified states. 
        This value may be a combination of any number of values from UpdateInstallationStates. 
        Accepted values are: "All","Downloaded","Failed","Installed","InstalledPendingReboot","NotApplicable","NotInstalled","Unknown"

    .PARAMETER IsWsusInfrastructureUpdate
        Sets whether or not to filter for WSUS infrastructure updates. If set to true, only WSUS infrastructure updates will be included. 
        If set to false, all updates are included. Defaults to false.

    .PARAMETER TextIncludes
        Sets the string to search for. An update will be included only if its Title, Description, Knowledge Base articles, or security bulletins contains this string.

    .PARAMETER TextNotIncludes
        Sets the string to exclude. An update will be not be included if its Title, Description, Knowledge Base articles, or security bulletins contains this string.

    .PARAMETER ToArrivalDate
        Sets the maximum arrival date to search for. An update will be included only if its arrival date is less than or equal to this value. 

    .PARAMETER ToCreationDate
        Sets the maximum creation date to search for. An update will be included only if its creation date is less than or equal to this value. 

    .PARAMETER UpdateApprovalActions
        Sets the update approval actions to search for. An update will be included only if it is approved to at least one computer target group for one of the specified approval actions. 
        This value may be a combination of any number of values from UpdateApprovalActions. Defaults to All.
        Accepted values are: "All","Install","Uninstall"

    .PARAMETER UpdateSources
        Sets the update sources to search for. An update will be included only if its update source is included in this value. This value may be a combination of any number of values from UpdateSources.
        Accepted values are: "All","MicrosoftUpdate","Other"

    .PARAMETER UpdateTypes        
        Sets the update types to search for. An update will be included only if its update type is included in this value. 
        Accepted values are: "All","Driver","SoftwareApplication","SoftwareUpdate"
               
    .NOTES  
        Name: New-PSWSUSUpdateScope
        Author: Boe Prox
        DateCreated: 09NOV2011 
               
    .LINK  
        https://learn-powershell.net
        
    .EXAMPLE 
   
    #> 
    [cmdletbinding()]
    Param (
        [parameter()]
        [Microsoft.UpdateServices.Administration.ApprovedStates]$ApprovedStates,        
        [parameter()]
        [Microsoft.UpdateServices.Administration.UpdateInstallationStates]$ExcludedInstallationStates,
        [parameter()]
        [switch]$ExcludeOptionalUpdates,
        [parameter()]
        [datetime]$FromArrivalDate, 
        [parameter()]
        [datetime]$FromCreationDate,
        [parameter()]
        [Microsoft.UpdateServices.Administration.UpdateInstallationStates]$IncludedInstallationStates,
        [parameter()]
        [string]$TextIncludes, 
        [parameter()]
        [string]$TextNotIncludes,   
        [parameter()]
        [datetime]$ToArrivalDate,   
        [parameter()]
        [datetime]$ToCreationDate,
        [parameter()]
        [Microsoft.UpdateServices.Administration.UpdateApprovalActions]$UpdateApprovalActions,
        [parameter()]
        [Microsoft.UpdateServices.Administration.UpdateSources]$UpdateSources,
        [parameter()]
        [Microsoft.UpdateServices.Administration.UpdateTypes]$UpdateTypes,
        [parameter()]
        [Switch]$IsWsusInfrastructureUpdate                    
        )
    Begin {
        Write-Verbose "Creating Computer Scope Object"
        $UpdateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
    }
    Process{
        If ($PSBoundParameters['ApprovedStates']) {
            Write-Verbose "Adding values to ApprovedStates property"
            $UpdateScope.ApprovedStates = $ApprovedStates
        }       
        If ($PSBoundParameters['ExcludedInstallationStates']) {
            Write-Verbose "Adding values to ExcludedInstallationStates property"
            $UpdateScope.ExcludedInstallationStates = $ExcludedInstallationStates
        }
        If ($PSBoundParameters['ExcludeOptionalUpdates']) {
            Write-Verbose "Adding values to ExcludeOptionalUpdates property"
            $UpdateScope.ExcludeOptionalUpdates = $True
        }
        If ($PSBoundParameters['FromArrivalDate']) {
            Write-Verbose "Adding values to FromArrivalDate property"
            $UpdateScope.FromArrivalDate = $FromArrivalDate
        }
        If ($PSBoundParameters['FromCreationDate']) {
            Write-Verbose "Adding values to FromCreationDate property"
            $UpdateScope.FromCreationDate = $FromCreationDate
        }
        If ($PSBoundParameters['IncludedInstallationStates']) {
            Write-Verbose "Adding values to IncludedInstallationStates property"
            $UpdateScope.IncludedInstallationStates = $IncludedInstallationStates
        }
        If ($PSBoundParameters['TextIncludes']) {
            Write-Verbose "Adding values to TextIncludes property"
            $UpdateScope.TextIncludes = $TextIncludes
        }
        If ($PSBoundParameters['TextNotIncludes']) {
            Write-Verbose "Adding values to TextNotIncludes property"
            $UpdateScope.TextNotIncludes = $TextNotIncludes
        }
        If ($PSBoundParameters['ToArrivalDate']) {
            Write-Verbose "Adding values to ToArrivalDate property"
            $UpdateScope.ToArrivalDate = $ToArrivalDate
        }
        If ($PSBoundParameters['ToCreationDate']) {
            Write-Verbose "Adding values to ToCreationDate property"
            $UpdateScope.ToCreationDate = $ToCreationDate
        }
        If ($PSBoundParameters['UpdateApprovalActions']) {
            Write-Verbose "Adding values to UpdateApprovalActions property"
            $UpdateScope.UpdateApprovalActions = $UpdateApprovalActions
        }
        If ($PSBoundParameters['UpdateSources']) {
            Write-Verbose "Adding values to UpdateSources property"
            $UpdateScope.UpdateSources = $UpdateSources
        }
        If ($PSBoundParameters['UpdateTypes']) {
            Write-Verbose "Adding values to UpdateTypes property"
            $UpdateScope.UpdateTypes = $UpdateTypes
        }    
        If ($PSBoundParameters['IsWsusInfrastructureUpdate']) {
            Write-Verbose "Adding values to IsWsusInfrastructureUpdate property"
            $UpdateScope.IsWsusInfrastructureUpdate = $True
        }                             
    }
    End {
        Write-Output $UpdateScope
    }
}
