function Set-PSWSUSConfigTargetingMode {
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
		Set-PSWSUSConfigTargetingMode -UpdateServiceConsole

	.EXAMPLE
        Set-PSWSUSConfigTargetingMode -GroupPolicyOrRegistry		


	.NOTES
		Name: Set-PSWSUSConfigTargetingMode
        Author: Dubinsky Evgeny
        DateCreated: 1DEC2013
        Modified 05 Feb 2014 -- Boe Prox
            -Changed to use ParameterSetName to avoid possibility of using both switches
            -Add -WhatIf support

	.LINK
		http://blog.itstuff.in.ua/?p=62#Set-PSWSUSConfigTargetingMode

#>

    [CmdletBinding(
        SupportsShouldProcess=$True,
        DefaultParameterSetName='UpdateServiceConsole'
    )]
    Param
    (
        [parameter(ParameterSetName='UpdateServiceConsole')]
        [switch]$UpdateServiceConsole,
        [parameter(ParameterSetName='GroupPolicyOrRegistry')]
        [switch]$GroupPolicyOrRegistry
    )

    if(-NOT $wsus)
    {

        Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
        Break
    }
    If ($PSCmdlet.ShouldProcess($wsus.ServerName,'Set Targeting Mode')) {
        Switch ($PSCmdlet.ParameterSetName) {
            'UpdateServiceConsole' {$_wsusconfig.TargetingMode = 1}
            'GroupPolicyOrRegistry' {$_wsusconfig.TargetingMode = 0}
        }   
        If ($PSBoundParameters['UpdateServiceConsole'] -OR $PSBoundParameters['GroupPolicyOrRegistry']) {
            $_wsusconfig.Save()
        }
    }
}
