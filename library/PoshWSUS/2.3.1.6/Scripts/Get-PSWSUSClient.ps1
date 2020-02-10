function Get-PSWSUSClient {
    <#  
    .SYNOPSIS  
        Retrieves information about a WSUS client.
        
    .DESCRIPTION
        Retrieves information about a WSUS client.
        
    .PARAMETER Computername
        Name of the client to search for. Accepts a partial name. If left blank, then all clients displayed

    .PARAMETER IncludedInstallationState
        Update installation states to search for

    .PARAMETER ExcludedInstallState
        Installation states to exclude

    .PARAMETER ComputerTargetGroups
        List of target groups to search

    .PARAMETER FromLastStatusTime
        Earliest reported status time

    .PARAMETER ToLastStatusTime
        Latest last reported status time to search for

    .PARAMETER FromLastSyncTime
        Earliest last synchronization time to search for

    .PARAMETER ToLastSyncTime
        Latest last synchronization time to search for

    .PARAMETER OSFamily
        Operating system family for which to search

    .PARAMETER IncludeSubGroups
        List of target groups to search

    .PARAMETER IncludeDownstreamComputerTargets
        Clients of a downstream server, not clients of this server, should be included
        
    .NOTES  
        Name: Get-PSWSUSClient
        Author: Boe Prox
        Version History: 
            1.2 | 18 Feb 2015
                -Renamed to Get-PSWSUSClient
                -Add multiple parameters
            1.0 | 24 Sept 2010
                -Initial Version
               
    .LINK  
        https://learn-powershell.net
        
    .EXAMPLE  
    Get-PSWSUSClient -Computername "server1"

    Description
    -----------      
    This command will search for and display all computers matching the given input. 

    .EXAMPLE  
    Get-PSWSUSClient -ToLastSyncTime (Get-Date).AddDays(-30)

    Description
    -----------      
    This command will search for and display all computers that have not synced since in the past 30 days. 

    .EXAMPLE  
    $Groups = Get-PSWSUSGroup -Name 'Windows Server 2012 R2'
    Get-PSWSUSClient -ComputerTargetGroups $Groups

    Description
    -----------      
    This command will search for and display all computers that are members of the specified group. 
           
    #> 
    [cmdletbinding(
    	DefaultParameterSetName = 'AllComputers'
    )]
        Param(            
            [Parameter(Position=0,ParameterSetName = 'Computer',ValueFromPipeline = $True)]
            [string[]]$Computername,
            [Parameter(ParameterSetName='ComputerScope')]
            [Microsoft.UpdateServices.Administration.UpdateInstallationStates]$IncludedInstallationState,
            [Parameter(ParameterSetName='ComputerScope')]
            [Microsoft.UpdateServices.Administration.UpdateInstallationStates]$ExcludedInstallState,
            [Parameter(ParameterSetName='ComputerScope')]
            [Microsoft.UpdateServices.Internal.BaseApi.ComputerTargetGroup[]]$ComputerTargetGroups,
            [Parameter(ParameterSetName='ComputerScope')]
            [DateTime]$FromLastStatusTime,
            [Parameter(ParameterSetName='ComputerScope')]
            [DateTime]$ToLastStatusTime,
            [Parameter(ParameterSetName='ComputerScope')]
            [DateTime]$FromLastSyncTime,
            [Parameter(ParameterSetName='ComputerScope')]
            [DateTime]$ToLastSyncTime,
            [Parameter(ParameterSetName='ComputerScope')]
            [string]$OSFamily,
            [Parameter(ParameterSetName='ComputerScope')]
            [switch]$IncludeSubGroups,
            [Parameter(ParameterSetName='ComputerScope')]
            [switch]$IncludeDownstreamComputerTargets
        )
    Begin {                
        if($wsus)
        {
            $ErrorActionPreference = 'Stop'  
            If ($PSCmdlet.ParameterSetName -eq 'ComputerScope') {
                $ComputerScope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope  
                If ($PSBoundParameters['IncludedInstallationState']) {
                    $ComputerScope.IncludedInstallationStates = $IncludedInstallationState
                }
                If ($PSBoundParameters['ExcludedInstallState']) {
                    $ComputerScope.ExcludedInstallationStates = $ExcludedInstallState
                }
                If ($PSBoundParameters['FromLastStatusTime']) {
                    $ComputerScope.FromLastReportedStatusTime = $FromLastStatusTime
                }
                If ($PSBoundParameters['ToLastStatusTime']) {
                    $ComputerScope.ToLastReportedStatusTime = $ToLastStatusTime
                }
                If ($PSBoundParameters['FromLastSyncTime']) {
                    $ComputerScope.FromLastSyncTime = $FromLastSyncTime
                }
                If ($PSBoundParameters['ToLastSyncTime']) {
                    $ComputerScope.ToLastSyncTime = $ToLastSyncTime
                }
                If ($PSBoundParameters['IncludeSubGroups']) {
                    $ComputerScope.IncludeSubgroups = $IncludeSubGroups
                }
                If ($PSBoundParameters['OSFamily']) {
                    $ComputerScope.OSFamily = $OSFamily
                }
                If ($PSBoundParameters['IncludeDownstreamComputerTargets']) {
                    $ComputerScope.IncludeDownstreamComputerTargets = $IncludeDownstreamComputerTargets
                }
                If ($PSBoundParameters['ComputerTargetGroups']) {
                    [void]$ComputerScope.ComputerTargetGroups.AddRange($ComputerTargetGroups)
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
            'AllComputers' {
                Write-Verbose "Gather all computers in WSUS"
                $wsus.GetComputerTargets()           
            }
            'Computer' {
                ForEach ($Computer in $Computername) {
                    Write-Verbose "Retrieve computer in WSUS"
                    Try {      
                        $wsus.SearchComputerTargets($Computer)
                    } Catch {
                        Write-Warning ("Unable to retrieve {0} from database." -f $Computer)
                    }
                }             
            }
            'ComputerScope' {
                Write-Verbose "Retrieve computers based on computer scope"
                $wsus.GetComputerTargets($ComputerScope)
            }
        } 
    }
    End {
        $ErrorActionPreference = 'Continue'    
    }   
}
