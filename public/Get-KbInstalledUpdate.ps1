function Get-KbInstalledUpdate {
    <#
    .SYNOPSIS
        Replacement for Get-Hotfix, Get-Package, searching the registry and searching CIM for updates

    .DESCRIPTION
        Replacement for Get-Hotfix, Get-Package, searching the registry and searching CIM for updates.

    .PARAMETER Pattern
        Any pattern. But really, a KB pattern is your best bet.

    .PARAMETER ComputerName
        Used to connect to a remote host

    .PARAMETER Credential
        The optional alternative credential to be used when connecting to ComputerName

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Author: Chrissy LeMaire (@cl), netnerds.net
        Copyright: (c) licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .EXAMPLE
        PS C:\> Get-KbInstalledUpdate

        Gets all the updates installed on the local machine

    .EXAMPLE
        PS C:\> Get-KbInstalledUpdate -ComputerName server01

        Gets all the updates installed on server01

    .EXAMPLE
        PS C:\> Get-KbInstalledUpdate -ComputerName server01 -Pattern KB4057119

        Gets all the updates installed on server01 that match KB4057119
#>
    [CmdletBinding()]
    param(
        [string[]]$ComputerName = $env:COMPUTERNAME,
        [pscredential]$Credential,
        [string[]]$Pattern,
        [switch]$EnableException
    )
    begin {
        $scriptblock = {
            param ($Search)
            # i didnt know how else to preserve the array, it kept flattening to a single string
            $pattern = $Search['Pattern']
            if ($pattern) {
                $packages = @()
                foreach ($name in $pattern) {
                    $packages += Get-Package -IncludeWindowsInstaller -ProviderName msi, msu, Programs -Name "*$name*" -ErrorAction SilentlyContinue
                    $packages += Get-Package -ProviderName msi, msu, Programs -Name "*$name*" -ErrorAction SilentlyContinue
                }
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

                # Make it pretty
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
                    ComputerName         = $env:COMPUTERNAME
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

            if ($pattern) {
                $allcim = $allcim | Where-Object HotfixId -in $pattern
            }

            foreach ($cim in $allcim) {
                #return the same properties as above
                [pscustomobject]@{
                    ComputerName        = $env:COMPUTERNAME
                    Name                = $cim.HotfixId
                    ProviderName        = $null
                    Source              = $null
                    Status              = $null
                    HotfixId            = $cim.HotfixId
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
                    RegistryObject      = $null
                    CimObject           = $cim
                }
            }
        }
    }
    process {
        try {
            foreach ($computer in $ComputerName) {
                Invoke-Command2 -ComputerName $computer -Credential $Credential -ErrorAction Stop -ScriptBlock $scriptblock -Raw -ArgumentList @{ Pattern = $Pattern } | Sort-Object -Property Name
            }
        } catch {
            Stop-PSFFunction -EnableException:$EnableException -Message "Failure" -ErrorRecord $_ -Continue
        }
    }
}