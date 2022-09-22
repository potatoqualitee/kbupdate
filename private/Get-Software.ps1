function Get-Software {
    param (
        [string[]]$Pattern,
        $IncludeHidden,
        $VerbosePreference
    )
    $allhotfixids = New-Object System.Collections.ArrayList
    $allcbs = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages'

    if ($psversiontable.PsVersion.Major -lt 5 -or ($psversiontable.PsVersion.Major -eq 5 -and $psversiontable.PsVersion.Major -lt 1)) {
        # using throw because it's a remote computer with no guarantee of psframework. Also the throw is caught at the bottom by PSFramework.
        throw "$env:ComputerName is running PowerShell version $psversiontalbe. Please upgrade to PowerShell version 5.1 or greater"
    }

    if ($pattern) {
        $packages = @()
        foreach ($name in $pattern) {
            $packages += Get-Package -IncludeWindowsInstaller -ProviderName msi, msu, Programs -Name "*$name*" -ErrorAction SilentlyContinue
            $packages += Get-Package -ProviderName msi, msu, Programs -Name "*$name*" -ErrorAction SilentlyContinue
            if ((Get-Service wuauserv | Where-Object StartType -ne Disabled)) {
                $session = [type]::GetTypeFromProgID("Microsoft.Update.Session")
                $wua = [activator]::CreateInstance($session)
                $updatesearcher = $wua.CreateUpdateSearcher()
                $count = $updatesearcher.GetTotalHistoryCount()
                $packages += $updatesearcher.QueryHistory(0, $count) | Where-Object Name -match $Pattern
            }
        }
    } else {
        $packages = @()
        $packages += Get-Package -IncludeWindowsInstaller -ProviderName msi, msu, Programs
        $packages += Get-Package -ProviderName msi, msu, Programs
        $packages = $packages | Sort-Object -Unique Name
        if ((Get-Service wuauserv | Where-Object StartType -ne Disabled)) {
            $session = [type]::GetTypeFromProgID("Microsoft.Update.Session")
            $wua = [activator]::CreateInstance($session)
            $updatesearcher = $wua.CreateUpdateSearcher()
            $count = $updatesearcher.GetTotalHistoryCount()
            $packages += $updatesearcher.QueryHistory(0, $count)
        }
    }

    $packages = $packages | Where-Object Name | Sort-Object -Unique Name
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
        if (($regpath = "$($package.FastPackageReference)".Replace("hklm64\HKEY_LOCAL_MACHINE", "HKLM:\")) -match 'HKLM') {
            $reg = Get-ItemProperty -Path $regpath -ErrorAction SilentlyContinue
            $null = $reg | Add-Member -MemberType ScriptMethod -Name ToString -Value { $this.DisplayName } -Force
            $hotfixid = Split-Path -Path $regpath -Leaf | Where-Object { "$PSItem".StartsWith("KB") }
        } else {
            $reg = $null
            $hotfixid = $null
        }

        #return the same properties as above
        if ($package.Name -match 'KB' -and -not $hotfixid) {
            #anyone want to help with regex, I'm down. Till then..
            $number = $package.Name.Split('KB') | Select-Object -Last 1
            $number = $number.Split(" ") | Select-Object -First 1
            $hotfixid = "KB$number".Trim().Replace(")", "")
        } else {
            $hotfixid = $package.HotfixId
        }
        if ($hotfixid) {
            $null = $allhotfixids.Add($hotfixid)
            $cbs = $allcbs | Where-Object Name -match $hotfixid | Get-ItemProperty
            if ($cbs) {
                # make it pretty
                $cbs | Add-Member -MemberType ScriptMethod -Name ToString -Value { "ComponentBasedServicing" } -Force
                $installclient = ($cbs | Select-Object -First 1).InstallClient
                $installuser = ($cbs | Select-Object -First 1).InstallUser
                $installname = $cbs.InstallName

                if ("$installname" -match "Package_1_for") {
                    $installname = $cbs | Where-Object InstallName -match "Package_1_for" | Select-Object -First 1 -ExpandProperty InstallName
                    $installname = $installname.Replace("Package_1_for", "Package_for")
                } elseif ("$installname" -match "Package_for") {
                    $installname = $cbs | Where-Object InstallName -match "Package_for" | Select-Object -First 1 -ExpandProperty InstallName
                }

                if ($installname.Count -gt 1) {
                    $installname | Select-Object -First 1
                }

                # props for highlighting that the installversion is important
                # https://social.technet.microsoft.com/Forums/Lync/en-US/f6594e00-2400-4276-85a1-fb06485b53e6/issues-with-wusaexe-and-windows-10-enterprise?forum=win10itprogeneral
                if ($installname) {
                    $installname = $installname.Replace(".mum", "")
                    $installversion = (($installname -split "~~")[1])
                }

                $allfiles = New-Object -TypeName System.Collections.ArrayList
                foreach ($file in $cbs) {
                    $name = $file.InstallName
                    $location = $file.InstallLocation.ToString().TrimStart("\\?\")
                    $location = "$location\$name"
                    $null = $allfiles.Add([pscustomobject]@{
                            Name = $name
                            Path = $location
                        })
                }
            }
        }

        # gotta get dism module and try that jesus christ
        if ($package.Meta.Attributes) {
            $DisplayName = $package.Meta.Attributes['DisplayName']
            $DisplayIcon = $package.Meta.Attributes['DisplayIcon']
            $UninstallString = $package.Meta.Attributes['UninstallString']
            $QuietUninstallString = $package.Meta.Attributes['QuietUninstallString']
            $InstallLocation = $package.Meta.Attributes['InstallLocation']
            $EstimatedSize = $package.Meta.Attributes['EstimatedSize']
            $Publisher = $package.Meta.Attributes['Publisher']
            $VersionMajor = $package.Meta.Attributes['VersionMajor']
            $VersionMinor = $package.Meta.Attributes['VersionMinor']
        } else {
            $DisplayIcon = $null
            $UninstallString = $null
            $QuietUninstallString = $null
            $InstallLocation = $null
            $EstimatedSize = $null
            $Publisher = $null
            $VersionMajor = $null
            $VersionMinor = $null
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
            InstallClient        = $installclient
            InstallName          = $installname
            InstallVersion       = $installversion
            InstallFile          = $allfiles
            InstallUser          = $installuser
            FixComments          = $cim.FixComments
            ServicePackInEffect  = $cim.ServicePackInEffect
            Caption              = $cim.Caption
            DisplayName          = $DisplayName
            DisplayIcon          = $DisplayIcon
            UninstallString      = $UninstallString
            QuietUninstallString = $QuietUninstallString
            InstallLocation      = $InstallLocation
            EstimatedSize        = $EstimatedSize
            Publisher            = $Publisher
            VersionMajor         = $VersionMajor
            VersionMinor         = $VersionMinor
            TagId                = $package.TagId
            PackageObject        = $package
            RegistryObject       = $reg
            CBSPackageObject     = $cbs
            CimObject            = $cim
        }
    }

    $allcim = Get-CimInstance -ClassName Win32_QuickFixEngineering | Sort-Object HotFixID -Unique

    if ($pattern) {
        $allcim = $allcim | Where-Object HotfixId -in $pattern
    }


    foreach ($cim in $allcim) {
        #return the same properties as above
        if ($cim.Name -match 'KB' -and -not $cim.HotfixId) {
            # anyone want to help with regex, I'm down. Till then..
            $split = $cim.Name -split 'KB'
            $number = ($split[-1]).TrimEnd(")").Trim()
            $hotfixid = "KB$number"
        } else {
            $hotfixid = $cim.HotfixId
        }

        if ($hotfixid) {
            $null = $allhotfixids.Add($hotfixid)
            $cbs = $allcbs | Where-Object Name -match $hotfixid | Get-ItemProperty
            if ($cbs) {
                # make it pretty
                $cbs | Add-Member -MemberType ScriptMethod -Name ToString -Value { "ComponentBasedServicing" } -Force
                $installclient = ($cbs | Select-Object -First 1).InstallClient
                $installuser = ($cbs | Select-Object -First 1).InstallUser

                $allfiles = New-Object -TypeName System.Collections.ArrayList
                foreach ($file in $cbs) {
                    $name = $file.InstallName
                    $location = $file.InstallLocation.ToString().TrimStart("\\?\")
                    $location = "$location\$name"
                    $null = $allfiles.Add([pscustomobject]@{
                            Name = $name
                            Path = $location
                        })
                }
                # no idea why this doesn't work :(
                Add-Member -InputObject $allfiles -MemberType ScriptMethod -Name ToString -Value { $this.Name } -Force
            }
        }

        [pscustomobject]@{
            ComputerName         = $env:COMPUTERNAME
            Name                 = $cim.HotfixId
            ProviderName         = $null
            Source               = $null
            Status               = $null
            HotfixId             = $hotfixid
            FullPath             = $null
            PackageFilename      = $null
            Summary              = $null
            InstalledBy          = $cim.InstalledBy
            InstalledOn          = $cim.InstalledOn
            InstallDate          = $cim.InstallDate
            InstallClient        = $installclient
            InstallName          = $installname
            InstallVersion       = $installversion
            InstallFile          = $allfiles
            InstallUser          = $installuser
            FixComments          = $cim.FixComments
            ServicePackInEffect  = $cim.ServicePackInEffect
            Caption              = $cim.Caption
            DisplayName          = $null
            DisplayIcon          = $null
            UninstallString      = $null
            QuietUninstallString = $null
            InstallLocation      = $null
            EstimatedSize        = $null
            Publisher            = $null
            VersionMajor         = $null
            VersionMinor         = $null
            TagId                = $null
            PackageObject        = $null
            RegistryObject       = $null
            CBSPackageObject     = $cbs
            CimObject            = $cim
        }
    }

    if ($IncludeHidden) {
        #anyone want to help with regex, I'm down. Till then..
        $kbfiles = $allcbs | Get-ItemProperty | Where-Object InstallName -match '_KB' | Select-Object -ExpandProperty InstallName
        $allkbs = @()
        foreach ($file in $kbfiles) {
            $tempfile = $file.ToString().Split("_") | Where-Object { $PSItem.StartsWith("KB") }
            if ($tempfile) {
                $allkbs += $tempfile.Replace("_", "").Split("~") | Select-Object -First 1
            }
        }

        $missing = $allkbs | Where-Object { $PSitem -notin $allhotfixids } | Select-Object -Unique

        if ($Pattern) {
            $missing = $missing | Where-Object { $PSItem -in $Pattern }
        }

        foreach ($result in $missing) {
            [pscustomobject]@{
                ComputerName         = $env:COMPUTERNAME
                Name                 = $result
                ProviderName         = $null
                Source               = $null
                Status               = $null
                HotfixId             = $result
                FullPath             = $null
                PackageFilename      = $null
                Summary              = "Requires restart to finish installing"
                InstalledBy          = $null
                InstalledOn          = $null
                InstallDate          = $null
                InstallClient        = $null
                InstallName          = $null
                InstallVersion       = $null
                InstallFile          = $null
                InstallUser          = $null
                FixComments          = $null
                ServicePackInEffect  = $null
                Caption              = $null
                DisplayName          = $null
                DisplayIcon          = $null
                UninstallString      = $null
                QuietUninstallString = $null
                InstallLocation      = $null
                EstimatedSize        = $null
                Publisher            = $null
                VersionMajor         = $null
                VersionMinor         = $null
                TagId                = $null
                PackageObject        = $null
                RegistryObject       = $null
                CBSPackageObject     = $null
                CimObject            = $null
            }
        }
    }
}
