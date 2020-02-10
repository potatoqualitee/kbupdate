function Get-PSWSUSUpdateSummaryPerClient {
    <#  
    .SYNOPSIS  
        Gets the summary of all updates for a client
        
    .DESCRIPTION
       Gets the summary of all updates for a client
    
    .PARAMETER ComputerScope
        Specified scope of computers to perform query against
        
    .PARAMETER UpdateScope
        Specified scope of updates to perform query against
        
    .NOTES  
        Name: Get-PSWSUSUpdateSummaryForClient
        Author: Boe Prox
        DateCreated: 23NOV2011 
        DateModified: 21 July 2015
               
    .LINK  
        https://learn-powershell.net
        
    .EXAMPLE    
    Get-PSWSUSUpdateSummaryPerClient -ComputerScope (New-PSWSUSComputerScope) -UpdateScope (New-PSWSUSUpdateScope)

    Computer                  InstalledCount  NeededCount       FailedCount
    --------                  --------------  -----------       -----------
    Server1                   108             8                 0
    Server2                   99              9                 0
    Server3                   184             13                0
    Server4                   98              5                 14
    Server5                   151             8                 0
    Server6                   128             7                 0
    Server7                   154             9                 0
    Server8                   151             8                 0
    Server9                   155             8                 0
    Server10                  149             12                0

    Description
    -----------    
    Displays a summary for each client and their number of installed, needed and failed updates.
 
    #> 
    [cmdletbinding(
    	ConfirmImpact = 'low'
    )]
    Param(
        [Parameter(Position = 0)]
        [Microsoft.UpdateServices.Administration.ComputerTargetScope]$ComputerScope,
        [Parameter(Position = 1)]
        [Microsoft.UpdateServices.Administration.UpdateScope]$UpdateScope                                                                                          
    )
    Begin {                
        if($wsus)
        {
            $ErrorActionPreference = 'stop'
            $hash = @{}
        }#endif
        else
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }
    }
    Process {
        If ($PSBoundParameters['UpdateScope']) {
            Write-Verbose "Adding update scope to table"
            $hash['UpdateScope'] = $UpdateScope
        } Else {
            Write-Verbose "Using default update scope"
            $hash['UpdateScope'] = New-PSWSUSUpdateScope
        }
        If ($PSBoundParameters['ComputerScope']) {
            Write-Verbose "Adding Computer scope to table"
            $hash['ComputerScope'] = $ComputerScope
        } Else {
            Write-Verbose "Using default Computer scope"
            $hash['ComputerScope'] = New-PSWSUSComputerScope
        }
        Write-Verbose ('Performing query based on scopes')
        $wsus.GetSummariesPerComputerTarget($hash['UpdateScope'],$hash['ComputerScope']) | ForEach {
            $_.pstypenames.insert(0,'Microsoft.UpdateServices.Internal.BaseApi.UpdateSummary.Client')
            $_
        }
    }  
    End {
        $ErrorActionPreference = 'continue'    
    } 
}
