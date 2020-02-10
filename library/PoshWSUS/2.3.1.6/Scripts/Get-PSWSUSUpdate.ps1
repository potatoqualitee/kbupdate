function Get-PSWSUSUpdate {
    <#  
    .SYNOPSIS  
        Retrieves information from a wsus update.
        
    .DESCRIPTION
        Retrieves information from a wsus update. Depending on how the information is presented in the search, more
        than one update may be returned.
         
    .PARAMETER Update
        String to search for. This can be any string for the update to include
        KB article numbers, name of update, category, etc... Use of wildcards (*,%) are not allowed in search!

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
     
    .PARAMETER ExcludedInstallationState
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
        Name: Get-PSWSUSUpdate
        Author: Boe Prox
        Version History: 
            1.2 | 18 Feb 2015
                -Renamed to Get-PSWSUSUpdate
                -Add multiple parameters
            1.0 | 24 Sept 2010
                -Initial Version
               
    .LINK  
        https://learn-powershell.net

    .EXAMPLE
        Get-PSWSUSUpdate

        Description
        -----------  
        This command will list every update on the WSUS Server. 
        
    .EXAMPLE 
        Get-PSWSUSUpdate -update "Exchange"

        Description
        -----------  
        This command will list every update that has 'Exchange' in it.
    
    .EXAMPLE
        Get-PSWSUSUpdate -update "KB925474"

        Description
        -----------  
        This command will list every update that has 'KB925474' in it.

    .EXAMPLE
        $Categories = Get-PSWSUSCategory|Where{$_.title -match 'server 2012'}
        Get-PSWSUSUpdate -Category $Categories

        Description
        -----------
        Gets all updates matching the Windows Server 2012 category
       
    #> 
    [cmdletbinding(
        DefaultParameterSetName = 'All'
    )]
        Param(
            [Parameter(Position=0,ValueFromPipeline = $True,ParameterSetName = 'Update')]
            [string[]]$Update,
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
            [Microsoft.UpdateServices.Administration.UpdateInstallationStates]$ExcludedInstallationState,
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
                If ($PSBoundParameters['ExcludedInstallationState']) {
                    $UpdateScope.ExcludedInstallationStates = $ExcludedInstallationState
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
                ForEach ($Item in $Update) {
                    Write-Verbose "Searching for $($Update)"
                    $Wsus.SearchUpdates($Item)
                }            
            }
            'UpdateScope' {
                $Wsus.getupdates($UpdateScope)
            }
            'All'{
                $Wsus.getupdates()
            }
        }
    }
    End {        
        $ErrorActionPreference = 'continue' 
    }   
}
