function Export-PSWSUSMetaData {
    <#  
    .SYNOPSIS  
        Exports WSUS Metadata to a file that can be used for disconnected network patch migrations
        
    .DESCRIPTION
        Exports WSUS Metadata to a file that can be used for disconnected network patch migrations
        
    .PARAMETER FileName
        Name of the metadata file
    
    .PARAMETER LogName
        NAme of the logfile that is generated during export
        
    .NOTES  
        Name: Export-PSWSUSMetaData
        Author: Boe Prox
        DateCreated: 15NOV2011
               
    .LINK  
        https://learn-powershell.net
        
    .EXAMPLE  
    Export-PSWSUSMetaData -FileName "C:\temp\wsusdata.cab" -LogName "C:\temp\WSUSMetaData.log"

    Description
    -----------      
    Exports the WSUS metadata to "C:\temp\wsusdata.cab" along with the logfile
           
    #> 
    [cmdletbinding(
    	ConfirmImpact = 'low',
        SupportsShouldProcess = $True        
    )]
        Param(
            [Parameter(Mandatory=$True,Position = 0,ValueFromPipeline = $True)]
            [string]$FileName,  
            [Parameter(Mandatory=$True,Position = 1,ValueFromPipeline = $True)]
            [string]$LogName                                                            
        )
    
    Begin {
        if(-not $wsus)
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }
    }
    Process {
        If ($pscmdlet.ShouldProcess($FileName,"Export MetaData")) {
            Try {
                Write-OutPUt ("Exporting WSUS Metadata to {0}`nThis may take a while." -f $FileName)
                $Wsus.ExportUpdates($FileName,$LogName)
            } Catch {
                Write-Warning ("Unable to export metadata!`n{0}" -f $_.Exception.Message)
            }
        }
    } 
}
