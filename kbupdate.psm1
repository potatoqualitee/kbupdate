#requires -Version 3.0
$script:ModuleRoot = $PSScriptRoot

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

if (-not $IsLinux -and -not $IsMacOs) {
    [array]$script:basedb = @()
    # for those of us who are loading the psm1 directly
    Import-Module -Name kbupdate-library
    $kblib = Split-Path -Path (Get-Module -Name kbupdate-library | Select-Object -Last 1).Path
    $script:basedb = (Get-ChildItem -Path "$kblib\*.sqlite" -Recurse).FullName
    $script:dailydb = (Get-ChildItem -Path "$PSScriptRoot\library\db\*.sqlite").FullName
}

# Register autocompleters
Register-PSFTeppScriptblock -Name Architecture -ScriptBlock { "x64", "x86", "ia64", "ARM" }
Register-PSFTeppScriptblock -Name OperatingSystem -ScriptBlock { "Windows Server 2019", "Windows Server 2016", "Windows 10", "Windows 8.1", "Windows Server 2012 R2", "Windows 8", "Windows Server 2012", "Windows Server 2012 Hyper-V", "Windows 7", "Windows Server 2008 R2", "Windows Vista", "Windows Server 2008", "Windows Small Business Server (SBS) 2008", "Windows Server 2003", "Windows Small Business Server (SBS) 2003", "Windows XP", "Windows XP Media Center Edition (MCE)", "Windows XP Tablet PC Edition", "Windows 2000", "Small Business Server (SBS) 2000", "Windows NT 4.0", "Windows Millennium Edition (ME)", "Windows 98 Second Edition (SE)", "Windows 98", "Windows 95", "Microsoft Windows Update", "Windows Embedded Compact 2013", "Windows Embedded Compact 7", "Windows Embedded CE 6.0", "Windows CE 5.0", "Windows CE .NET 4.2", "Windows CE .NET 4.1" }
Register-PSFTeppScriptblock -Name Product -ScriptBlock { "Exchange Server 2019", "Exchange Server 2016", "Exchange Server 2013", "Exchange Server 2010", "Exchange Server 2007", "Exchange Server 2003", "Exchange Server 2000", "Exchange Server 5.5", "Exchange Server 5.0", "Exchange Server 4.0", "Microsoft Office 365", "Outlook 2019", "Excel 2019", "Word 2019", "Access 2019", "Outlook 2016", "Excel 2016", "Word 2016", "Access 2016", "Outlook 2013", "Excel 2013", "Word 2013", "Access 2013", "Outlook 2010", "Excel 2010", "Word 2010", "Access 2010", "Outlook 2007", "Excel 2007", "Word 2007", "Access 2007", "PowerPoint 2007", "Visio 2007", "Publisher 2007", "Project 2007", "OneNote 2007", "InfoPath 2007", "Microsoft Office Groove 2007", "Outlook 2003", "Excel 2003", "Word 2003", "Access 2003", "PowerPoint 2003", "FrontPage 2003", "Visio 2003", "Publisher 2003", "Project 2003", "OneNote 2003", "InfoPath 2003", "Outlook 2002 (Outlook XP)", "Excel 2002 (Excel XP)", "Word 2002 (Word XP)", "Access 2002 (Access XP)", "PowerPoint 2002 (PowerPoint XP)", "FrontPage 2002 (FrontPage XP)", "Visio 2002 (Visio XP)", "Publisher 2002 (Publisher XP)", "Project 2002 (Project XP)", "Outlook 2000", "Excel 2000", "Word 2000", "Access 2000", "PowerPoint 2000", "FrontPage 2000", "Visio 2000", "Publisher 2000", "Project 2000", "Microsoft Office Live Meeting 2005", "Microsoft Works Suite 2003", "Microsoft Works Suite 2002", "Microsoft Works Suite 2001", "Microsoft Works 2000", "SharePoint Server 2019", "SharePoint Server 2016", "SharePoint Server 2013", "SharePoint Server 2010", "SharePoint Server 2007", "SharePoint Portal Server 2003", "SharePoint Portal Server 2001", "BizTalk Server 2006", "BizTalk Server 2004", "BizTalk Server 2002", "BizTalk Server 2000", "Internet Security and Acceleration (ISA) Server 2006", "Internet Security and Acceleration (ISA) Server 2004", "Internet Security and Acceleration (ISA) Server 2000", "System Center Essentials (SCE) 2010", "System Center Essentials (SCE) 2007", "System Center Operations Manager (SCOM) 2012", "System Center Virtual Machine Manager (SCVMM) 2012", "System Center Orchestrator (SCO) 2012", "System Center Service Manager (SCSM) 2012", "System Center Configuration Manager (SCCM) 2012", "System Center Configuration Manager (SCCM) 2007", "Systems Management Server (SMS) 2003", "Systems Management Server (SMS) 2.0", "Systems Management Server (SMS) 1.2", "Systems Management Server (SMS) 1.1", "Systems Management Server (SMS) 1.0", "SNA Server 4.0", "SNA Server 3.0", "System Center Operations Manager (SCOM) 2007", "Operations Manager (MOM) 2005", "Operations Manager (MOM) 2000", "Host Integration Server (HIS) 2004", "Host Integration Server (HIS) 2000", "Commerce Server 2007", "Commerce Server 2002", "Commerce Server 2000", "Dynamics CRM 3.0", "Zune", "Xbox 360", "Internet Explorer 11", "Internet Explorer 10", "Internet Explorer 9", "Internet Explorer 8", "Internet Explorer 7", "Internet Explorer 6", "Internet Explorer 5.5", "Internet Explorer 5.0", "SQL Server 2017", "SQL Server 2016", "SQL Server 2014", "SQL Server 2012", "SQL Server 2008 R2", "SQL Server 2008", "SQL Server 2005", "SQL Server 2000", "SQL Server 7.0", "Microsoft Data Access Components (MDAC) 2.8", "Microsoft Data Access Components (MDAC) 2.7", "Microsoft Data Access Components (MDAC) 2.6", "Microsoft Data Access Components (MDAC) 2.5", "Microsoft Data Access Components (MDAC) 2.1", "Visual FoxPro 9.0", "Visual FoxPro 8.0", "Visual FoxPro 7.0", "Visual FoxPro 6.0", ".NET Framework 4.7", ".NET Framework 4.6", ".NET Framework 4.5", ".NET Framework 4", ".NET Framework 3.5", ".NET Framework 3.0", ".NET Framework 2.0", ".NET Framework 1.1", ".NET Framework 1.0", "ASP.NET 2.0", "ASP.NET 1.1", "ASP.NET 1.0", "Visual Studio 2008", "Visual Studio 2005", "Visual C++ 2005", "Visual C# 2005", "Visual Basic 2005", "Visual Studio .NET 2003", "Visual C++ .NET 2003", "Visual C# .NET 2003", "Visual Basic .NET 2003", "Visual Studio .NET 2002", "Visual C++ .NET 2002", "Visual C# .NET 2002", "Visual Basic .NET 2002", "Visual Studio 6.0", "Visual C++ 6.0", "Visual Basic 6.0", "Windows Media Player 11", "Windows Media Player 10", "Windows Media Player 9", "Internet Information Services (IIS) 7.0", "Internet Information Services (IIS) 6.0", "Internet Information Services (IIS) 5.1", "Internet Information Services (IIS) 5.0", "Office Accounting 2007", "Small Business Accounting 2006", "Money 2007", "Money 2006", "Money 2005", "Money 2004", "Money 2003", "Money 2002", "Money 2001", "Visual SourceSafe 6.0", "Microsoft Encarta Encyclopedia 2000", "Age of Empires III (AoE3)", "Age of Empires II (AoE2)", "Age of Mythology", "Zoo Tycoon 2", "Zoo Tycoon", "Microsoft Mail for Appletalk Networks 3.1", "Microsoft Mail for Appletalk Networks 3.0" }
# Languge is a tough one
#Register-PSFTeppScriptblock -Name Language -ScriptBlock { [System.Globalization.CultureInfo]::GetCultures("AllCultures") | Where-Object Name -ne $null | Select-Object -ExpandProperty DisplayName }
Register-PSFTeppScriptblock -Name Language -ScriptBlock { "Slovak", "Czech", "Lower Sorbian", "French (Cameroon)", "French (Canada)", "English (Ireland)", "Greenlandic", "Spanish (Chile)", "Somali", "Sami, Lule (Sweden)", "Occitan", "Serbian", "Bashkir", "German (Liechtenstein)", "Bulgarian", "Yi", "French (Congo)", "English (Trinidad and Tobago)", "Kashmiri", "Swedish", "Southern Sotho", "English (Singapore)", "Uyghur", "Quechua (Bolivia)", "Khmer", "Frisian", "Spanish (Venezuela)", "Spanish (Latin America)", "Polish", "Oromo", "Ukrainian", "Korean", "Spanish (Bolivia)", "Norwegian (Bokml) (Norway)", "Tatar", "Mongolian (Traditional Mongolian, Mongolia)", "Tigrinya", "Serbian (Latin, Bosnia and Herzegovina)", "French (Runion)", "Chinese (Macau S.A.R.)", "Mapudungun (Chile)", "Slovenian", "Fulah", "K'iche", "Arabic (Jordan)", "Tajik", "Swahili", "Sami, Northern (Finland)", "English (India)", "German (Luxembourg)", "Spanish (El Salvador)", "Afrikaans", "Tsonga", "Sami (Southern)", "English (Canada)", "English (South Africa)", "Central Atlas Tamazight", "French", "isiXhosa", "Irish", "Romansh", "Basque", "Arabic (Lebanon)", "French (Switzerland)", "Arabic (Yemen)", "Setswana", "Finnish", "Catalan", "Spanish (Uruguay)", "Dutch (Netherlands)", "Spanish (Guatemala)", "Filipino", "Sesotho sa Leboa", "Spanish (Peru)", "German (Austria)", "English (Republic of the Philippines)", "Telugu", "Urdu", "Upper Sorbian", "Tamil", "Hebrew (Israel)", "Chinese (Singapore)", "Nepali", "French (Belgium)", "Hungarian", "Arabic (Qatar)", "Guarani", "Serbian (Cyrillic, Bosnia and Herzegovina)", "Arabic (Algeria)", "Arabic (Egypt)", "Arabic (Kuwait)", "Spanish (Nicaragua)", "Quechua (Peru)", "Arabic (Libya)", "Indonesian", "Arabic (Bahrain)", "Malay (Malaysia)", "Welsh", "Arabic (U.A.E.)", "Assamese", "Mohawk", "Tibetan", "Amharic", "Hausa", "Malayalam", "Serbian (Latin)", "English (Zimbabwe)", "Sami, Lule (Norway)", "English (United Kingdom)", "Central Kurdish", "Serbian (Latin, Montenegro)", "Spanish (Colombia)", "Punjabi", "Thai", "Corsican", "Kashmiri (India)", "French (Haiti)", "isiZulu", "Spanish (Dominican Republic)", "Wolof", "Norwegian (Nynorsk) (Norway)", "Mongolian (Traditional Mongolian)", "Spanish (Panama)", "Icelandic", "Sindhi", "Serbian (Latin, Serbia and Montenegro (Former))", "Cherokee", "French (Luxembourg)", "Burmese", "Sinhala", "Azeri", "English (Hong Kong)", "Spanish (Ecuador)", "Romanian", "Spanish (Spain)", "Farsi", "Yoruba", "Inuktitut (Syllabics)", "Maori", "Spanish (Argentina)", "Alsatian (France)", "English (Jamaica)", "Hawaiian", "Breton", "Arabic (Syria)", "English (Caribbean)", "Malay (Brunei Darussalam)", "Bosnian (Latin)", "German", "Italian", "Malayalam (India)", "English (New Zealand)", "Greek", "Pashto", "French (Monaco)", "Sami, Southern (Norway)", "Syriac", "Vietnamese", "Swedish (Finland)", "Hindi", "Albanian", "German (Switzerland)", "Azerbaijani", "Sami, Northern (Norway)", "Mongolian (Mongolia)", "Bangla", "Arabic (Saudi Arabia)", "Spanish (Puerto Rico)", "Divehi", "Spanish (Mexico)", "Latvian", "Sami (Skolt)", "Armenian", "Lithuanian (Lithuania)", "Luxembourgish", "Javanese", "Kazakh", "Igbo", "Turkish", "Bengali", "Maltese", "Oriya", "Gujarati (India)", "English (Belize)", "Danish", "Quechua (Ecuador)", "Spanish (Castilian)", "Kinyarwanda", "Sanskrit", "Lithuanian (Classic)", "Tamazight", "Spanish (Costa Rica)", "Sami, Northern (Sweden)", "Scottish Gaelic", "English", "Arabic (Morocco)", "Valencian", "Croatian (Croatia)", "Bosnian (Cyrillic)", "English (Australia)", "Serbian (Cyrillic, Montenegro)", "Arabic (Tunisia)", "Dari", "Macedonian", "Georgian", "Serbian (Cyrillic, Serbia)", "Mongolian (Cyrillic)", "Kyrgyz", "Japanese", "Marathi", "Sakha", "Dutch (Belgium)", "French (Senegal)", "Kannada", "Spanish (Paraguay)", "Turkmen", "Romanian (Moldova)", "Faeroese", "English (Malaysia)", "Uzbek", "Inuktitut", "Spanish (Honduras)", "Estonian (Estonia)", "French (Morocco)", "Russian", "Chinese", "French (Mali)", "Croatian (Bosnia and Herzegovina)", "Arabic (Iraq)", "Portuguese", "Italian (Switzerland)", "Belarusian", "Arabic (Oman)", "Chinese (Traditional / Taiwan)", "French (Ivory Coast)", "Galician (Galician)", "Chinese (Hong Kong S.A.R.)", "Lao", "Portuguese (Portugal)", "Konkani", "Sami (Inari)" }

# Register the actual auto completer
Register-PSFTeppArgumentCompleter -Command Get-KbUpdate, Save-KbUpdate -Parameter Architecture -Name Architecture
Register-PSFTeppArgumentCompleter -Command Get-KbUpdate, Save-KbUpdate -Parameter OperatingSystem -Name OperatingSystem
Register-PSFTeppArgumentCompleter -Command Get-KbUpdate, Save-KbUpdate -Parameter Product -Name Product
Register-PSFTeppArgumentCompleter -Command Get-KbUpdate, Save-KbUpdate -Parameter Language -Name Language