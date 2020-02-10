function Set-PSWSUSTargetingMode {
<#
	.SYNOPSIS
		Defines constants for the possible targeting modes. The targeting mode determines if the server or 
        client decides to which group the client belongs.

	.DESCRIPTION
		Determines if the server decides to which group the client belongs or the client decides.
        Defines constants for the possible targeting modes. The targeting mode determines if the
        server or client decides to which group the client belongs.

	.PARAMETER  UpdateServiceConsole
        Servers specify the target group to which the clients belong.

	.PARAMETER  GroupPolicyOrRegistry
        Clients specify the target group to which they belong.
        When the client registers with the WSUS server they can specify to which group they want 
        to belong. If client-side targeting is enabled and the group exists, the client is added to
        the specified group. Otherwise, the client is added to the Unassigned Computers group 

	.EXAMPLE
		Set-PSWSUSTargetingMode -UpdateServiceConsole

	.EXAMPLE
        Set-PSWSUSTargetingMode -GroupPolicyOrRegistry		


	.NOTES
		Name: Set-PSWSUSTargetingMode
        Author: Dubinsky Evgeny
        DateCreated: 1DEC2013

	.LINK
		http://blog.itstuff.in.ua/?p=62#Set-PSWSUSTargetingMode

#>

    [CmdletBinding()]
    Param
    (
        [switch]$UpdateServiceConsole,
        [switch]$GroupPolicyOrRegistry
    )

    Begin
    {
        if($wsus)
        {
            $config = $wsus.GetConfiguration()
            $config.ServerId = [System.Guid]::NewGuid()
            $config.Save()
        }#endif
        else
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }
    }
    Process
    {        
        if($PSBoundParameters['UpdateServiceConsole'])
        {
            $config.TargetingMode = 1
        }#endif
        if($PSBoundParameters['GroupPolicyOrRegistry'])
        {
            $config.TargetingMode = 0
        }#endif
    }#endProcess
    End
    {
        $config.Save()
    }
}
