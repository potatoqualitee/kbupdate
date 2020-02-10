function Set-PSWSUSEnabledUpdateLanguages {
    <#
	.SYNOPSIS
		Sets whether the WSUS server downloads updates for all languages or for a subset of languages. 

	.DESCRIPTION 
       Collection of language codes to enable for updates. Language codes that are not included in the collection are disabled. 
       You must specify the language code strings in lowercase.

	.PARAMETER Language
		Enables updates for the specified languages.

	.PARAMETER  AllUpdateLanguagesEnabled
		Sets whether the WSUS server downloads updates for all languages or for a subset of languages.
        If $true, the WSUS server downloads updates for all languages. If $false, a call to Languages property
        is made to specify the languages supported by this WSUS server.

	.EXAMPLE
		Get-PSWSUSSupportedUpdateLanguages | where {$_ -in @( 'ru', 'en')} | Set-PSWSUSEnabledUpdateLanguages

	.EXAMPLE
		Set-PSWSUSEnabledUpdateLanguages -Language 'ru','en','uk'

	.EXAMPLE
        Set-PSWSUSEnabledUpdateLanguages -AllUpdateLanguagesEnabled

	.INPUTS
		System.Collections.Specialized.StringCollection

	.NOTES
		Name: Set-PSWSUSEnabledUpdateLanguages
        Author: Dubinsky Evgeny
        DateCreated: 1DEC2013

	.LINK
		http://msdn.microsoft.com/en-us/library/windows/desktop/microsoft.updateservices.administration.iupdateserverconfiguration.setenabledupdatelanguages(v=vs.85).aspx
    
    .LINK
	    http://msdn.microsoft.com/en-us/library/windows/desktop/microsoft.updateservices.administration.iupdateserverconfiguration.allupdatelanguagesenabled(v=vs.85).aspx    
    
    .LINK
		http://blog.itstuff.in.ua/?p=62#Set-PSWSUSEnabledUpdateLanguages

    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(ValueFromPipeline=$true,Position = 0)]$Language,
        [switch]$AllUpdateLanguagesEnabled
    )

    Begin
    {
        if($wsus)
        {
            $config = $wsus.GetConfiguration()
            $config.ServerId = [System.Guid]::NewGuid()
            $config.Save()
            
            if($PSBoundParameters['Language'])
            {
                $objects = @()
                $config.AllUpdateLanguagesEnabled = $false
            }#endif
        }#endif
        else
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }#endelse
    }
    Process
    { 
            if($PSBoundParameters['Language'])
            {
                    [System.Collections.Specialized.StringCollection]$objects += $Language
            }#endif
            if($PSBoundParameters['AllUpdateLanguagesEnabled'])
            {
                    $config.AllUpdateLanguagesEnabled = $true
            }#endif
    }
    End{
        Write-Verbose "Setting Languages for wsus updates."
        if ($AllUpdateLanguagesEnabled -eq $false)
        {
            $config.SetEnabledUpdateLanguages($objects)            
        }#endif
        $config.Save()
    }
}
