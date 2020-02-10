function Get-PSWSUSUpdateSummary {
    <#  
    .SYNOPSIS  
        Retrieves summary of the given update.
        
    .DESCRIPTION
        Retrieves summary of the given update.
        
    .PARAMETER Update
        Name of the update to collect data on.
        
    .PARAMETER InputObject
        Update object used to collect data on. 
    
    .PARAMETER ComputerScope
        Computer scope object required to collect update summary data.
        
    .NOTES  
        Name: Get-PSWSUSUpdateSummary
        Author: Boe Prox
        DateCreated: 22NOV2011 
               
    .LINK  
        https://learn-powershell.net
        
    .EXAMPLE  
        $Computerscope = New-PSWSUSComputerScope -FromLastSyncTime "05/05/2010" -ToLastSyncTime "11/01/2011"
        Get-PSWSUSUpdateSummary -Update 938759 -ComputerScope $ComputerScope
        
        UpdateTitle                         UpdateKB   InstalledC NotInstalledCount NotApplicableCount FailedCount
                                                       ount
        -----------                         --------   ---------- ----------------- ------------------ -----------
        Update for Windows Server 2003 (... 938759     1          0                 118                0
        Update for Windows Server 2003 f... 938759     0          0                 119                0
        Update for Windows Server 2003 x... 938759     2          0                 117                0        

        Description
        -----------      
        Gets the update summary based on the given computer scope information
    
    .EXAMPLE
        Get-PSWSUSUpdate -Update 2641690 | Get-PSWSUSUpdateSummary

        UpdateTitle                         UpdateKB   InstalledC NotInstalledCount NotApplicableCount FailedCount
                                                       ount
        -----------                         --------   ---------- ----------------- ------------------ -----------
        Update for Windows Server 2003 (... 2641690    2          1                 53                 0
        Update for Windows Server 2003 f... 2641690    0          0                 115                0
        Update for Windows Server 2003 x... 2641690    1          0                 107                0
        Update for Windows XP x64 Editio... 2641690    0          0                 115                0
        ...
        
        Description
        -----------
        Accepts pipeline input for update and uses a default computer scope to gather update data.
           
    #> 
    [cmdletbinding(
    	ConfirmImpact = 'low',
        DefaultParameterSetName = 'Object'
    )]
        Param(
            [Parameter(
                Position = 0, ParameterSetName = 'NonObject',
                ValueFromPipeline = $True)]
                [string]$Update, 
            [Parameter(
                Position = 0, ParameterSetName = 'Object',
                ValueFromPipeline = $True)]
                [Microsoft.UpdateServices.Internal.BaseApi.Update[]]$InputObject,
            [Parameter(
                Position = 1,ParameterSetName = '')]
                [Microsoft.UpdateServices.Administration.ComputerTargetScope]$ComputerScope                                                                  
        )
    Begin {                
        $ErrorActionPreference = 'Stop'
        If (-NOT $PSBoundParameters.ContainsKey('ComputerScope')) {
            Write-Verbose "Creating default Computer Scope"
            $ComputerScope = New-PSWSUSComputerScope
        }  
    }
    Process {
        If ($PSBoundParameters.ContainsKey('Update')) {
            Write-Verbose "Gathering update data"
            $InputObject = Get-PSWSUSUpdate $update
        }
        Write-Verbose "Preparing report"
        ForEach ($Object in $InputObject) {
            $data = $Object.GetSummary($ComputerScope)
            $data.pstypenames.insert(0,'Microsoft.UpdateServices.Internal.BaseApi.UpdateSummary.Update')
            Write-Output $Data
        }

    }  
    End {
        $ErrorActionPreference = 'continue'    
    } 
}
