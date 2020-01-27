function Install-KbUpdate {
    <#
    .SYNOPSIS
        Installs

    .DESCRIPTION
        Installs etc

    .PARAMETER ComputerName
        Get the Operating System and architecture information automatically

    .PARAMETER Credential
        The optional alternative credential to be used when connecting to ComputerName

    .PARAMETER PSDscRunAsCredential
        Run the install as a specific user (other than SYSTEM) on the target node

    .PARAMETER HotfixId
        The HotfixId of the patch. This needs to be updated to be more in-depth.

    .PARAMETER FilePath
        The filepath of the patch. This needs to be updated to be more in-depth.

    .PARAMETER Guid
        The filepath of the patch. This needs to be updated to be more in-depth.

    .PARAMETER Type
        The type of patch. Basically General or SQL.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Update
        Author: Jess Pomfret (@jpomfret)
        Copyright: (c) licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .EXAMPLE
        PS C:\> Install-KbUpdate -ComputerName sql2017 -HotfixId KB4534273 -FilePath C:\temp\windows10.0-kb4534273-x64_74bf76bc5a941bbbd0052caf5c3f956867e1de38.msu

        Installs KB4534273 from the C:\temp directory on sql2017

    .EXAMPLE
        PS C:\> Get-KbUpdate -Pattern 4498951 | Install-KbUpdate -Type SQL -ComputerName sql2017

        Installs KB4534273 from the C:\temp directory on sql2017
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    param (
        [string[]]$ComputerName = $env:ComputerName,
        [PSCredential]$Credential,
        [PSCredential]$PSDscRunAsCredential,
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]$HotfixId,
        [string]$FilePath,
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias("UpdateId")]
        [string]$Guid,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Title,
        [switch]$NoDelete,
        [Parameter(ValueFromPipeline)]
        [pscustomobject]$InputObject,
        [switch]$Force,
        [switch]$EnableException
    )
    process {
        if (-not $PSBoundParameters.HotfixId -and -not $PSBoundParameters.FilePath -and -not $PSBoundParameters.InputObject) {
            Stop-Function -EnableException:$EnableException -Message "You must specify either HotfixId or FilePath or pipe in the results from Get-KbUpdate"
            return
        }

        # moved this from begin because it can be piped in which can only be seen in process
        if (-not $HotfixId.ToUpper().StartsWith("KB") -and $PSBoundParameters.HotfixId) {
            $HotfixId = "KB$HotfixId"
        }

        foreach ($computer in $ComputerName) {
            #null out a couple things to be safe
            $remoteexists = $remotehome = $remotesession = $null

            if ($HotFixId) {
                $exists = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ArgumentList $HotfixId -ScriptBlock {
                    # props https://blog.dbi-services.com/sql-server-change-management-list-all-updates/
                    # all other methods are incomplete, boo
                    Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall -ErrorAction SilentlyContinue | Get-ItemProperty -ErrorAction SilentlyContinue | Where-Object DisplayName -match $args
                }
                if ($exists) {
                    Stop-Function -EnableException:$EnableException -Message "$hotfixid is already installed on $computer" -Continue
                }
            }

            # a lot of the file copy work will be done in the remote $home dir
            $remotehome = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ScriptBlock { $home }
            $remotesession = Get-PSSession -ComputerName $computer | Where-Object Availability -eq Available

            if (-not $remotesession) {
                Stop-Function -EnableException:$EnableException -Message "Session for $computer can't be found or no runspaces are available. Please file an issue on the GitHub repo at https://github.com/potatoqualitee/kbupdate/issues" -Continue
            }

            # Copy every time even if remote computer has xWindowsUpdate because this version has Jess' fix
            $oldpref = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'
            $null = Copy-Item -Path "$script:ModuleRoot\library\xWindowsUpdate" -Destination "$remotehome\kbupdatetemp\xWindowsUpdate" -ToSession $remotesession -Recurse -Force
            $ProgressPreference = $oldpref

            if ($PSBoundParameters.FilePath) {
                $remoteexists = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ArgumentList $FilePath -ScriptBlock { Get-ChildItem -Path $args -ErrorAction SilentlyContinue }
            }

            if (-not $remoteexists) {
                if (-not $updatefile) {
                    # need to detect being piped in via InputObject
                    if (-not $PSBoundParameters.InputObject) {
                        $InputObject = Get-KbUpdate -ComputerName $computer -Architecture x64 -Credential $credential -Latest -Pattern $HotfixId
                    }

                    $file = Split-Path $InputObject.Link -Leaf

                    if ((Test-Path -Path "$home\$file")) {
                        $updatefile = Get-ChildItem -Path "$home\$file"
                    } else {
                        if ($PSCmdlet.ShouldProcess($computer, "File not detected, downloading now and copying to remote computer")) {
                            $updatefile = $InputObject | Select-Object -First 1 | Save-KbUpdate -Path $home
                        }
                    }
                }

                if (-not $FilePath) {
                    $FilePath = "$remotehome\kbupdatetemp\$(Split-Path -Leaf $updateFile)"
                }

                if ($updatefile) {
                    try {
                        $null = Copy-Item -Path $updatefile -Destination $FilePath -ToSession $remotesession -ErrrorAction Stop
                    } catch {
                        $exists = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ArgumentList $FilePath -ScriptBlock {
                            Remove-Item $args -Force -ErrorAction SilentlyContinue
                        }
                    }
                } else {
                    Stop-Function -EnableException:$EnableException -Message "Could not find $HotfixId and no file was specified" -Continue
                }
            }

            # if user doesnt add kb, try to find it for them from the provided filename
            if (-not $PSBoundParameters.HotfixId) {
                $HotfixId = $FilePath.ToUpper() -split "\-" | Where-Object { $psitem.Startswith("KB") }
                if (-not $HotfixId) {
                    Stop-Function -EnableException:$EnableException -Message "Could not determine KB from $FilePath. Looked for '-kbnumber-'. Please provide a HotfixId."
                    return
                }
            }

            if ($FilePath.EndsWith("exe")) {
                $type = "exe"
            } else {
                $type = "msu"
            }

            switch ($type) {
                "msu" {
                    if ($PSDscRunAsCredential) {
                        $hotfix = @{
                            Name       = 'xHotFix'
                            ModuleName = 'xWindowsUpdate'
                            Property   = @{
                                Id                   = $HotfixId
                                Path                 = $FilePath
                                Ensure               = 'Present'
                                PSDscRunAsCredential = $PSDscRunAsCredential
                            }
                        }
                    } else {
                        $hotfix = @{
                            Name       = 'xHotFix'
                            ModuleName = 'xWindowsUpdate'
                            Property   = @{
                                Id     = $HotfixId
                                Path   = $FilePath
                                Ensure = 'Present'
                            }
                        }
                    }
                }
                "exe" {
                    $hotfix = @{
                        Name       = 'Package'
                        ModuleName = 'PSDesiredStateConfiguration'
                        Property   = @{
                            Ensure     = 'Present'
                            ProductId  = $Guid
                            Name       = $Title
                            Path       = $FilePath
                            Arguments  = "/action=patch /AllInstances /quiet /IAcceptSQLServerLicenseTerms"
                            ReturnCode = 0, 3010
                        }
                    }
                }
            }

            ## could also use xPendingReboot to look for pending reboots and handle?

            if ($PSCmdlet.ShouldProcess($computer, "Installing Hotfix $HotfixId from $FilePath")) {
                try {
                    Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ScriptBlock {
                        param (
                            $Hotfix,
                            $VerbosePreference,
                            $NoDelete,
                            $ManualFileName
                        )

                        if (-not (Get-Command Invoke-DscResource)) {
                            throw "Invoke-DscResource not found on $env:ComputerName"
                        }
                        # Extract exes, cabs? exe = /extract
                        Import-Module "$home\kbupdatetemp\xWindowsUpdate" -Force
                        Write-Verbose -Message ("Installing {0} from {1}" -f $hotfix.property.id, $hotfix.property.path)
                        try {
                            if (-not (Invoke-DscResource @hotfix -Method Test)) {
                                Invoke-DscResource @hotfix -Method Set -ErrorAction Stop
                            }
                        } catch {
                            switch ($message = "$_") {
                                # sometimes there's a "Serialized XML" issue that can be ignored because
                                # the patch installs successfully anyway. so throw only if there's a real issue
                                # Serialized XML is nested too deeply. Line 1, position 3507."
                                { $message -match "Serialized XML is nested too deeply" -or $message -match "Name does not match package details" } {
                                    # nothing
                                }
                                { $message -match "2042429437" } {
                                    throw "The return code -2042429437 was not expected. Configuration is likely not correct. The requested features may not be installed or features are already at a higher patch level."
                                }
                                { $message -match "2067919934" } {
                                    throw "The return code -2067919934 was not expected. You likely need to reboot $env:ComputerName."
                                }
                                default {
                                    Remove-Module xWindowsUpdate -ErrorAction SilentlyContinue
                                    if (-not $NoDelete -and -not $ManualFileName) {
                                        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -Path "$home\kbupdatetemp"
                                    }
                                    throw
                                }
                            }
                        }

                        [pscustomobject]@{
                            ComputerName = $env:ComputerName
                            HotfixID     = $hotfix.property.id
                            Status       = "Success"
                        }
                        Remove-Module xWindowsUpdate -ErrorAction SilentlyContinue
                        if (-not $NoDelete -and -not $ManualFileName) {
                            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -Path "$home\kbupdatetemp"
                        }
                    } -ArgumentList $hotfix, $VerbosePreference, $NoDelete, $PSBoundParameters.FileName -ErrorAction Stop
                } catch {
                    Stop-Function -Message "Failure on $computer" -ErrorRecord $_ -EnableException:$EnableException
                }
            }
        }
    }
    end {
        # if copy-item tosession remote fails, we leave litter. gotta fix that.
        if ($updatefile -and -not $NoDelete) {
            Remove-Item -Path $Path -ErrorAction SilentlyContinue
        }
    }
}