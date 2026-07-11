function Get-Software {
    param (
        [string[]]$Pattern,
        $IncludeHidden,
        $VerbosePreference
    )
    $allhotfixids = New-Object System.Collections.ArrayList
    $allcbs = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages'

    $packageProviderNames = @()
    if ((Get-Command Get-Package -ErrorAction SilentlyContinue) -and (Get-Command Get-PackageProvider -ErrorAction SilentlyContinue)) {
        try {
            $availablePackageProviders = @(Get-PackageProvider -ListAvailable -ErrorAction Stop)
            foreach ($providerName in @('msi', 'msu', 'Programs')) {
                if ($providerName -in $availablePackageProviders.Name) {
                    $packageProviderNames += $providerName
                }
            }
        } catch {
            Write-Verbose "PackageManagement providers are unavailable: $($PSItem.Exception.Message)"
        }
    }

    $registryPackages = @()
    if ('Programs' -notin $packageProviderNames) {
        $uninstallPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        foreach ($uninstallPath in $uninstallPaths) {
            $installedPrograms = Get-ItemProperty -Path $uninstallPath -ErrorAction SilentlyContinue | Where-Object DisplayName
            foreach ($installedProgram in $installedPrograms) {
                $registryPackages += [pscustomobject]@{
                    Name                 = $installedProgram.DisplayName
                    ProviderName         = 'Programs'
                    Source               = $null
                    Status               = 'Installed'
                    HotfixId             = $null
                    FullPath             = $null
                    PackageFilename      = $null
                    Summary              = $null
                    FastPackageReference = $null
                    TagId                = $null
                    RegistryObject       = $installedProgram
                    Meta                 = [pscustomobject]@{
                        Attributes = @{
                            DisplayName          = $installedProgram.DisplayName
                            DisplayIcon          = $installedProgram.DisplayIcon
                            UninstallString      = $installedProgram.UninstallString
                            QuietUninstallString = $installedProgram.QuietUninstallString
                            InstallLocation      = $installedProgram.InstallLocation
                            EstimatedSize        = $installedProgram.EstimatedSize
                            Publisher            = $installedProgram.Publisher
                            VersionMajor         = $installedProgram.VersionMajor
                            VersionMinor         = $installedProgram.VersionMinor
                        }
                    }
                }
            }
        }
    }

    if ($pattern) {
        $packages = @()
        foreach ($name in $pattern) {
            if ($packageProviderNames) {
                try {
                    $packages += Get-Package -IncludeWindowsInstaller -ProviderName $packageProviderNames -Name "*$name*" -ErrorAction Stop
                    $packages += Get-Package -ProviderName $packageProviderNames -Name "*$name*" -ErrorAction Stop
                } catch {
                    Write-Verbose "PackageManagement query failed: $($PSItem.Exception.Message)"
                }
            }
            if ((Get-Service wuauserv | Where-Object StartType -ne Disabled)) {
                $session = [type]::GetTypeFromProgID("Microsoft.Update.Session")
                $wua = [activator]::CreateInstance($session)
                $updatesearcher = $wua.CreateUpdateSearcher()
                $count = $updatesearcher.GetTotalHistoryCount()
                if ($count -gt 0) {
                    $packages += $updatesearcher.QueryHistory(0, $count) | Where-Object Name -match $Pattern
                }
            }
            $packages += $registryPackages | Where-Object Name -like "*$name*"
        }
    } else {
        $packages = @()
        if ($packageProviderNames) {
            try {
                $packages += Get-Package -IncludeWindowsInstaller -ProviderName $packageProviderNames -ErrorAction Stop
                $packages += Get-Package -ProviderName $packageProviderNames -ErrorAction Stop
            } catch {
                Write-Verbose "PackageManagement query failed: $($PSItem.Exception.Message)"
            }
        }
        $packages += $registryPackages
        $packages = $packages | Sort-Object -Unique Name
        if ((Get-Service wuauserv | Where-Object StartType -ne Disabled)) {
            $session = [type]::GetTypeFromProgID("Microsoft.Update.Session")
            $wua = [activator]::CreateInstance($session)
            $updatesearcher = $wua.CreateUpdateSearcher()
            $count = $updatesearcher.GetTotalHistoryCount()
            if ($count -gt 0) {
                $packages += $updatesearcher.QueryHistory(0, $count)
            }
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
        if ($package.RegistryObject) {
            $reg = $package.RegistryObject
            $hotfixid = $null
        } elseif (($regpath = "$($package.FastPackageReference)".Replace("hklm64\HKEY_LOCAL_MACHINE", "HKLM:\")) -match 'HKLM') {
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
