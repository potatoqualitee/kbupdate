function Get-PSWSUSUpdatePerClient {
    <#  
    .SYNOPSIS  
        Gets the summary of all updates for a client
        
    .DESCRIPTION
       Gets the summary of all updates for a client
        
    .PARAMETER ComputerName
        Name of the client to query
    
    .PARAMETER ComputerObject
        Collection of computers to query
        
    .PARAMETER UpdateScope
        Specified scope of updates to perform query against
        
    .NOTES  
        Name: Get-PSWSUSUpdatePerComputer
        Author: Boe Prox
        DateCreated: 23NOV2011 
               
    .LINK  
        https://learn-powershell.net
        
    .EXAMPLE    
    Get-PSWSUSUpdatePerClient -UpdateScope (New-PSWSUSUpdateScope -IncludedInstallationStates Failed)
    
    Computername         TargetGroup               UpdateKB   UpdateTitle                              UpdateInstallationSt UpdateApprovalA
                                                                                                       ate                  ction
    ------------         -----------               --------   -----------                              -------------------- ---------------
    TEST1                Servers - Test            979909     Microsoft .NET Framework 3.5 SP1 and ... Failed               Install
    TEST2                Servers - Test            983583     Security Update for .NET Framework 2.... Failed               Install
    TEST2                Servers - Test            2418241    Security Update for Microsoft .NET Fr... Failed               Install
    TEST3                Servers - Test            2446704    Security Update for .NET Framework 2.... Failed               Install
    TEST5                Servers - Test            2478658    Security Update for .NET Framework 2.... Failed               Install
    ... 
        
    Descripton
    ----------
    This example will gather all failed updates from all of the clients on the WSUS server using the UpdateScope.
    
    .EXAMPLE
    Get-PSWSUSUpdatePerClient -Computername Test1 -UpdateScope (New-PSWSUSUpdateScope -IsWsusInfrastructureUpdate)
    
    Computername         TargetGroup               UpdateKB   UpdateTitle                              UpdateInstallationSt UpdateApprovalA
                                                                                                       ate                  ction
    ------------         -----------               --------   -----------                              -------------------- ---------------
    TEST1                Servers - Test            842773     Update for Background Intelligent Tra... NotApplicable        Install
    TEST1                Servers - Test            898461     Update for Windows XP (KB898461)         NotApplicable        Install
    TEST1                Servers - Test            938759     Update for Windows Server 2003 (KB938... Installed            Install
    TEST1                Servers - Test            938759     Update for Windows Server 2003 for It... NotApplicable        Install
    TEST1                Servers - Test            938759     Update for Windows Server 2003 x64 Ed... NotApplicable        Install  
    
    Description
    -----------  
    This example gets all updates from TEST1 that are WSUS infrastructure related updates.
    
    #> 
    [cmdletbinding(
    	ConfirmImpact = 'low',
        DefaultParameterSetName = 'ComputerName'
    )]
    Param(
        [Parameter(Position = 0, ParameterSetName = 'ComputerName')]
        [string]$ComputerName, 
        [Parameter(Position = 0, ParameterSetName = 'ComputerObject',ValueFromPipeline = $True)]
        [Microsoft.UpdateServices.Internal.BaseApi.ComputerTarget]$ComputerObject,
        [Parameter(Position = 1, ParameterSetName = '')]
        [Microsoft.UpdateServices.Administration.UpdateScope]$UpdateScope                                                                                          
    )
    Begin {                
        $ErrorActionPreference = 'stop'
        $hash = @{}
    }
    Process {
        If ($PSBoundParameters['ComputerName']) {
            $hash['ComputerObject'] = Get-PSWSUSClient -Computername $Computername
        } ElseIf ($PSBoundParameters['ComputerObject']) {
            $hash['ComputerObject'] = $ComputerObject
        } Else {
            $hash['ComputerObject'] = Get-PSWSUSClient
        }
        ForEach ($object in $hash['ComputerObject']) {
            Try {
                If ($PSBoundParameters['UpdateScope']) {
                    $object.GetUpdateInstallationInfoPerUpdate($UpdateScope)
                } Else {
                    $object.GetUpdateInstallationInfoPerUpdate()
                }
            } Catch {
                Write-Warning ("{0}" -f $_.Exception.Message)
            }
        }        
    }  
    End {
        $ErrorActionPreference = 'continue'    
    } 
}
