function Get-PSWSUSUpdateSummaryPerGroup {
    <#  
    .SYNOPSIS  
        Retrieves summary of the given update for a specified group.
        
    .DESCRIPTION
        Retrieves summary of the given update for a specified group. All groups will be reported on if none specified.
        
    .PARAMETER UpdateName
        Name of the update to collect data on.
        
    .PARAMETER UpdateObject
        Update object used to collect data on.         
        
    .PARAMETER GroupName
        Name of the group to perform query against. Will default to all groups if not used.        
    
    .PARAMETER IncludeChildGroup
        Includes the child group, if exists
        
    .NOTES  
        Name: Get-PSWSUSUpdateSummaryPerGroup
        Author: Boe Prox
        DateCreated: 23NOV2011 
               
    .LINK  
        https://learn-powershell.net
        
    .EXAMPLE    
    Get-PSWSUSUpdateSummaryPerGroup -UpdateName 2617986 
    UpdateTitle                         ComputerGroup             InstalledCount  NeededCount        FailedCount
    -----------                         -------------             --------------  -----------------  -----------
    Security Update for Microsoft Si... Group1                     0               0                 0
    Security Update for Microsoft Si... Group2                     3               0                 0
    Security Update for Microsoft Si... Group3                     12              0                 0
    Microsoft Silverlight (KB2617986)   Group1                     0               0                 0
    Microsoft Silverlight (KB2617986)   Group2                     14              0                 0
    Microsoft Silverlight (KB2617986)   Group3                     2               0                 0
    ... 

    Description
    -----------    
    Presents a report of all groups and their current update status for update 2617986.  
    
    .EXAMPLE
    Get-PSWSUSUpdateSummaryPerGroup -UpdateName 2617986 -GroupName Group1
    UpdateTitle                         ComputerGroup             InstalledCount  NeededCount       FailedCount
    -----------                         -------------             --------------  ----------------- -----------
    Security Update for Microsoft Si... Group1                    54              0                 0
    Microsoft Silverlight (KB2617986)   Group1                    54              1                 0
               
    Description
    -----------
    Presents a report the Group1 and its current update status for update 2617986. 
    #> 
    [cmdletbinding(
    	ConfirmImpact = 'low',
        DefaultParameterSetName = 'UpdateObject'
    )]
    Param(
        [Parameter(Position = 0, ParameterSetName = 'UpdateNonObject')]
        [Alias("Update")]
        [string]$UpdateName, 
        [Parameter(Position = 0, ParameterSetName = 'UpdateObject',ValueFromPipeline = $True)]
        [Alias("InputObject")]
        [system.object[]]$UpdateObject,
        [Parameter(Position = 1, ParameterSetName = '')]
        [Alias("Name")]
        [string]$GroupName, 
        [Parameter(Position = 2, ParameterSetName = '')]
        [switch]$IncludeChildGroup                                                                                            
    )
    Begin {                
        $ErrorActionPreference = 'stop'
        $hash = @{}
    }
    Process {
        If ($PSBoundParameters['UpdateName']) {
            $hash['UpdateObject'] = Get-PSWSUSUpdate -Update $UpdateName
        } ElseIf ($PSBoundParameters['UpdateObject']) {
            $hash['UpdateObject'] = $UpdateObject
        } Else {
            $hash['UpdateObject'] = Get-PSWSUSUpdate
        }
        If ($PSBoundParameters['GroupName']) {
            Write-Verbose "Gathering data from specified group"
            $hash['GroupObject'] = Get-PSWSUSGroup -Name $GroupName
            ForEach ($Object in $hash['UpdateObject']) {
                Try {
                    If ($PSBoundParameters['IncludeChildGroup']) {
                        $Object.GetSummaryForComputerTargetGroup($hash['GroupObject'],$True) | ForEach {
                            $_.pstypenames.insert(0,'Microsoft.UpdateServices.Internal.BaseApi.UpdateSummary.Group')
                            $_
                        }
                    } Else {
                        $Object.GetSummaryForComputerTargetGroup($hash['GroupObject'],$False) | ForEach {
                            $_.pstypenames.insert(0,'Microsoft.UpdateServices.Internal.BaseApi.UpdateSummary.Group')
                            $_
                        }
                    }
                } Catch {
                    Write-Warning ("{0}" -f $_.Exception.Message)
                }
            }
        } Else {
            Write-Verbose "Gathering data from all groups"
            ForEach ($Object in $hash['UpdateObject']) {
                Try {            
                    If ($PSBoundParameters['IncludeChildGroup']) {
                        $Object.GetSummaryPerComputerTargetGroup($True) | ForEach {
                            $_.pstypenames.insert(0,'Microsoft.UpdateServices.Internal.BaseApi.UpdateSummary.Group')
                            $_
                        }
                    } Else {
                        $Object.GetSummaryPerComputerTargetGroup($False) | ForEach {
                            $_.pstypenames.insert(0,'Microsoft.UpdateServices.Internal.BaseApi.UpdateSummary.Group')
                            $_
                        }
                    }
                } Catch {
                    Write-Warning ("{0}" -f $_.Exception.Message)
                } 
            }           
            
        }
    }  
    End {
        $ErrorActionPreference = 'continue'    
    } 
}
