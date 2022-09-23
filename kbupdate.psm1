#requires -Version 3.0
$script:ModuleRoot = $PSScriptRoot

Import-Module "$PSScriptRoot/library/Microsoft.Deployment.Compression.Cab.dll", "$PSScriptRoot/library/Microsoft.Deployment.Compression.dll"

function Import-ModuleFile {
    <#
		.SYNOPSIS
			Loads files into the module on module import.

		.DESCRIPTION
			This helper function is used during module initialization.
			It should always be dotsourced itself, in order to proper function.

			This provides a central location to react to files being imported, if later desired

		.PARAMETER Path
			The path to the file to load

		.EXAMPLE
			PS C:\> . Import-ModuleFile -File $function.FullName

			Imports the file stored in $function according to import policy
	    #>
    [CmdletBinding()]
    Param (
        [string]
        $Path
    )

    if ($doDotSource) { . $Path }
    else { $ExecutionContext.InvokeCommand.InvokeScript($false, ([scriptblock]::Create([io.file]::ReadAllText($Path))), $null, $null) }
}

# Import all internal functions
foreach ($function in (Get-ChildItem "$ModuleRoot\private" -Filter "*.ps1" -Recurse -ErrorAction Ignore)) {
    . Import-ModuleFile -Path $function.FullName
}

# Import all public functions
foreach ($function in (Get-ChildItem "$ModuleRoot\public" -Filter "*.ps1" -Recurse -ErrorAction Ignore)) {
    . Import-ModuleFile -Path $function.FullName
}

# Setup initial collections
if (-not $script:kbcollection) {
    $script:kbcollection = [hashtable]::Synchronized(@{ })
}

if (-not $script:compcollection) {
    $script:compcollection = [hashtable]::Synchronized(@{ })
}

$script:languages = . "$ModuleRoot\library\languages.ps1"
$script:languagescsv = Import-Csv -Path "$ModuleRoot\library\languages.tsv" -Delimiter `t


if (-not $IsLinux -and -not $IsMacOs) {
    # for those of us who are loading the psm1 directly
    try {
        Import-Module -Name kbupdate-library -ErrorAction Stop
    } catch {
        throw "kbupdate-library is required to import this module"
    }
    $kblib = Split-Path -Path (Get-Module -Name kbupdate-library | Select-Object -Last 1).Path
    $script:basedb = (Get-ChildItem -Path "$kblib\*.sqlite" -Recurse).FullName
}

# Register autocompleters
Register-PSFTeppScriptblock -Name Architecture -ScriptBlock { "x64","x86","IA64","ARM64","ARM","ARM32" }
Register-PSFTeppScriptblock -Name OperatingSystem -ScriptBlock { "Windows Server 2022", "Windows Server 2019", "Windows Server 2016", "Windows 10", "Windows 8.1", "Windows Server 2012 R2", "Windows 8", "Windows Server 2012", "Windows Server 2012 Hyper-V", "Windows 7", "Windows Server 2008 R2", "Windows Vista", "Windows Server 2008", "Windows Small Business Server (SBS) 2008", "Windows Server 2003", "Windows Small Business Server (SBS) 2003", "Windows XP", "Windows XP Media Center Edition (MCE)", "Windows XP Tablet PC Edition", "Windows 2000", "Small Business Server (SBS) 2000", "Windows NT 4.0", "Windows Millennium Edition (ME)", "Windows 98 Second Edition (SE)", "Windows 98", "Windows 95", "Microsoft Windows Update", "Windows Embedded Compact 2013", "Windows Embedded Compact 7", "Windows Embedded CE 6.0", "Windows CE 5.0", "Windows CE .NET 4.2", "Windows CE .NET 4.1" }
Register-PSFTeppScriptblock -Name Product -ScriptBlock { "Exchange Server 2019", "Exchange Server 2016", "Exchange Server 2013", "Exchange Server 2010", "Exchange Server 2007", "Exchange Server 2003", "Exchange Server 2000", "Exchange Server 5.5", "Exchange Server 5.0", "Exchange Server 4.0", "Microsoft Office 365", "Outlook 2019", "Excel 2019", "Word 2019", "Access 2019", "Outlook 2016", "Excel 2016", "Word 2016", "Access 2016", "Outlook 2013", "Excel 2013", "Word 2013", "Access 2013", "Outlook 2010", "Excel 2010", "Word 2010", "Access 2010", "Outlook 2007", "Excel 2007", "Word 2007", "Access 2007", "PowerPoint 2007", "Visio 2007", "Publisher 2007", "Project 2007", "OneNote 2007", "InfoPath 2007", "Microsoft Office Groove 2007", "Outlook 2003", "Excel 2003", "Word 2003", "Access 2003", "PowerPoint 2003", "FrontPage 2003", "Visio 2003", "Publisher 2003", "Project 2003", "OneNote 2003", "InfoPath 2003", "Outlook 2002 (Outlook XP)", "Excel 2002 (Excel XP)", "Word 2002 (Word XP)", "Access 2002 (Access XP)", "PowerPoint 2002 (PowerPoint XP)", "FrontPage 2002 (FrontPage XP)", "Visio 2002 (Visio XP)", "Publisher 2002 (Publisher XP)", "Project 2002 (Project XP)", "Outlook 2000", "Excel 2000", "Word 2000", "Access 2000", "PowerPoint 2000", "FrontPage 2000", "Visio 2000", "Publisher 2000", "Project 2000", "Microsoft Office Live Meeting 2005", "Microsoft Works Suite 2003", "Microsoft Works Suite 2002", "Microsoft Works Suite 2001", "Microsoft Works 2000", "SharePoint Server 2019", "SharePoint Server 2016", "SharePoint Server 2013", "SharePoint Server 2010", "SharePoint Server 2007", "SharePoint Portal Server 2003", "SharePoint Portal Server 2001", "BizTalk Server 2006", "BizTalk Server 2004", "BizTalk Server 2002", "BizTalk Server 2000", "Internet Security and Acceleration (ISA) Server 2006", "Internet Security and Acceleration (ISA) Server 2004", "Internet Security and Acceleration (ISA) Server 2000", "System Center Essentials (SCE) 2010", "System Center Essentials (SCE) 2007", "System Center Operations Manager (SCOM) 2012", "System Center Virtual Machine Manager (SCVMM) 2012", "System Center Orchestrator (SCO) 2012", "System Center Service Manager (SCSM) 2012", "System Center Configuration Manager (SCCM) 2012", "System Center Configuration Manager (SCCM) 2007", "Systems Management Server (SMS) 2003", "Systems Management Server (SMS) 2.0", "Systems Management Server (SMS) 1.2", "Systems Management Server (SMS) 1.1", "Systems Management Server (SMS) 1.0", "SNA Server 4.0", "SNA Server 3.0", "System Center Operations Manager (SCOM) 2007", "Operations Manager (MOM) 2005", "Operations Manager (MOM) 2000", "Host Integration Server (HIS) 2004", "Host Integration Server (HIS) 2000", "Commerce Server 2007", "Commerce Server 2002", "Commerce Server 2000", "Dynamics CRM 3.0", "Zune", "Xbox 360", "Internet Explorer 11", "Internet Explorer 10", "Internet Explorer 9", "Internet Explorer 8", "Internet Explorer 7", "Internet Explorer 6", "Internet Explorer 5.5", "Internet Explorer 5.0", "SQL Server 2017", "SQL Server 2016", "SQL Server 2014", "SQL Server 2012", "SQL Server 2008 R2", "SQL Server 2008", "SQL Server 2005", "SQL Server 2000", "SQL Server 7.0", "Microsoft Data Access Components (MDAC) 2.8", "Microsoft Data Access Components (MDAC) 2.7", "Microsoft Data Access Components (MDAC) 2.6", "Microsoft Data Access Components (MDAC) 2.5", "Microsoft Data Access Components (MDAC) 2.1", "Visual FoxPro 9.0", "Visual FoxPro 8.0", "Visual FoxPro 7.0", "Visual FoxPro 6.0", ".NET Framework 4.7", ".NET Framework 4.6", ".NET Framework 4.5", ".NET Framework 4", ".NET Framework 3.5", ".NET Framework 3.0", ".NET Framework 2.0", ".NET Framework 1.1", ".NET Framework 1.0", "ASP.NET 2.0", "ASP.NET 1.1", "ASP.NET 1.0", "Visual Studio 2008", "Visual Studio 2005", "Visual C++ 2005", "Visual C# 2005", "Visual Basic 2005", "Visual Studio .NET 2003", "Visual C++ .NET 2003", "Visual C# .NET 2003", "Visual Basic .NET 2003", "Visual Studio .NET 2002", "Visual C++ .NET 2002", "Visual C# .NET 2002", "Visual Basic .NET 2002", "Visual Studio 6.0", "Visual C++ 6.0", "Visual Basic 6.0", "Windows Media Player 11", "Windows Media Player 10", "Windows Media Player 9", "Internet Information Services (IIS) 7.0", "Internet Information Services (IIS) 6.0", "Internet Information Services (IIS) 5.1", "Internet Information Services (IIS) 5.0", "Office Accounting 2007", "Small Business Accounting 2006", "Money 2007", "Money 2006", "Money 2005", "Money 2004", "Money 2003", "Money 2002", "Money 2001", "Visual SourceSafe 6.0", "Microsoft Encarta Encyclopedia 2000", "Age of Empires III (AoE3)", "Age of Empires II (AoE2)", "Age of Mythology", "Zoo Tycoon 2", "Zoo Tycoon", "Microsoft Mail for Appletalk Networks 3.1", "Microsoft Mail for Appletalk Networks 3.0" }
# Languge is a tough one
#Register-PSFTeppScriptblock -Name Language -ScriptBlock { [System.Globalization.CultureInfo]::GetCultures("AllCultures") | Where-Object Name -ne $null | Select-Object -ExpandProperty DisplayName }
Register-PSFTeppScriptblock -Name Language -ScriptBlock { "Afrikaans", "Afrikaans (South Africa)", "Arabic", "Arabic (U.A.E.)", "Arabic (Bahrain)", "Arabic (Algeria)", "Arabic (Egypt)", "Arabic (Iraq)", "Arabic (Jordan)", "Arabic (Kuwait)", "Arabic (Lebanon)", "Arabic (Libya)", "Arabic (Morocco)", "Arabic (Oman)", "Arabic (Qatar)", "Arabic (Saudi Arabia)", "Arabic (Syria)", "Arabic (Tunisia)", "Arabic (Yemen)", "Azeri (Latin)", "Azeri (Latin) (Azerbaijan)", "Azeri (Cyrillic) (Azerbaijan)", "Belarusian", "Belarusian (Belarus)", "Bulgarian", "Bulgarian (Bulgaria)", "Bosnian (Bosnia and Herzegovina)", "Catalan", "Catalan (Spain)", "Czech", "Czech (Czech Republic)", "Welsh", "Welsh (United Kingdom)", "Danish", "Danish (Denmark)", "German", "German (Austria)", "German (Switzerland)", "German (Germany)", "German (Liechtenstein)", "German (Luxembourg)", "Divehi", "Divehi (Maldives)", "Greek", "Greek (Greece)", "English", "English (Australia)", "English (Belize)", "English (Canada)", "English (Caribbean)", "English (United Kingdom)", "English (Ireland)", "English (Jamaica)", "English (New Zealand)", "English (Republic of the Philippines)", "English (Trinidad and Tobago)", "English (United States)", "English (South Africa)", "English (Zimbabwe)", "Esperanto", "Spanish", "Spanish (Argentina)", "Spanish (Bolivia)", "Spanish (Chile)", "Spanish (Colombia)", "Spanish (Costa Rica)", "Spanish (Dominican Republic)", "Spanish (Ecuador)", "Spanish (Castilian)", "Spanish (Spain)", "Spanish (Guatemala)", "Spanish (Honduras)", "Spanish (Mexico)", "Spanish (Nicaragua)", "Spanish (Panama)", "Spanish (Peru)", "Spanish (Puerto Rico)", "Spanish (Paraguay)", "Spanish (El Salvador)", "Spanish (Uruguay)", "Spanish (Venezuela)", "Estonian", "Estonian (Estonia)", "Basque", "Basque (Spain)", "Farsi", "Farsi (Iran)", "Finnish", "Finnish (Finland)", "Faroese", "Faroese (Faroe Islands)", "French", "French (Belgium)", "French (Canada)", "French (Switzerland)", "French (France)", "French (Luxembourg)", "French (Principality of Monaco)", "Galician", "Galician (Spain)", "Gujarati", "Gujarati (India)", "Hebrew", "Hebrew (Israel)", "Hindi", "Hindi (India)", "Croatian", "Croatian (Bosnia and Herzegovina)", "Croatian (Croatia)", "Hungarian", "Hungarian (Hungary)", "Armenian", "Armenian (Armenia)", "Indonesian", "Indonesian (Indonesia)", "Icelandic", "Icelandic (Iceland)", "Italian", "Italian (Switzerland)", "Italian (Italy)", "Japanese", "Japanese (Japan)", "Georgian", "Georgian (Georgia)", "Kazakh", "Kazakh (Kazakhstan)", "Kannada", "Kannada (India)", "Korean", "Korean (Korea)", "Konkani", "Konkani (India)", "Kyrgyz", "Kyrgyz (Kyrgyzstan)", "Lithuanian", "Lithuanian (Lithuania)", "Latvian", "Latvian (Latvia)", "Maori", "Maori (New Zealand)", "FYRO Macedonian", "FYRO Macedonian (Former Yugoslav Republic of Macedonia)", "Mongolian", "Mongolian (Mongolia)", "Marathi", "Marathi (India)", "Malay", "Malay (Brunei Darussalam)", "Malay (Malaysia)", "Maltese", "Maltese (Malta)", "Norwegian (Bokm?l)", "Norwegian (Bokm?l) (Norway)", "Dutch", "Dutch (Belgium)", "Dutch (Netherlands)", "Norwegian (Nynorsk) (Norway)", "Northern Sotho", "Northern Sotho (South Africa)", "Punjabi", "Punjabi (India)", "Polish", "Polish (Poland)", "Pashto", "Pashto (Afghanistan)", "Portuguese", "Portuguese (Brazil)", "Portuguese (Portugal)", "Quechua", "Quechua (Bolivia)", "Quechua (Ecuador)", "Quechua (Peru)", "Romanian", "Romanian (Romania)", "Russian", "Russian (Russia)", "Sanskrit", "Sanskrit (India)", "Sami (Northern)", "Sami (Northern) (Finland)", "Sami (Skolt) (Finland)", "Sami (Inari) (Finland)", "Sami (Northern) (Norway)", "Sami (Lule) (Norway)", "Sami (Southern) (Norway)", "Sami (Northern) (Sweden)", "Sami (Lule) (Sweden)", "Sami (Southern) (Sweden)", "Slovak", "Slovak (Slovakia)", "Slovenian", "Slovenian (Slovenia)", "Albanian", "Albanian (Albania)", "Serbian (Latin) (Bosnia and Herzegovina)", "Serbian (Cyrillic) (Bosnia and Herzegovina)", "Serbian (Latin) (Serbia and Montenegro)", "Serbian (Cyrillic) (Serbia and Montenegro)", "Swedish", "Swedish (Finland)", "Swedish (Sweden)", "Swahili", "Swahili (Kenya)", "Syriac", "Syriac (Syria)", "Tamil", "Tamil (India)", "Telugu", "Telugu (India)", "Thai", "Thai (Thailand)", "Tagalog", "Tagalog (Philippines)", "Tswana", "Tswana (South Africa)", "Turkish", "Turkish (Turkey)", "Tatar", "Tatar (Russia)", "Tsonga", "Ukrainian", "Ukrainian (Ukraine)", "Urdu", "Urdu (Islamic Republic of Pakistan)", "Uzbek (Latin)", "Uzbek (Latin) (Uzbekistan)", "Uzbek (Cyrillic) (Uzbekistan)", "Vietnamese", "Vietnamese (Viet Nam)", "Xhosa", "Xhosa (South Africa)", "Chinese", "Chinese (S)", "Chinese (Hong Kong)", "Chinese (Macau)", "Chinese (Singapore)", "Chinese (T)", "Zulu", "Zulu (South Africa)" }

# Register the actual auto completer
Register-PSFTeppArgumentCompleter -Command Get-KbUpdate, Save-KbUpdate -Parameter Architecture -Name Architecture
Register-PSFTeppArgumentCompleter -Command Get-KbUpdate, Save-KbUpdate -Parameter OperatingSystem -Name OperatingSystem
Register-PSFTeppArgumentCompleter -Command Get-KbUpdate, Save-KbUpdate -Parameter Product -Name Product
Register-PSFTeppArgumentCompleter -Command Get-KbUpdate, Save-KbUpdate -Parameter Language -Name Language


# set some defaults
if ((Get-Command -Name Get-NetConnectionProfile -ErrorAction SilentlyContinue)) {
    $internet = (Get-NetConnectionProfile).IPv4Connectivity -contains "Internet"
} else {
    try {
        $network = [Type]::GetTypeFromCLSID([Guid]"{DCB00C01-570F-4A9B-8D69-199FDBA5723B}")
        $internet = ([Activator]::CreateInstance($network)).GetNetworkConnections() | ForEach-Object {
            $_.GetNetwork().GetConnectivity()
        } | Where-Object { ($_ -band 64) -eq 64 }
    } catch {
        # don't care
    }
}

if ($internet) {
    Write-PSFMessage -Level Verbose -Message "Internet connection detected. Setting source for Get-KbUpdate to Web and Database."
    $PSDefaultParameterValues['Get-KbUpdate:Source'] = @("Web", "Database")
    $PSDefaultParameterValues['Save-KbUpdate:Source'] = @("Web", "Database")
} else {
    Write-PSFMessage -Level Verbose -Message "Internet connection not detected. Setting source for Get-KbUpdate to Database."
    $PSDefaultParameterValues['Get-KbUpdate:Source'] = "Database"
    $PSDefaultParameterValues['Save-KbUpdate:Source'] = "Database"
}

# Disables session caching
Set-PSFConfig -FullName PSRemoting.Sessions.Enable -Value $true -Initialize -Validation bool -Handler { } -Description 'Globally enables session caching for PowerShell remoting'

# New-PSSessionOption
Set-PSFConfig -FullName PSRemoting.PsSessionOption.IncludePortInSPN -Value $false -Initialize -Validation bool -Description 'Changes the value of -IncludePortInSPN parameter used by New-PsSessionOption which is used for kbupdate internally when working with PSRemoting.'
Set-PSFConfig -FullName PSRemoting.PsSessionOption.SkipCACheck -Value $false -Initialize -Validation bool -Description 'Changes the value of -SkipCACheck parameter used by New-PsSessionOption which is used for kbupdate internally when working with PSRemoting.'
Set-PSFConfig -FullName PSRemoting.PsSessionOption.SkipCNCheck -Value $false -Initialize -Validation bool -Description 'Changes the value of -SkipCNCheck parameter used by New-PsSessionOption which is used for kbupdate internally when working with PSRemoting.'
Set-PSFConfig -FullName PSRemoting.PsSessionOption.SkipRevocationCheck -Value $false -Initialize -Validation bool -Description 'Changes the value of -SkipRevocationCheck parameter used by New-PsSessionOption which is used for kbupdate internally when working with PSRemoting.'

# New-PSSession
Set-PSFConfig -FullName PSRemoting.PsSession.UseSSL -Value $false -Initialize -Validation bool -Description 'Changes the value of -UseSSL parameter used by New-PsSession which is used for kbupdate internally when working with PSRemoting.'
Set-PSFConfig -FullName PSRemoting.PsSession.Port -Value $null -Initialize -Validation integerpositive -Description 'Changes the -Port parameter value used by New-PsSession which is used for kbupdate internally when working with PSRemoting. Use it when you don''t work with default port number. To reset, use Set-PSFConfig -FullName PSRemoting.PsSession.Port -Value $null'

Set-Alias -Name Get-KbInstalledUpdate -Value Get-KbUpdateSoftware


$null = $PSDefaultParameterValues["Start-Job:InitializationScript"] = {
    $null = Import-Module PSSQLite 4>$null
    $null = Import-Module PSFramework 4>$null
    $null = Import-Module kbupdate 4>$null
}


Start-Import -Name Link -ScriptBlock {
    foreach ($linkresult in (Invoke-SqliteQuery -DataSource $script:basedb -Query "select DISTINCT UpdateId, Link from Link")) {
        $script:linkhash[$linkresult.UpdateId] = $linkresult.Link
    }
}

Start-Import -Name Supersedes -ScriptBlock {
    foreach ($superresult in (Invoke-SqliteQuery -DataSource $script:basedb -Query "select UpdateId, KB, Description from Supersedes")) {
        $script:superhash[$superresult.UpdateId] = [pscustomobject]@{
            KB          = $superresult.KB
            Description = $superresult.Description
        }
    }
}

Start-Import -Name SupersededBy -ScriptBlock {
    foreach ($superbyresult in (Invoke-SqliteQuery -DataSource $script:basedb -Query "select UpdateId, KB, Description, Description from SupersededBy")) {
        $script:superbyhash[$superbyresult.UpdateId] = [pscustomobject]@{
            KB          = $superbyresult.KB
            Description = $superbyresult.Description
        }
    }
}
