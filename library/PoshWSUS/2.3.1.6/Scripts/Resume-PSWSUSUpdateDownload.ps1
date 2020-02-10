function Resume-PSWSUSUpdateDownload {
    <#  
    .SYNOPSIS  
        Resumes previously cancelled update download after approval.
        
    .DESCRIPTION
        Resumes previously cancelled update download after approval.
        
    .PARAMETER Update
        Name of cancelled update download to resume download.    
           
    .NOTES  
        Name: Resume-PSWSUSUpdateDownload
        Author: Boe Prox
        DateCreated: 24SEPT2010 
               
    .LINK  
        https://learn-powershell.net
        
    .EXAMPLE  
    Resume-PSWSUSUpdateDownload -update "KB965896"

    Description
    ----------- 
    This command will resume the download of update KB956896 that was previously cancelled.       
    #> 
    [cmdletbinding(
    	ConfirmImpact = 'low',
        SupportsShouldProcess = $True
    )]
    Param(
    [Parameter(Mandatory = $True,ValueFromPipeline = $True,ParameterSetName='Update')]
    $Update,
    [parameter(ParameterSetName='AllUpdates')]
    [switch]$AllUpdates                                          
    ) 
    Begin {
        if($wsus)
        {
            $List = New-Object System.Collections.ArrayList
        }#endif
        else
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }
    }                
    Process {
        If ($pscmdlet.ParameterSetName -eq 'Update') {
            If ($Update -is [Microsoft.UpdateServices.Internal.BaseApi.Update]) {
                [void]$List.Add($Update)
            } Else {
                $List.AddRange(@(Get-PSWSUSUpdate $Update))
            }
            ForEach ($patch in $List) {
                Write-Verbose "Resuming update download"                
                If ($pscmdlet.ShouldProcess($($patch.title))) {
                    $patch.ResumeDownload()
                    Write-Verbose "$($patch.title) download has been resumed."
                }         
            }  
        } ElseIf ($pscmdlet.ParameterSetName -eq 'AllUpdates') {
            If ($pscmdlet.ShouldProcess($($wsus.name))) {
                $wsus.ResumeAllDownloads()
                Write-Verbose "Downloads have been resumed on {0}." -f $wsus.name
            }            
        }     
    }   
} 
