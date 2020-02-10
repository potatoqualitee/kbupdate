function Get-PSWSUSUpdateApproval {
    <#  
    .SYNOPSIS  
        Lists approval summary for each update.
        
    .DESCRIPTION
        Lists approval summary for each update. If an update has been declined,it will be ignored.
        
    .PARAMETER Update
        Name of the update to get approval summary from. Can be a string of any kind.
        
    .PARAMETER IncludeText
        Text to include in search

    .PARAMETER ExcludeText
        Text to exclude from search

    .PARAMETER ApprovedState
        Approval states to search for

    .PARAMETER UpdateType
        Update types to search for

    .PARAMETER ComputerTargetGroups
        List of target groups to search for approvals

    .PARAMETER ExcludeOptionalUpdates
        Exclude optional updates from the list

    .PARAMETER IsWsusInfrastructureUpdate
        Filter for WSUS infrastructure updates

    .PARAMETER IncludedInstallationState
        Installation states to search for
     
    .PARAMETER ExcludedInstallState
        Installation states to exclude

    .PARAMETER FromArrivalDate
        Minimum arrival date to search for

    .PARAMETER ToArrivalDate
        Maximum arrival date to search for

    .PARAMETER FromCreationDate
        Minimum creation date to search for

    .PARAMETER ToCreationDate
        Maximum creation date to search for

    .PARAMETER UpdateApprovalAction
        Update approval actions to search for

    .PARAMETER UpdateSource
        Update sources to search for

    .PARAMETER Category
        List of update categories to search.

    .PARAMETER Classification
        List of update classifications to search
        
    .NOTES  
        Name: Get-PSWSUSUpdateApproval
        Author: Boe Prox
        DateCreated: 08Dec2011 
               
    .LINK  
        https://learn-powershell.net
        
    .EXAMPLE   
    Get-PSWSUSUpdateApproval -TextIncludes 2546951 

    UpdateTitle          GoLiveTime                Deadline                  AdministratorName    TargetGroup
    -----------          ----------                --------                  -----------------    -----------
    Microsoft SQL Ser... 11/8/2011 2:18:01 PM      12/31/9999 11:59:59 PM    rivendell\administrator    TESTGROUP
    Microsoft SQL Ser... 11/8/2011 2:18:01 PM      12/31/9999 11:59:59 PM    rivendell\administrator    TESTGROUP1
    Microsoft SQL Ser... 11/8/2011 2:18:00 PM      12/31/9999 11:59:59 PM    rivendell\administrator    All Computers    

    Description
    -----------    
    Lists the approval summary for update 2546951
    
    .EXAMPLE
    $updatescope = New-PSWSUSUpdateScope -FromArrivalDate "11/01/2011"
    Get-PSWSUSUpdateApproval -UpdateScope $updatescope
    
    UpdateTitle          GoLiveTime                Deadline                  AdministratorName    TargetGroup
    -----------          ----------                --------                  -----------------    -----------
    Security Update f... 11/10/2011 6:01:15 AM     12/31/9999 11:59:59 PM    WUS Server           Unassigned Computers
    Security Update f... 11/10/2011 6:01:16 AM     12/31/9999 11:59:59 PM    WUS Server           TESTGROUP
    Security Update f... 11/10/2011 6:01:16 AM     12/31/9999 11:59:59 PM    WUS Server           GROUP1
    Security Update f... 11/10/2011 6:01:16 AM     12/31/9999 11:59:59 PM    WUS Server           Exchange
    Security Update f... 11/10/2011 6:01:17 AM     12/31/9999 11:59:59 PM    WUS Server           Server2008    
    ...
    
    Description
    -----------   
    Lists all updates approval summaries for updates approved from 11/01/2011 up to the present day
     
    #> 
    [cmdletbinding(
    	ConfirmImpact = 'low',
        DefaultParameterSetName = '__Default'
    )]
    Param(
        [Parameter(Position = 0, ParameterSetName = 'Update',ValueFromPipeline=$True)]
        [Object]$Update, 
        [Parameter(ParameterSetName='UpdateScope')]
        [string]$IncludeText,
        [Parameter(ParameterSetName='UpdateScope')]
        [string]$ExcludeText,
        [Parameter(ParameterSetName='UpdateScope')]  
        [Microsoft.UpdateServices.Administration.ApprovedStates]$ApprovedState,
        [Parameter(ParameterSetName='UpdateScope')]
        [Microsoft.UpdateServices.Administration.UpdateTypes]$UpdateType,
        [Parameter(ParameterSetName='UpdateScope')]
        [string[]]$ComputerTargetGroups,
        [Parameter(ParameterSetName='UpdateScope')]
        [switch]$ExcludeOptionalUpdates,
        [Parameter(ParameterSetName='UpdateScope')]
        [switch]$IsWsusInfrastructureUpdate,
        [Parameter(ParameterSetName='UpdateScope')]
        [Microsoft.UpdateServices.Administration.UpdateInstallationStates]$IncludedInstallationState,
        [Parameter(ParameterSetName='UpdateScope')]
        [Microsoft.UpdateServices.Administration.UpdateInstallationStates]$ExcludedInstallState,
        [Parameter(ParameterSetName='UpdateScope')]
        [DateTime]$FromArrivalDate,
        [Parameter(ParameterSetName='UpdateScope')]
        [DateTime]$ToArrivalDate,
        [Parameter(ParameterSetName='UpdateScope')]
        [DateTime]$FromCreationDate,
        [Parameter(ParameterSetName='UpdateScope')]
        [DateTime]$ToCreationDate,
        [Parameter(ParameterSetName='UpdateScope')]
        [Microsoft.UpdateServices.Administration.UpdateApprovalActions]$UpdateApprovalAction,
        [Parameter(ParameterSetName='UpdateScope')]
        [Microsoft.UpdateServices.Administration.UpdateSources]$UpdateSource,
        [Parameter(ParameterSetName='UpdateScope')]
        [Microsoft.UpdateServices.Internal.BaseApi.UpdateCategory[]]$Category,
        [Parameter(ParameterSetName='UpdateScope')]
        [Microsoft.UpdateServices.Internal.BaseApi.UpdateClassification[]]$Classification                                                                                       
    )

    Begin {                
        if($wsus)
        {
            $ErrorActionPreference = 'stop'
            If ($PSCmdlet.ParameterSetName -eq 'UpdateScope') {
                $UpdateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope  
                If ($PSBoundParameters['ApprovedState']) {
                    $UpdateScope.ApprovedStates = $ApprovedState
                }
                If ($PSBoundParameters['IncludedInstallationState']) {
                    $UpdateScope.IncludedInstallationStates = $IncludedInstallationState
                }
                If ($PSBoundParameters['ExcludedInstallState']) {
                    $UpdateScope.ExcludedInstallStates = $ExcludedInstallState
                }
                If ($PSBoundParameters['UpdateApprovalAction']) {
                    $UpdateScope.UpdateApprovalActions = $UpdateApprovalAction
                }
                If ($PSBoundParameters['UpdateSource']) {
                    $UpdateScope.UpdateSources = $UpdateSource
                }
                If ($PSBoundParameters['UpdateType']) {
                    $UpdateScope.UpdateTypes = $UpdateType
                }
                If ($PSBoundParameters['FromArrivalDate']) {
                    $UpdateScope.FromArrivalDate = $FromArrivalDate
                }
                If ($PSBoundParameters['ToArrivalDate']) {
                    $UpdateScope.ToArrivalDate = $ToArrivalDate
                }
                If ($PSBoundParameters['FromCreationDate']) {
                    $UpdateScope.FromCreationDate = $FromCreationDate
                }
                If ($PSBoundParameters['ToCreationDate']) {
                    $UpdateScope.ToCreationDate = $ToCreationDate
                }
                If ($PSBoundParameters['ExcludeOptionalUpdates']) {
                    $UpdateScope.ExcludeOptionalUpdates = $ExcludeOptionalUpdates
                }
                If ($PSBoundParameters['IsWsusInfrastructureUpdate']) {
                    $UpdateScope.IsWsusInfrastructureUpdate = $IsWsusInfrastructureUpdate
                }
                If ($PSBoundParameters['Category']) {
                    [void]$UpdateScope.Categories.AddRange($Category)
                }
                If ($PSBoundParameters['Classification']) {
                    [void]$UpdateScope.Classifications.AddRange($Classification)
                }
                If ($PSBoundParameters['IncludeText']) {
                    $UpdateScope.TextIncludes = $IncludeText
                }
                If ($PSBoundParameters['ExcludeText']) {
                    $UpdateScope.TextNotIncludes = $ExcludeText
                }
                If ($PSBoundParameters['ComputerTargetGroups']) {
                    $Groups = @{}
                    $Wsus.GetComputerTargetGroups() | ForEach {                    
                        $Groups[$_.Name]=$_
                    }
                    ForEach ($Group in $ComputerTargetGroups) {
                        Write-Verbose "Adding Target Group: $($Group)"
                        [void]$UpdateScope.ApprovedComputerTargetGroups.Add($Groups[$Group])
                    }
                }
            }
            Write-Verbose "ParameterSetName: $($PSCmdlet.ParameterSetName)"
        }#endif
        else
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }
    }
    Process {
        Switch ($PSCmdlet.ParameterSetName) {
            'Update' {
                If ($Update -is [Microsoft.UpdateServices.Internal.BaseApi.Update]) {
                    $patches = $update
                } Else {
                    $patches = $Wsus.SearchUpdates($Update)
                }
            }
            'UpdateScope' {$patches = $Wsus.getupdates($UpdateScope)}
            '__Default' {$patches = $Wsus.getupdates()}
        }
        Write-Verbose "Begin locating approvals"
        ForEach ($patch in $patches) {
            If ($PSBoundParameters['ComputerTargetGroups']) {
                ForEach ($ComputerTargetGroup in $UpdateScope.ApprovedComputerTargetGroups) {
                    $patch.GetUpdateApprovals($ComputerTargetGroup)
                }
            } Else {
                $patch.GetUpdateApprovals()
            }
        }       
    }  
    End {
        $ErrorActionPreference = 'continue'    
    } 
}
