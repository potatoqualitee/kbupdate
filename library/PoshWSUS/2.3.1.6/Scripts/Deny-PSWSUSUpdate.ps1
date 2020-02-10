function Deny-PSWSUSUpdate {
    <#  
    .SYNOPSIS  
        Declines an update on WSUS.
    .DESCRIPTION
        Declines an update on WSUS. Use of the -whatif is advised to be sure you are declining the right patch or patches.

    .PARAMETER Update
        Collection of update/s being declined. This must be an object, otherwise it will fail.  
               
    .NOTES  
        Name: Deny-PSWSUSUpdate
        Author: Boe Prox
        DateCreated: 24SEPT2010 
               
    .LINK  
        https://learn-powershell.net

    .EXAMPLE
    Get-PSWSUSUpdate -Update "Exchange 2010" | Deny-PSWSUSUpdate 

    Description
    -----------  
    This command will decline all updates with 'Exchange 2010' in its metadata.
   
    .EXAMPLE
    $updates = Get-PSWSUSUpdate -update "Exchange 2010" 
    Deny-PSWSUSUpdate -Update $updates

    Description
    -----------  
    This command will decline all updates with 'Exchange 2010' in its metadata.  
     
    .EXAMPLE
    Get-PSWSUSUpdate -Update "Exchange 2010" | Deny-PSWSUSUpdate

    Description
    -----------  
    This command will decline all updates with 'Exchange 2010' in its metadata via the pipeline.    
    #> 
    [cmdletbinding(
        SupportsShouldProcess = $True
    )]
    Param(
        [Parameter(Mandatory = $True,ValueFromPipeline = $True)]
        [ValidateNotNullorEmpty()]
        [Microsoft.UpdateServices.Internal.BaseApi.Update[]]$Update
    )                     
    Process {
        ForEach ($Patch in $Update) {
            #Decline the update
            Write-Verbose "Declining update"                
            If ($pscmdlet.ShouldProcess($Patch.Title,"Decline Update")) {
                $patch.Decline($True) | out-null
                #Print out report of what was declined
                New-Object PSObject -Property @{
                    Patch = $Patch.title
                    IsDeclined = $Patch.isDeclined
                }
            }         
        }
    }    
}
