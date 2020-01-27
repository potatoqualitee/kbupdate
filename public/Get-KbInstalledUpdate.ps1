function Get-KbInstalledUpdate {
    <#
    .SYNOPSIS
        Replacement for Get-Hotfix

    .DESCRIPTION
        Replacement for Get-Hotfix

    .PARAMETER Pattern
        Any pattern. Can be the KB name, number or even MSRC numbrer. For example, KB4057119, 4057119, or MS15-101.

    .PARAMETER Architecture
        Can be x64, x86, ia64, or ARM.

    .PARAMETER Language
        Specify one or more Language. Tab complete to see what's available. This is not an exact science, as the data itself is miscategorized.

    .PARAMETER OperatingSystem
        Specify one or more operating systems. Tab complete to see what's available. If anything is missing, please file an issue.

    .PARAMETER ComputerName
        Get the Operating System and architecture information automatically

    .PARAMETER Credential
        The optional alternative credential to be used when connecting to ComputerName

    .PARAMETER Product
        Specify one or more products (SharePoint, SQL Server, etc). Tab complete to see what's available. If anything is missing, please file an issue.

    .PARAMETER Latest
        Filters out any patches that have been superseded by other patches in the batch

    .PARAMETER Simple
        A lil faster. Returns, at the very least: Title, Architecture, Language, UpdateId and Link

    .PARAMETER Source
        Search source. By default, Database is searched first, then if no matches are found, it tries finding it on the web.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Update
        Author: Chrissy LeMaire (@cl), netnerds.net
        Copyright: (c) licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .EXAMPLE
        PS C:\> Get-KbUpdate KB4057119

        Gets detailed information about KB4057119.

    .EXAMPLE
        PS C:\> Get-KbUpdate -Pattern KB4057119, 4057114 -Source Database

        Gets detailed information about KB4057119 and KB4057114. Only searches the database (useful for offline enviornments).


    .EXAMPLE
        PS C:\> Get-KbUpdate -Pattern MS15-101 -Source Web

        Downloads KBs related to MSRC MS15-101 to the current directory. Only searches the web and not the local db or WSUS.

    .EXAMPLE
        PS C:\> Connect-KbWsusServer -ComputerName server1 -SecureConnection
        PS C:\> Get-KbUpdate -Pattern KB2764916

        This command will make a secure connection (Default: 443) to a WSUS server.

        Then use Wsus as a source for Get-KbUpdate.

    .EXAMPLE
        PS C:\> Connect-KbWsusServer -ComputerName server1 -SecureConnection
        PS C:\> Get-KbUpdate -Pattern KB2764916 -Source Database

        Search the database even if you've connected to WSUS in the same session.

    .EXAMPLE
        PS C:\> Get-KbUpdate -Pattern KB4057119, 4057114 -Simple

        A lil faster when using web as a source. Returns, at the very least: Title, Architecture, Language, UpdateId and Link

    .EXAMPLE
        PS C:\> Get-KbUpdate -Pattern "KB2764916 Nederlands" -Simple

        An alternative way to search for language specific packages
#>
    [CmdletBinding()]
    param(
        [Alias("Name")]
        [string[]]$Pattern,
        [string[]]$Architecture,
        [string[]]$OperatingSystem,
        [string[]]$ComputerName,
        [pscredential]$Credential,
        [string[]]$Product,
        [string[]]$Language,
        [switch]$Simple,
        [switch]$Latest,
        [ValidateSet("Wsus", "Web", "Database")]
        [string[]]$Source = @("Web", "Database"),
        [switch]$EnableException
    )
    process {
        <#
        Name                  : Microsoft .NET Core Runtime - 2.1.5 (x64)
        Version               : 16.84.26919
        InstallState          : 5
        Caption               : Microsoft .NET Core Runtime - 2.1.5 (x64)
        Description           : Microsoft .NET Core Runtime - 2.1.5 (x64)
        IdentifyingNumber     : {BEB59D04-C6DD-4926-AFEB-410CBE2EBCE4}
        SKUNumber             :
        Vendor                : Microsoft Corporation
        AssignmentType        : 1
        HelpLink              :
        HelpTelephone         :
        InstallDate           : 20181105
        InstallDate2          :
        InstallLocation       :
        InstallSource         : C:\ProgramData\Package Cache\{BEB59D04-C6DD-4926-AFEB-410CBE2EBCE4}v16.84.26919\
        Language              : 1033
        LocalPackage          : C:\WINDOWS\Installer\4f97a771.msi
        PackageCache          : C:\WINDOWS\Installer\4f97a771.msi
        PackageCode           : {9A271A10-039D-49EA-8D24-043D91B9F915}
        PackageName           : dotnet-runtime-2.1.5-win-x64.msi
        ProductID             :
        RegCompany            :
        RegOwner              :
        Transforms            :
        URLInfoAbout          :
        URLUpdateInfo         :
        WordCount             : 0
        PSComputerName        :
        CimClass              : root/cimv2:Win32_Product
        CimInstanceProperties : {Caption, Description, IdentifyingNumber, Name...}
        CimSystemProperties   : Microsoft.Management.Infrastructure.CimSystemProperties
        #>
        # The Win32_Product class is not query optimized. Queries that use wildcard filters cause WMI to use the MSI provider to enumerate all installed products then parse the full list sequentially to handle the filter. This also initiates a consistency check of packages installed, verifying and repairing the install. The validation is a slow process and may result in errors in the event logs. For more information seek KB article 974524.

        <#
        InstanceId          : MSSQL10_50.SQL2008R2SP2
AuthorizedCDFPrefix :
Comments            :
Contact             :
DisplayVersion      : 10.52.4000.0
HelpLink            : http://go.microsoft.com/fwlink/?LinkId=154582
HelpTelephone       :
InstallDate         : 20170526
InstallLocation     :
InstallSource       : s:\e06c1685cdbd9f2e19\x64\setup\sql_engine_core_inst_msi\
ModifyPath          : MsiExec.exe /I{FBD367D1-642F-47CF-B79B-9BE48FB34007}
NoRepair            : 1
Publisher           : Microsoft Corporation
Readme              : Placeholder for ARP readme in case of no UI
Size                :
EstimatedSize       : 284269
SystemComponent     : 1
UninstallString     : MsiExec.exe /I{FBD367D1-642F-47CF-B79B-9BE48FB34007}
URLInfoAbout        :
URLUpdateInfo       :
VersionMajor        : 10
VersionMinor        : 52
WindowsInstaller    : 1
Version             : 171184032
Language            : 1033
DisplayName         : SQL Server 2008 R2 SP2 Database Engine Services
sEstimatedSize2     : 165767
PSPath              : Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{FBD367D1-642F-47CF-B79B-9BE48FB34007}
PSParentPath        : Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall
PSChildName         : {FBD367D1-642F-47CF-B79B-9BE48FB34007}
PSProvider          : Microsoft.PowerShell.Core\Registry
#>

        <#
[sql2017]: PS C:\Users\ctrlb\Documents> Get-Package | where name -match sql |select providername, name, tagid

ProviderName Name                                                 TagId
------------ ----                                                 -----
Programs     Hotfix 3162 for SQL Server 2017 (KB4498951) (64-bit)
msi          SQL Server 2017 Shared Management Objects Extensions C6D92730-3EC0-47B1-8F6C-6F5635D1EFAC
msi          SQL Server 2017 Common Files                         B777C4C0-A1CD-4AB9-99B1-AD5FBED6F8E5
msi          SQL Server 2017 Batch Parser                         2C6E8311-28BD-4615-9545-6E39E8E83A4B
msi          Microsoft ODBC Driver 13 for SQL Server              4F17B7F1-8576-4ACF-A69A-64D26F4CB4EE
msi          SQL Server 2017 DMF                                  B9998A13-5563-496C-B95E-597FFC70B670
msi          Microsoft SQL Server 2017 T-SQL Language Service     C8A51693-98B9-4AB1-91B8-9A1B86729D5F
msi          SQL Server 2017 Shared Management Objects            6CBBF624-696C-499E-948D-ADBAFFA2F548
msi          Microsoft SQL Server 2017 RsFx Driver                1B948444-76F2-4D86-91E8-915F20BC0075
msi          SQL Server 2017 Database Engine Shared               0E22DBB4-691B-400C-B52D-8DFE8EC421AA
msi          SQL Server 2017 Connection Info                      A9A443F5-56E1-4FC6-937C-5F481345A843
msi          SQL Server 2017 SQL Diagnostics                      DFA6A906-3024-49DE-87AD-750EAED2FA49
msi          Browser for SQL Server 2017                          CF8EEB96-E7E7-4EF7-A0A1-559F09953156
msi          Microsoft VSS Writer for SQL Server 2017             20B328C9-C6BB-434A-928A-00F05CD820B8
msi          SQL Server 2017 Database Engine Services             28EEF6BA-A23A-42D2-86BA-A6BEE723B969
msi          Microsoft SQL Server 2017 Setup (English)            D185F82B-3BD8-4803-89C5-939F25B58C7C
msi          SQL Server 2017 XEvent                               AA2A015C-C210-413B-95F6-BF9D3CDD6E0D
Programs     Microsoft SQL Server 2017 (64-bit)
msi          Microsoft SQL Server 2012 Native Client              4D2C56FF-7F36-4B49-A97A-24F0522D41D7
        #>




        <#




FromTrustedSource          : False
Summary                    :
SwidTags                   : {7-Zip 15.08 beta (x64)}
CanonicalId                : programs:7-Zip 15.08 beta (x64)/15.08
Metadata                   : {DisplayName,DisplayIcon,UninstallString,NoModify,NoRepair,DisplayVersion,InstallLocation,EstimatedSize,VersionMajor,VersionMinor,Publisher,sEstimatedSize2}
SwidTagText                : <?xml version="1.0" encoding="utf-16" standalone="yes"?>
                             <SoftwareIdentity
                               name="7-Zip 15.08 beta (x64)"
                               version="15.08"
                               versionScheme="unknown" xmlns="http://standards.iso.org/iso/19770/-2/2015/schema.xsd">
                               <Meta
                                 DisplayName="7-Zip 15.08 beta (x64)"
                                 DisplayIcon="C:\Program Files\7-Zip\7zFM.exe"
                                 UninstallString="C:\Program Files\7-Zip\Uninstall.exe"
                                 NoModify="1"
                                 NoRepair="1"
                                 DisplayVersion="15.08"
                                 InstallLocation="C:\Program Files\7-Zip\"
                                 EstimatedSize="4796"
                                 VersionMajor="15"
                                 VersionMinor="8"
                                 Publisher="Igor Pavlov"
                                 sEstimatedSize2="4796" />
                             </SoftwareIdentity>
Dependencies               : {}
IsCorpus                   :
Name                       : 7-Zip 15.08 beta (x64)
Version                    : 15.08
VersionScheme              : unknown
TagVersion                 :
TagId                      :
IsPatch                    :
IsSupplemental             :
AppliesToMedia             :
Meta                       : {{DisplayName,DisplayIcon,UninstallString,NoModify,NoRepair,DisplayVersion,InstallLocation,EstimatedSize,VersionMajor,VersionMinor,Publisher,sEstimatedSize2
                             }}
Links                      : {}
Entities                   : {}
Payload                    :
Evidence                   :
Culture                    :
Attributes                 : {name,version,versionScheme}

        #>
        # Graveyard
        #$cim = Get-CimInstance -ClassName Win32_Product
        #$allregs = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall


        $packages = @()
        $packages += Get-Package -IncludeWindowsInstaller -ProviderName msi, msu, Programs
        $packages += Get-Package -ProviderName msi, msu, Programs
        $packages = $packages | Sort-Object -Unique Name

        foreach ($package in $packages) {
            $null = $package | Add-Member -MemberType ScriptMethod -Name ToString -Value { $this.Name } -Force
            $regpath = ($package.FastPackageReference).Replace("hklm64\HKEY_LOCAL_MACHINE", "HKLM:\")
            if ($regpath -match 'HKLM') {
                $regprops = Get-ItemProperty -Path $regpath -ErrorAction SilentlyContinue
                $null = $regprops | Add-Member -MemberType ScriptMethod -Name ToString -Value { $this.DisplayName } -Force
            } else {
                $regprops = $null
            }

            [pscustomobject]@{
                ProviderName    = $package.ProviderName
                Source          = $package.Source
                Status          = $package.Status
                FullPath        = $package.FullPath
                PackageFilename = $package.PackageFilename
                Summary         = $package.Summary
                DisplayName     = $package.Meta.Attributes['DisplayName']
                DisplayIcon     = $package.Meta.Attributes['DisplayIcon']
                UninstallString = $package.Meta.Attributes['UninstallString']
                InstallLocation = $package.Meta.Attributes['InstallLocation']
                EstimatedSize   = $package.Meta.Attributes['EstimatedSize']
                Publisher       = $package.Meta.Attributes['Publisher']
                VersionMajor    = $package.Meta.Attributes['VersionMajor']
                VersionMinor    = $package.Meta.Attributes['VersionMinor']
                TagId           = $package.TagId
                PackageObject   = $package
                RegistryObject  = $regprops
            } | Select-DefaultView -ExcludeProperty PackageObject, RegistryObject
        }
    }
}