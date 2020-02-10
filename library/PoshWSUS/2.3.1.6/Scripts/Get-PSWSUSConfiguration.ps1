function Get-PSWSUSConfiguration {
    
    <#
	.SYNOPSIS
        Shows WSUS Server config.
	
	.DESCRIPTION
		Gets an IUpdateServerConfiguration that you use to configure the WSUS server.
	
	.EXAMPLE
        Get-PSWSUS

        Description
        -----------  
        This command will show full list of configuration parameters
	
	.OUTPUTS
		Microsoft.UpdateServices.Internal.BaseApi.UpdateServerConfiguration
	
	.NOTES
        Name: Get-PSWSUS
        Author: Dubinsky Evgeny
        DateCreated: 1DEC2013

    .LINK
		http://blog.itstuff.in.ua/?p=62#Get-PSWSUSPSWSUSConfiguration 
	
    .LINK
        http://msdn.microsoft.com/en-us/library/microsoft.updateservices.administration.iupdateserver.getconfiguration%28v=vs.85%29.aspx

	#>
	
    [CmdletBinding()]
    Param
    (
    )

    Begin
    {
        if($wsus){}#endif
        else
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }
    }
    Process
    { 
        Write-Verbose "Getting WSUS Configuration"
        $wsus.GetConfiguration()
    }
    End{}
}
