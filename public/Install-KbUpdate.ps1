function Install-KbUpdate {
    <#
    .SYNOPSIS
        Installs

    .DESCRIPTION
        Installs etc

    .PARAMETER ComputerName
        Used to connect to a remote host

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
        Author: Jess Pomfret (@jpomfret)
        Copyright: (c) licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .EXAMPLE
        PS C:\> Install-KbUpdate -ComputerName sql2017 -HotfixId KB4534273 -FilePath C:\temp\windows10.0-kb4534273-x64_74bf76bc5a941bbbd0052caf5c3f956867e1de38.msu

        Installs KB4534273 from the C:\temp directory on sql2017

    .EXAMPLE
        PS C:\> Get-KbUpdate -Pattern 4498951 | Install-KbUpdate -ComputerName sql2017 -NoDelete -FilePath \\dc\sql\sqlserver2017-kb4498951-x64_b143d28a48204eb6ebab62394ce45df53d73f286.exe

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

        if (-not $HotfixId.ToUpper().StartsWith("KB") -and $PSBoundParameters.HotfixId) {
            $HotfixId = "KB$HotfixId"
        }

        foreach ($computer in $ComputerName) {
            # null out a couple things to be safe
            $remotefileexists = $remotehome = $remotesession = $null

            if ($HotFixId) {
                if (Get-KbInstalledUpdate -ComputerName $computer -Credential $Credential -Pattern $HotFixId) {
                    Stop-Function -EnableException:$EnableException -Message "$HotFixId is already installed on $computer" -Continue
                }
            }

            # a lot of the file copy work will be done in the remote $home dir
            $remotehome = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ScriptBlock { $home }
            $hasxhotfix = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ScriptBlock {
                Get-Module -ListAvailable xWindowsUpdate
                Get-ChildItem -Path "$remotehome\kbupdatetemp\xWindowsUpdate\xWindowsUpdate.psd1" -ErrorAction SilentlyContinue
            }
            $remotesession = Get-PSSession -ComputerName $computer | Where-Object { $PsItem.Availability -eq 'Available' -and $PsItem.Name -match 'WinRM' } | Select-Object -First 1

            if (-not $remotesession) {
                Stop-Function -EnableException:$EnableException -Message "Session for $computer can't be found or no runspaces are available. Please file an issue on the GitHub repo at https://github.com/potatoqualitee/kbupdate/issues" -Continue
            }

            if (-not $hasxhotfix) {
                try {
                    $oldpref = $ProgressPreference
                    $ProgressPreference = 'SilentlyContinue'
                    $null = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ArgumentList "$remotehome\kbupdatetemp" -ScriptBlock {
                        Remove-Item $args -Force -ErrorAction SilentlyContinue -Recurse
                    }
                    $null = Copy-Item -Path "$script:ModuleRoot\library\xWindowsUpdate" -Destination "$remotehome\kbupdatetemp\xWindowsUpdate" -ToSession $remotesession -Recurse -Force
                    $ProgressPreference = $oldpref
                } catch {
                    $null = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ArgumentList "$remotehome\kbupdatetemp" -ScriptBlock {
                        Remove-Item $args -Force -ErrorAction SilentlyContinue -Recurse
                    }
                    Stop-Function -EnableException:$EnableException -Message "Couldn't auto-install xHotfix on $computer. Please Install-Module xWindowsUpdate on $computer to continue." -Continue
                }
            }

            if ($PSBoundParameters.FilePath) {
                $remotefileexists = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ArgumentList $FilePath -ScriptBlock { Get-ChildItem -Path $args -ErrorAction SilentlyContinue }
            }

            if (-not $remotefileexists) {
                if (-not $updatefile) {
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

                if (-not $PSBoundParameters.FilePath) {
                    $FilePath = "$remotehome\kbupdatetemp\$(Split-Path -Leaf $updateFile)"
                }

                # ignore if it's on a file server
                if ($updatefile -and -not ($PSBoundParameters.FilePath).StartsWith("\\")) {
                    try {
                        $null = Copy-Item -Path $updatefile -Destination $FilePath -ToSession $remotesession -ErrrorAction Stop
                    } catch {
                        $null = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ArgumentList $FilePath -ScriptBlock {
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
                    # RIGHT HERE DO if dsc then .ddsc =
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
                            Arguments  = $ArgumentList
                            ReturnCode = 0, 3010
                        }
                    }
                }
            }

            if ($PSCmdlet.ShouldProcess($computer, "Installing Hotfix $HotfixId from $FilePath")) {
                try {
                    Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ScriptBlock {
                        param (
                            $Hotfix,
                            $VerbosePreference,
                            $NoDelete,
                            $ManualFileName
                        )
                        $PSDefaultParameterValues['*:ErrorAction'] = 'SilentlyContinue'
                        if (-not (Get-Command Invoke-DscResource)) {
                            throw "Invoke-DscResource not found on $env:ComputerName"
                        }

                        $null = Import-Module xWindowsUpdate

                        if (-not (Get-Module -Name xWindowsUpdate)) {
                            Import-Module "$home\kbupdatetemp\xWindowsUpdate" -Force
                        }

                        # Extract exes, cabs? exe = /extract
                        Write-Verbose -Message ("Installing {0} from {1}" -f $hotfix.property.id, $hotfix.property.path)
                        try {
                            if (-not (Invoke-DscResource @hotfix -Method Test)) {
                                Invoke-DscResource @hotfix -Method Set -ErrorAction Stop
                            }
                        } catch {
                            Remove-Module xWindowsUpdate
                            Remove-Item -Recurse -Force -Path "$home\kbupdatetemp"
                            switch ($message = "$_") {
                                # some things can be ignored
                                { $message -match "Serialized XML is nested too deeply" -or $message -match "Name does not match package details" } {
                                    $null = 1
                                }
                                { $message -match "2042429437" } {
                                    throw "The return code -2042429437 was not expected. Configuration is likely not correct. The requested features may not be installed or features are already at a higher patch level."
                                }
                                { $message -match "2067919934" } {
                                    throw "The return code -2067919934 was not expected. You likely need to reboot $env:ComputerName."
                                }
                                default {
                                    throw
                                }
                            }
                        }
                        [pscustomobject]@{
                            ComputerName = $env:ComputerName
                            Name         = $Name
                            HotfixID     = $hotfix.property.id
                            Status       = "Seems successful"
                        }
                        Remove-Module xWindowsUpdate
                        Remove-Item -Recurse -Force -Path "$home\kbupdatetemp\xWindowsUpdate"
                        if (-not $NoDelete -and -not $ManualFileName) {
                            Remove-Item -Recurse -Force -Path "$home\kbupdatetemp"
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