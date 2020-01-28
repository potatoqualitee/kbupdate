function Get-KbInstalledUpdate {
    <#
    .SYNOPSIS
        Replacement for Get-Hotfix

    .DESCRIPTION
        Replacement for Get-Hotfix

    .PARAMETER Pattern
        Any pattern. Can be the KB name, number or even MSRC numbrer. For example, KB4057119, 4057119, or MS15-101.

    .PARAMETER ComputerName
        Get the Operating System and architecture information automatically

    .PARAMETER Credential
        The optional alternative credential to be used when connecting to ComputerName

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
        PS C:\> Get-KbInstalledUpdate -ComputerName sql2017

        Gets detailed information about all of the installed updates on sql2017.

    .EXAMPLE
        PS C:\> Get-KbInstalledUpdate -ComputerName sql2017 -Pattern kb4498951

        Gets detailed information about all of the installed updates on sql2017 for KB4057119
#>
    [CmdletBinding()]
    param(
        [string[]]$ComputerName = $env:COMPUTERNAME,
        [pscredential]$Credential,
        [string]$Pattern,
        [switch]$EnableException
    )
    begin {
        $scriptblock = {
            param ($Pattern)
            if ($Pattern) {
                $packages = @()
                $packages += Get-Package -IncludeWindowsInstaller -ProviderName msi, msu, Programs -Name "*$Pattern*" -ErrorAction SilentlyContinue
                $packages += Get-Package -ProviderName msi, msu, Programs -Name "*$Pattern*" -ErrorAction SilentlyContinue
                $packages = $packages | Sort-Object -Unique Name
            } else {
                $packages = @()
                $packages += Get-Package -IncludeWindowsInstaller -ProviderName msi, msu, Programs
                $packages += Get-Package -ProviderName msi, msu, Programs
                $packages = $packages | Sort-Object -Unique Name
            }
            # Cim never reports stuff in a package :(

            foreach ($package in $packages) {
                $null = $package | Add-Member -MemberType ScriptMethod -Name ToString -Value { $this.Name } -Force
                $fullpath = $package.FullPath
                if ($fullpath -eq "?") {
                    $fullpath = $null
                }
                $filename = $package.PackageFilename
                if ($filename -eq "?") {
                    $filename = $null
                }

                $null = $package | Add-Member -MemberType ScriptMethod -Name ToString -Value { $this.Name } -Force
                if (($regpath = ($package.FastPackageReference).Replace("hklm64\HKEY_LOCAL_MACHINE", "HKLM:\")) -match 'HKLM') {
                    $reg = Get-ItemProperty -Path $regpath -ErrorAction SilentlyContinue
                    $null = $reg | Add-Member -MemberType ScriptMethod -Name ToString -Value { $this.DisplayName } -Force
                    $hotfixid = Split-Path -Path $regpath -Leaf | Where-Object { $psitem.StartsWith("KB") }
                } else {
                    $reg = $null
                }

                [pscustomobject]@{
                    Name                 = $package.Name
                    ProviderName         = $package.ProviderName
                    Source               = $package.Source
                    Status               = $package.Status
                    HotfixId             = $hotfixid
                    FullPath             = $fullpath
                    PackageFilename      = $filename
                    Summary              = $package.Summary
                    InstalledBy          = $cim.InstalledBy
                    FastPackageReference = $package.FastPackageReference
                    InstalledOn          = $cim.InstalledOn
                    InstallDate          = $cim.InstallDate
                    FixComments          = $cim.FixComments
                    ServicePackInEffect  = $cim.ServicePackInEffect
                    Caption              = $cim.Caption
                    DisplayName          = $package.Meta.Attributes['DisplayName']
                    DisplayIcon          = $package.Meta.Attributes['DisplayIcon']
                    UninstallString      = $package.Meta.Attributes['UninstallString']
                    InstallLocation      = $package.Meta.Attributes['InstallLocation']
                    EstimatedSize        = $package.Meta.Attributes['EstimatedSize']
                    Publisher            = $package.Meta.Attributes['Publisher']
                    VersionMajor         = $package.Meta.Attributes['VersionMajor']
                    VersionMinor         = $package.Meta.Attributes['VersionMinor']
                    TagId                = $package.TagId
                    PackageObject        = $package
                    RegistryObject       = $reg
                    CimObject            = $cim
                }
            }

            $allcim = Get-CimInstance -ClassName Win32_QuickFixEngineering
            if ($Pattern) {
                $allcim = $allcim | Where-Object HotfixId -match $Pattern
            }

            foreach ($cim in $allcim) {
                $hotfixid = $cim.HotfixId
                $reg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$hotfixid" -ErrorAction SilentlyContinue
                if ($reg) {
                    $null = $reg | Add-Member -MemberType ScriptMethod -Name ToString -Value { $this.DisplayName } -Force
                }

                #return the same properties as above
                [pscustomobject]@{
                    Name                = $null
                    ProviderName        = $null
                    Source              = $null
                    Status              = $null
                    HotfixId            = $hotfixid
                    FullPath            = $null
                    PackageFilename     = $null
                    Summary             = $null
                    InstalledBy         = $cim.InstalledBy
                    InstalledOn         = $cim.InstalledOn
                    InstallDate         = $cim.InstallDate
                    FixComments         = $cim.FixComments
                    ServicePackInEffect = $cim.ServicePackInEffect
                    Caption             = $cim.Caption
                    DisplayName         = $null
                    DisplayIcon         = $null
                    UninstallString     = $null
                    InstallLocation     = $null
                    EstimatedSize       = $null
                    Publisher           = $null
                    VersionMajor        = $null
                    VersionMinor        = $null
                    TagId               = $null
                    PackageObject       = $null
                    RegistryObject      = $reg
                    CimObject           = $cim
                }
            }
        }
    }
    process {
        try {
            foreach ($computer in $ComputerName) {
                Invoke-Command2 -ComputerName $computer -Credential $Credential -ErrorAction Stop -ScriptBlock $scriptblock -Raw -ArgumentList $Pattern | Sort-Object -Property Name
            }
        } catch {
            Stop-PSFFunction -EnableException:$EnableException -Message "Failure" -ErrorRecord $_ -Continue
        }
    }
}