# requires 5
function Install-KbUpdate {
    <#
    .SYNOPSIS
        Installs KBs on local and remote servers on Windows-based systems

    .DESCRIPTION
        Installs KBs on local and remote servers on Windows-based systems

        PowerShell 5.1 must be installed and enabled on the target machine and the target machine must be Windows-based

        Note that if you use a DSC Pull server, this may impact your LCM

    .PARAMETER ComputerName
        Used to connect to a remote host

    .PARAMETER Credential
        The optional alternative credential to be used when connecting to ComputerName

    .PARAMETER PSDscRunAsCredential
        Run the install as a specific user (other than SYSTEM) on the target node

    .PARAMETER HotfixId
        The HotfixId of the patch

    .PARAMETER FilePath
        The filepath of the patch. Not required - if you don't have it, we can grab it from the internet

        Note this does place the hotfix files in your local and remote Downloads directories

    .PARAMETER Guid
        If the file is an exe and no GUID is specified, we will have to get it from Get-KbUpdate

    .PARAMETER Title
        If the file is an exe and no Title is specified, we will have to get it from Get-KbUpdate

    .PARAMETER Method
        Not yet implemented but will be used to specify DSC or Windows Update

    .PARAMETER ArgumentList
        This is an advanced parameter for those of you who need special argumentlists for your platform-specific update.

        The argument list required by SQL updates are already accounted for.

    .PARAMETER InputObject
        Allows infos to be piped in from Get-KbUpdate

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Author: Jess Pomfret (@jpomfret), Chrissy LeMaire (@cl)
        Copyright: (c) licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .EXAMPLE
        PS C:\> Install-KbUpdate -ComputerName sql2017 -FilePath C:\temp\windows10.0-kb4534273-x64_74bf76bc5a941bbbd0052caf5c3f956867e1de38.msu

        Installs KB4534273 from the C:\temp directory on sql2017

    .EXAMPLE
        PS C:\> Install-KbUpdate -ComputerName sql2017 -FilePath \\dc\sql\windows10.0-kb4532947-x64_20103b70445e230e5994dc2a89dc639cd5756a66.msu

        Installs KB4534273 from the \\dc\sql\ directory on sql2017

    .EXAMPLE
        PS C:\> Install-KbUpdate -ComputerName sql2017 -HotfixId kb4486129

        Downloads an update, stores it in Downloads and installs it from there

    .EXAMPLE
        PS C:\> $params = @{
            ComputerName = "sql2017"
            FilePath = "C:\temp\sqlserver2017-kb4498951-x64_b143d28a48204eb6ebab62394ce45df53d73f286.exe"
            Verbose = $true
        }
        PS C:\> Install-KbUpdate @params
        PS C:\> Uninstall-KbUpdate -ComputerName sql2017 -HotfixId KB4498951

        Installs KB4498951 on sql2017 then uninstalls it ✔

    .EXAMPLE
        PS C:\> Get-KbNeededUpdate | Install-KbUpdate -Method WindowsUpdate -Verbose

        Installs needed updates, only works on localhost

    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    param (
        [PSFComputer[]]$ComputerName = $env:ComputerName,
        [PSCredential]$Credential,
        [PSCredential]$PSDscRunAsCredential,
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias("Name", "KBUpdate", "Id")]
        [string]$HotfixId,
        [Alias("Path")]
        [string]$FilePath,
        [string]$RepositoryPath,
        [ValidateSet("WindowsUpdate", "DSC")]
        [string]$Method,
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias("UpdateId")]
        [string]$Guid,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Title,
        [string]$ArgumentList,
        [Parameter(ValueFromPipeline)]
        [pscustomobject[]]$InputObject,
        [switch]$EnableException
    )
    process {
        if (-not $PSBoundParameters.HotfixId -and -not $PSBoundParameters.FilePath -and -not $PSBoundParameters.InputObject) {
            Stop-PSFFunction -EnableException:$EnableException -Message "You must specify either HotfixId or FilePath or pipe in the results from Get-KbUpdate"
            return
        }

        if ($IsLinux -or $IsMacOs) {
            Stop-PSFFunction -Message "This command using remoting and only supports Windows at this time" -EnableException:$EnableException
            return
        }

        if (-not $HotfixId.ToUpper().StartsWith("KB") -and $PSBoundParameters.HotfixId) {
            $HotfixId = "KB$HotfixId"
        }

        if ($Credential.UserName) {
            $PSDefaultParameterValues["*:Credential"] = $Credential
        }

        if (-not $PSBoundParameters.ComputerName -and $InputObject) {
            $ComputerName = [PSFComputer]$InputObject.ComputerName
            Write-PSFMessage -Level Verbose -Message "Added $ComputerName"
        }

        foreach ($item in $ComputerName) {
            $computer = $item.ComputerName
            if ($item.IsLocalHost -and -not (Test-ElevationRequirement -ComputerName $computer)) {
                Stop-PSFFunction -EnableException:$EnableException -Message "You must be an administrator to run this command on the local host" -Continue
            }

            if (-not $item.IsLocalHost -and $Method -eq "WindowsUpdate") {
                Stop-PSFFunction -EnableException:$EnableException -Message "The Windows Update method is only supported on localhost due to Windows security restrictions" -Continue
            }
            # null out a couple things to be safe
            $remotefileexists = $programhome = $remotesession = $null
            Write-PSFMessage -Level Verbose -Message "Processing $computer"


            if ($Method -eq "WindowsUpdate") {
                $sessiontype = [type]::GetTypeFromProgID("Microsoft.Update.Session")
                $session = [activator]::CreateInstance($sessiontype)
                $session.ClientApplicationID = "kbupdate installer"
                $downloadat = $false
                $updateinstall = New-Object -ComObject 'Microsoft.Update.UpdateColl'

                if ($InputObject.InputObject) {
                    Write-PSFMessage -Level Verbose -Message "Got an input object"
                    $searchresult = $InputObject.InputObject
                } else {
                    Write-PSFMessage -Level Verbose -Message "Build needed updates"
                    $searchresult = $session.CreateUpdateSearcher().Search("Type='Software'")
                }

                # iterate the updates in searchresult
                # it must be force iterated like this
                if ($searchresult.Updates) {
                    foreach ($update in $searchresult.Updates) {
                        $null = $update.AcceptEula()
                        foreach ($bundle in $update.BundledUpdates) {
                            $files = New-Object -ComObject "Microsoft.Update.StringColl.1"
                            foreach ($file in $bundle.DownloadContents) {
                                if ($file.DownloadUrl -and $RepositoryPath) {
                                    $filename = Split-Path -Path $file.DownloadUrl -Leaf
                                    Write-PSFMessage -Level Verbose -Message "Adding $filename"
                                    $fullpath = Join-Path -Path $RepositoryPath -ChildPath $filename
                                    Write-PSFMessage -Level Verbose -Message $fullpath
                                    $null = $files.Add($fullpath)
                                }
                            }
                        }
                        if (-not $update.IsDownloaded) { $downloadat = $true }
                        $updateinstall.Add($update) | Out-Null
                    }

                    if ($downloadat) {
                        try {
                            $downloader = $session.CreateUpdateDownloader()
                            $downloader.Updates = $searchresult.Updates
                            $null = $downloader.Download()
                        } catch {
                            Stop-PSFFunction -EnableException:$EnableException -Message "Failure on $env:ComputerName" -ErrorRecord $PSItem -Continue
                        }
                    }
                } else {
                    $files = New-Object -ComObject "Microsoft.Update.StringColl.1"
                    Write-PSFMessage -Level Verbose -Message "Link"
                    foreach ($link in $searchresult.Link) {
                        if ($link -and $RepositoryPath) {
                            $filename = Split-Path -Path $link -Leaf
                            $fullpath = Join-Path -Path $RepositoryPath -ChildPath $filename
                            $null = $files.Add($fullpath)
                        }
                    }

                    # load into Windows Update API
                    try {
                        $bundle.CopyToCache($files)
                    } catch {
                        Stop-PSFFunction -EnableException:$EnableException -Message "Failure on $env:ComputerName" -ErrorRecord $PSItem -Continue
                    }
                }

                try {
                    $installer = $session.CreateUpdateInstaller()
                    if ($updateinstall) {
                        $installer.Updates = $updateinstall
                    } else {
                        $installer.Updates = $searchresult.Updates
                    }
                    $installer.Install()
                } catch {
                    Stop-PSFFunction -EnableException:$EnableException -Message "Failure on $env:ComputerName" -ErrorRecord $PSItem -Continue
                }
            } else {
                # Method is DSC
                if ($PSDefaultParameterValues["Invoke-PSFCommand:ComputerName"]) {
                    $null = $PSDefaultParameterValues.Remove("Invoke-PSFCommand:ComputerName")
                }

                if ($item.IsLocalHost) {
                    # a lot of the file copy work will be done in the $home dir
                    $programhome = Invoke-PSFCommand -ScriptBlock { $home }
                } else {
                    Write-PSFMessage -Level Verbose -Message "Adding $computer to PSDefaultParameterValues for Invoke-PSFCommand:ComputerName"
                    $PSDefaultParameterValues["Invoke-PSFCommand:ComputerName"] = $computer

                    Write-PSFMessage -Level Verbose -Message "Initializing remote session to $computer and also getting the remote home directory"
                    $programhome = Invoke-PSFCommand -ScriptBlock { $home }

                    if (-not $remotesession) {
                        $remotesession = Get-PSSession -ComputerName $computer -Verbose | Where-Object { $PsItem.Availability -eq 'Available' -and ($PsItem.Name -match 'WinRM' -or $PsItem.Name -match 'Runspace') } | Select-Object -First 1
                    }

                    if (-not $remotesession) {
                        $remotesession = Get-PSSession -ComputerName $computer | Where-Object { $PsItem.Availability -eq 'Available' } | Select-Object -First 1
                    }

                    if (-not $remotesession) {
                        Stop-PSFFunction -EnableException:$EnableException -Message "Session for $computer can't be found or no runspaces are available. Please file an issue on the GitHub repo at https://github.com/potatoqualitee/kbupdate/issues" -Continue
                    }
                }

                # fix for SYSTEM which doesn't have a downloads directory by default
                Write-PSFMessage -Level Verbose -Message "Checking for home downloads directory"
                Invoke-PSFCommand -ScriptBlock {
                    if (-not (Test-Path -Path "$home\Downloads")) {
                        Write-Warning "Creating Downloads directory at $home\Downloads"
                        $null = New-Item -ItemType Directory -Force -Path "$home\Downloads"
                    }
                }

                $hasxhotfix = Invoke-PSFCommand -ScriptBlock {
                    Get-Module -ListAvailable xWindowsUpdate
                }

                if (-not $hasxhotfix) {
                    try {
                        # Copy xWindowsUpdate to Program Files. The module is pretty much required to be in the PS Modules directory.
                        $oldpref = $ProgressPreference
                        $ProgressPreference = "SilentlyContinue"
                        $programfiles = Invoke-PSFCommand -ScriptBlock {
                            $env:ProgramFiles
                        }
                        if ($item.IsLocalhost) {
                            $null = Copy-Item -Path "$script:ModuleRoot\library\xWindowsUpdate" -Destination "$programfiles\WindowsPowerShell\Modules\xWindowsUpdate" -Recurse -Force
                        } else {
                            $null = Copy-Item -Path "$script:ModuleRoot\library\xWindowsUpdate" -Destination "$programfiles\WindowsPowerShell\Modules\xWindowsUpdate" -ToSession $remotesession -Recurse -Force
                        }

                        $ProgressPreference = $oldpref
                    } catch {
                        Stop-PSFFunction -EnableException:$EnableException -Message "Couldn't auto-install xHotfix on $computer. Please Install-Module xWindowsUpdate on $computer to continue." -Continue
                    }
                }

                if ($InputObject.Link -and $RepositoryPath) {
                    $filename = Split-Path -Path $InputObject.Link -Leaf
                    Write-PSFMessage -Level Verbose -Message "Adding $filename"
                    $FilePath = Join-Path -Path $RepositoryPath -ChildPath $filename
                    $PSBoundParameters.FilePath = Join-Path -Path $RepositoryPath -ChildPath $filename
                    Write-PSFMessage -Level Verbose -Message "Adding $($PSBoundParameters.FilePath)"
                }

                if ($PSBoundParameters.FilePath) {
                    $remotefileexists = $updatefile = Invoke-PSFCommand -ArgumentList $FilePath -ScriptBlock {
                        Get-ChildItem -Path $args -ErrorAction SilentlyContinue
                    }
                }

                if (-not $remotefileexists) {
                    if ($FilePath) {
                        # try really hard to find it locally
                        $updatefile = Get-ChildItem -Path $FilePath -ErrorAction SilentlyContinue
                        if (-not $updatefile) {
                            Write-PSFMessage -Level Verbose -Message "Update file not found, try in Downloads"
                            $filename = Split-Path -Path $FilePath -Leaf
                            $updatefile = Get-ChildItem -Path "$home\Downloads\$filename" -ErrorAction SilentlyContinue
                        }
                    }

                    if (-not $updatefile) {
                        Write-PSFMessage -Level Verbose -Message "Update file not found, download it for them"
                        # try to automatically download it for them
                        if (-not $PSBoundParameters.InputObject) {
                            $InputObject = Get-KbUpdate -Architecture x64 -Latest -Pattern $HotfixId | Where-Object Link
                        }

                        # note to reader: if this picks the wrong one, please download the required file manually.
                        if ($InputObject.Link) {
                            if ($InputObject.Link -match 'x64') {
                                $file = $InputObject | Where-Object Link -match 'x64' | Select-Object -ExpandProperty Link -Last 1 | Split-Path -Leaf
                            } else {
                                $file = Split-Path $InputObject.Link -Leaf | Select-Object -Last 1
                            }
                        } else {
                            Stop-PSFFunction -EnableException:$EnableException -Message "Could not find file on $computer and couldn't find it online. Try piping in exactly what you'd like from Get-KbUpdate." -Continue
                        }

                        if ((Test-Path -Path "$home\Downloads\$file")) {
                            $updatefile = Get-ChildItem -Path "$home\Downloads\$file"
                        } else {
                            if ($PSCmdlet.ShouldProcess($computer, "File not detected, downloading now to $home\Downloads and copying to remote computer")) {
                                $warnatbottom = $true

                                # fix for SYSTEM which doesn't have a downloads directory by default
                                Write-PSFMessage -Level Verbose -Message "Checking for home downloads directory"
                                if (-not (Test-Path -Path "$home\Downloads")) {
                                    Write-PSFMessage -Level Warning -Message "Creating Downloads directory at $home\Downloads"
                                    $null = New-Item -ItemType Directory -Force -Path "$home\Downloads"
                                }

                                $updatefile = $InputObject | Select-Object -First 1 | Save-KbUpdate -Path "$home\Downloads"
                            }
                        }
                    }

                    if (-not $PSBoundParameters.FilePath) {
                        $FilePath = "$programhome\Downloads\$(Split-Path -Leaf $updateFile)"
                    }

                    if ($item.IsLocalhost) {
                        $remotefile = $updatefile
                    } else {
                        $remotefile = "$programhome\Downloads\$(Split-Path -Leaf $updateFile)"
                    }

                    # copy over to destination server unless
                    # it's local or it's on a network share
                    if (-not "$($PSBoundParameters.FilePath)".StartsWith("\\") -and -not $item.IsLocalhost) {
                        Write-PSFMessage -Level Verbose -Message "Update is not located on a file server and not local, copying over the remote server"
                        try {
                            $exists = Invoke-PSFCommand -ComputerName $computer -ArgumentList $remotefile -ScriptBlock {
                                Get-ChildItem -Path $args -ErrorAction SilentlyContinue
                            }
                            if (-not $exists) {
                                $null = Copy-Item -Path $updatefile -Destination $remotefile -ToSession $remotesession -ErrorAction Stop
                                $deleteremotefile = $remotefile
                            }
                        } catch {
                            $null = Invoke-PSFCommand -ComputerName $computer -ArgumentList $remotefile -ScriptBlock {
                                Remove-Item $args -Force -ErrorAction SilentlyContinue
                            }
                            try {
                                Write-PSFMessage -Level Warning -Message "Copy failed, trying again"
                                $null = Copy-Item -Path $updatefile -Destination $remotefile -ToSession $remotesession -ErrorAction Stop
                                $deleteremotefile = $remotefile
                            } catch {
                                $null = Invoke-PSFCommand -ComputerName $computer -ArgumentList $remotefile -ScriptBlock {
                                    Remove-Item $args -Force -ErrorAction SilentlyContinue
                                }
                                Stop-PSFFunction -EnableException:$EnableException -Message "Could not copy $updatefile to $remotefile" -ErrorRecord $PSItem -Continue
                            }
                        }
                    }
                }

                # if user doesnt add kb, try to find it for them from the provided filename
                if (-not $PSBoundParameters.HotfixId) {
                    $HotfixId = $FilePath.ToUpper() -split "\-" | Where-Object { $psitem.Startswith("KB") }
                }

                # i probably need to fix some logic but until then, check a few things
                if ($item.IsLocalHost) {
                    if ($updatefile) {
                        $FilePath = $updatefile
                    } else {
                        $updatefile = Get-ChildItem -Path $FilePath
                    }
                    if (-not $PSBoundParameters.Title) {
                        Write-PSFMessage -Level Verbose -Message "Trying to get Title from $($updatefile.FullName)"
                        $Title = $updatefile.VersionInfo.ProductName
                    }
                } elseif ($remotefile) {
                    $FilePath = $remotefile
                }

                if ($FilePath.EndsWith("exe")) {
                    if (-not $PSBoundParameters.ArgumentList -and $FilePath -match "sql") {
                        $ArgumentList = "/action=patch /AllInstances /quiet /IAcceptSQLServerLicenseTerms"
                    } else {
                        # Setting a default argumentlist that hopefully works for most things?
                        $ArgumentList = "/install /quiet /notrestart"
                    }

                    if (-not $Guid) {
                        if ($InputObject) {
                            $Guid = $PSBoundParameters.InputObject.Guid
                            $Title = $PSBoundParameters.InputObject.Title
                        } else {
                            if ($true) {
                                try {
                                    $hotfixid = $guid = $null
                                    Write-PSFMessage -Level Verbose -Message "Trying to get Title from $($updatefile.FullName)"
                                    $updatefile = Get-ChildItem -Path $updatefile.FullName -ErrorAction SilentlyContinue
                                    $Title = $updatefile.VersionInfo.ProductName
                                    Write-PSFMessage -Level Verbose -Message "Trying to get GUID from $($updatefile.FullName)"

                                    <#
                                    The reason you want to find the GUID is to save time, mostly, I guess?

                                    It saves time because it won't even attempt the install if there are GUID matches
                                    in the registry. If you pass a fake but compliant GUID, it attempts the install and
                                    fails, no big deal.

                                    Overall, it just seems like a good idea to get a GUID if it's required.
                                #>

                                    <#
                                    It's better to just read from memory but I can't get this to work
                                    $cab = New-Object Microsoft.Deployment.Compression.Cab.Cabinfo "C:\path\path.exe"
                                    $file = New-Object Microsoft.Deployment.Compression.Cab.CabFileInfo($cab, "0")
                                    $content = $file.OpenRead()
                                #>

                                    $cab = New-Object Microsoft.Deployment.Compression.Cab.Cabinfo $updatefile.FullName
                                    $files = $cab.GetFiles("*")
                                    $index = $files | Where-Object Name -eq 0
                                    if (-not $index) {
                                        $index = $files | Where-Object Name -match "none.xml| ParameterInfo.xml"
                                    }
                                    $temp = Get-PSFPath -Name Temp
                                    $indexfilename = $index.Name
                                    $xmlfile = Join-Path -Path $temp -ChildPath "$($updatefile.BaseName).xml"
                                    $null = $cab.UnpackFile($indexfilename, $xmlfile)
                                    if ((Test-Path -Path $xmlfile)) {
                                        $xml = [xml](Get-Content -Path $xmlfile)
                                        $tempguid = $xml.BurnManifest.Registration.Id
                                    }

                                    if (-not $tempguid -and $xml.MsiPatch.PatchGUID) {
                                        $tempguid = $xml.MsiPatch.PatchGUID
                                    }
                                    if (-not $tempguid -and $xml.Setup.Items.Patches.MSP.PatchCode) {
                                        $tempguid = $xml.Setup.Items.Patches.MSP.PatchCode
                                    }

                                    Get-ChildItem -Path $xmlfile -ErrorAction SilentlyContinue | Remove-Item -Confirm:$false -ErrorAction SilentlyContinue

                                    # if we can't find the guid, use one that we know
                                    # is valid but not associated with any hotfix
                                    if (-not $tempguid) {
                                        $tempguid = "DAADB00F-DAAD-B00F-B00F-DAADB00FB00F"
                                    }

                                    $guid = ([guid]$tempguid).Guid
                                } catch {
                                    $guid = "DAADB00F-DAAD-B00F-B00F-DAADB00FB00F"
                                }

                                Write-PSFMessage -Level Verbose -Message "GUID is $guid"
                            }
                        }
                    }

                    # this takes care of things like SQL Server updates
                    $hotfix = @{
                        Name       = 'Package'
                        ModuleName = 'PSDesiredStateConfiguration'
                        Property   = @{
                            Ensure     = 'Present'
                            ProductId  = $Guid
                            Name       = $Title
                            Path       = $FilePath
                            Arguments  = $ArgumentList
                            ReturnCode = 0, 3010
                        }
                    }
                } else {
                    # this takes care of WSU files
                    $hotfix = @{
                        Name       = 'xHotFix'
                        ModuleName = 'xWindowsUpdate'
                        Property   = @{
                            Ensure = 'Present'
                            Id     = $HotfixId
                            Path   = $FilePath
                        }
                    }
                    if ($PSDscRunAsCredential) {
                        $hotfix.Property.PSDscRunAsCredential = $PSDscRunAsCredential
                    }
                }

                if ($PSCmdlet.ShouldProcess($computer, "Installing file from $FilePath")) {
                    try {
                        Invoke-PSFCommand -ScriptBlock {
                            param (
                                $Hotfix,
                                $VerbosePreference,
                                $ManualFileName
                            )
                            $PSDefaultParameterValues.Remove("Invoke-WebRequest:ErrorAction")
                            $PSDefaultParameterValues['*:ErrorAction'] = 'SilentlyContinue'
                            $ErrorActionPreference = "Stop"

                            if (-not (Get-Command Invoke-DscResource)) {
                                throw "Invoke-DscResource not found on $env:ComputerName"
                            }
                            $null = Import-Module xWindowsUpdate -Force
                            Write-Verbose -Message "Installing $($hotfix.property.id) from $($hotfix.property.path)"
                            try {
                                if (-not (Invoke-DscResource @hotfix -Method Test)) {
                                    Invoke-DscResource @hotfix -Method Set -ErrorAction Stop
                                }
                            } catch {
                                $message = "$_"

                                # Unsure how to figure out params, try another way
                                if ($message -match "The return code 1 was not expected.") {
                                    try {
                                        Write-Verbose -Message "Retrying install with /quit parameter"
                                        $hotfix.Property.Arguments = "/quiet"
                                        Invoke-DscResource @hotfix -Method Set -ErrorAction Stop
                                    } catch {
                                        $message = "$_"
                                    }
                                }

                                switch ($message) {
                                    # some things can be ignored
                                    { $message -match "Serialized XML is nested too deeply" -or $message -match "Name does not match package details" } {
                                        $null = 1
                                    }
                                    { $message -match "2359302" } {
                                        throw "Error 2359302: update is already installed on $env:ComputerName"
                                    }
                                    { $message -match "could not be started" } {
                                        throw "The install coult not initiate. The $($hotfix.Property.Path) on $env:ComputerName may be corrupt or only partially downloaded. Delete it and try again."
                                    }
                                    { $message -match "2042429437" } {
                                        throw "Error -2042429437. Configuration is likely not correct. The requested features may not be installed or features are already at a higher patch level."
                                    }
                                    { $message -match "2068709375" } {
                                        throw "Error -2068709375. The exit code suggests that something is corrupt. See if this tutorial helps: http://www.sqlcoffee.com/Tips0026.htm"
                                    }
                                    { $message -match "2067919934" } {
                                        throw "Error -2067919934 You likely need to reboot $env:ComputerName."
                                    }
                                    { $message -match "2147942402" } {
                                        throw "System can't find the file specified for some reason."
                                    }
                                    default {
                                        throw
                                    }
                                }
                            }
                        } -ArgumentList $hotfix, $VerbosePreference, $PSBoundParameters.FileName -ErrorAction Stop

                        if ($deleteremotefile) {
                            Write-PSFMessage -Level Verbose -Message "Deleting $deleteremotefile"
                            $null = Invoke-PSFCommand -ComputerName $computer -ArgumentList $deleteremotefile -ScriptBlock {
                                Get-ChildItem -ErrorAction SilentlyContinue $args | Remove-Item -Force -ErrorAction SilentlyContinue -Confirm:$false
                            }
                        }

                        Write-Verbose -Message "Finished installing, checking status"
                        $exists = Get-KbInstalledUpdate -ComputerName $computer -Pattern $hotfix.property.id -IncludeHidden

                        if ($exists.Summary -match "restart") {
                            $status = "This update requires a restart"
                        } else {
                            $status = "Install successful"
                        }
                        if ($HotfixId) {
                            $id = $HotfixId
                        } else {
                            $id = $guid
                        }
                        if ($id -eq "DAADB00F-DAAD-B00F-B00F-DAADB00FB00F") {
                            $id = $null
                        }
                        [pscustomobject]@{
                            ComputerName = $computer
                            Title        = $Title
                            ID           = $id
                            Status       = $Status
                            FileName     = $updatefile.Name
                        } | Select-DefaultView -Property ComputerName, Title, Status, FileName, Id
                    } catch {
                        if ("$PSItem" -match "Serialized XML is nested too deeply") {
                            Write-PSFMessage -Level Verbose -Message "Serialized XML is nested too deeply. Forcing output."
                            $exists = Get-KbInstalledUpdate -ComputerName $computer -HotfixId $hotfix.property.id

                            if ($exists.Summary -match "restart") {
                                $status = "This update requires a restart"
                            } else {
                                $status = "Install successful"
                            }
                            if ($HotfixId) {
                                $id = $HotfixId
                            } else {
                                $id = $guid
                            }

                            if ($id -eq "DAADB00F-DAAD-B00F-B00F-DAADB00FB00F") {
                                $id = $null
                            }

                            [pscustomobject]@{
                                ComputerName = $computer
                                Title        = $Title
                                ID           = $id
                                Status       = $Status
                                FileName     = $updatefile.Name
                            } | Select-DefaultView -Property ComputerName, Title, Status, FileName, Id
                        } else {
                            Stop-PSFFunction -Message "Failure on $computer" -ErrorRecord $_ -EnableException:$EnableException
                        }
                    }
                }
            }
        }
    }
    end {
        if ($warnatbottom) {
            Write-PSFMessage -Level Output -Message "Downloaded files may still exist on your local drive and other servers as well, in the Downloads directory."
            Write-PSFMessage -Level Output -Message "If you ran this as SYSTEM, the downloads will be in windows\system32\config\systemprofile."
        }
    }
}