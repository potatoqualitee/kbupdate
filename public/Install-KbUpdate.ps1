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

        foreach ($computer in $ComputerName.ComputerName) {
            # null out a couple things to be safe
            $remotefileexists = $remotehome = $remotesession = $null

            if ($computer -ne $env:ComputerName) {
                # a lot of the file copy work will be done in the remote $home dir
                $remotehome = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ScriptBlock { $home }

                if (-not $remotesession) {
                    $remotesession = Get-PSSession -ComputerName $computer | Where-Object { $PsItem.Availability -eq 'Available' -and ($PsItem.Name -match 'WinRM' -or $PsItem.Name -match 'Runspace') } | Select-Object -First 1
                }

                if (-not $remotesession) {
                    $remotesession = Get-PSSession -ComputerName $computer | Where-Object { $PsItem.Availability -eq 'Available' } | Select-Object -First 1
                }

                if (-not $remotesession) {
                    Stop-PSFFunction -EnableException:$EnableException -Message "Session for $computer can't be found or no runspaces are available. Please file an issue on the GitHub repo at https://github.com/potatoqualitee/kbupdate/issues" -Continue
                }
            }

            $hasxhotfix = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ScriptBlock {
                Get-Module -ListAvailable xWindowsUpdate
            }

            if (-not $hasxhotfix) {
                try {
                    # Copy xWindowsUpdate to Program Files. The module is pretty much required to be in the PS Modules directory.
                    $oldpref = $ProgressPreference
                    $ProgressPreference = "SilentlyContinue"
                    $programfiles = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ArgumentList "$env:ProgramFiles\WindowsPowerShell\Modules" -ScriptBlock {
                        $env:ProgramFiles
                    }
                    $null = Copy-Item -Path "$script:ModuleRoot\library\xWindowsUpdate" -Destination "$programfiles\WindowsPowerShell\Modules\xWindowsUpdate" -ToSession $remotesession -Recurse -Force
                    $ProgressPreference = $oldpref
                } catch {
                    Stop-PSFFunction -EnableException:$EnableException -Message "Couldn't auto-install xHotfix on $computer. Please Install-Module xWindowsUpdate on $computer to continue." -Continue
                }
            }

            if ($PSBoundParameters.FilePath) {
                $remotefileexists = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ArgumentList $FilePath -ScriptBlock { Get-ChildItem -Path $args -ErrorAction SilentlyContinue }
            }

            if (-not $remotefileexists) {
                if ($FilePath) {
                    # try really hard to find it locally
                    $updatefile = Get-ChildItem -Path $FilePath -ErrorAction SilentlyContinue
                    if (-not $updatefile) {
                        $filename = Split-Path -Path $FilePath -Leaf
                        $updatefile = Get-ChildItem -Path "$home\Downloads\$filename" -ErrorAction SilentlyContinue
                    }
                }

                if (-not $updatefile) {
                    # try to automatically download it for them
                    if (-not $PSBoundParameters.InputObject) {
                        $InputObject = Get-KbUpdate -Architecture x64 -Credential $credential -Latest -Pattern $HotfixId | Where-Object Link
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
                            $updatefile = $InputObject | Select-Object -First 1 | Save-KbUpdate -Path "$home\Downloads"
                        }
                    }
                }

                if (-not $PSBoundParameters.FilePath) {
                    $FilePath = "$remotehome\Downloads\$(Split-Path -Leaf $updateFile)"
                }

                # ignore if it's on a file server
                if (($updatefile -and -not "$($PSBoundParameters.FilePath)".StartsWith("\\")) -or $computer -ne $env:ComputerName) {
                    try {
                        $exists = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ArgumentList $FilePath -ScriptBlock {
                            Get-ChildItem -Path $args -ErrorAction SilentlyContinue
                        }
                        if (-not $exists) {
                            $null = Copy-Item -Path $updatefile -Destination $FilePath -ToSession $remotesession
                        }
                    } catch {
                        $null = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ArgumentList $FilePath -ScriptBlock {
                            Remove-Item $args -Force -ErrorAction SilentlyContinue
                        }
                        Stop-PSFFunction -EnableException:$EnableException -Message "Could not copy $updatefile to $filepath and no file was specified" -Continue
                    }
                } else {
                    Stop-PSFFunction -EnableException:$EnableException -Message "Could not find $HotfixId and no file was specified" -Continue
                }
            }

            # if user doesnt add kb, try to find it for them from the provided filename
            if (-not $PSBoundParameters.HotfixId) {
                $HotfixId = $FilePath.ToUpper() -split "\-" | Where-Object { $psitem.Startswith("KB") }
                if (-not $HotfixId) {
                    Stop-PSFFunction -EnableException:$EnableException -Message "Could not determine KB from $FilePath. Looked for '-kbnumber-'. Please provide a HotfixId."
                    return
                }
            }

            if ($FilePath.EndsWith("exe")) {
                if (-not $ArgumentList -and $FilePath -match "sql") {
                    $ArgumentList = "/action=patch /AllInstances /quiet /IAcceptSQLServerLicenseTerms"
                }

                if (-not $Guid) {
                    if ($InputObject) {
                        $Guid = $PSBoundParameters.InputObject.Guid
                        $Title = $PSBoundParameters.InputObject.Title
                    } else {
                        $InputObject = Get-KbUpdate -Architecture x64 -Credential $credential -Latest -Pattern $HotfixId | Where-Object Link | Select-Object -First 1
                        $Guid = $InputObject | Select-Object -ExpandProperty UpdateId
                        $Title = $InputObject | Select-Object -ExpandProperty Title
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

            if ($PSCmdlet.ShouldProcess($computer, "Installing Hotfix $HotfixId from $FilePath")) {
                try {
                    Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ScriptBlock {
                        param (
                            $Hotfix,
                            $VerbosePreference,
                            $ManualFileName
                        )
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
                            switch ($message = "$_") {
                                # some things can be ignored
                                { $message -match "Serialized XML is nested too deeply" -or $message -match "Name does not match package details" } {
                                    $null = 1
                                }
                                { $message -match "2359302" } {
                                    throw "Error 2359302: update is already installed on $env:ComputerName"
                                }
                                { $message -match "2042429437" } {
                                    throw "Error -2042429437. Configuration is likely not correct. The requested features may not be installed or features are already at a higher patch level."
                                }
                                { $message -match "2068709375" } {
                                    throw "Error -2068709375. The exit code suggests that something is corrupt. See if this tutorial helps:  http://www.sqlcoffee.com/Tips0026.htm"
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
                    Write-Verbose -Message "Finished installing, checking status"
                    $exists = Get-KbInstalledUpdate -ComputerName $computer -Credential $Credential -Pattern $hotfix.property.id -IncludeHidden

                    if ($exists.Summary -match "restart") {
                        $status = "This update requires a restart"
                    } else {
                        $status = "Install successful"
                    }

                    [pscustomobject]@{
                        ComputerName = $computer
                        HotfixID     = $HotfixId
                        Status       = $Status
                    }
                } catch {
                    if ("$PSItem" -match "Serialized XML is nested too deeply") {
                        Write-PSFMessage -Level Verbose -Message "Serialized XML is nested too deeply. Forcing output."
                        $exists = Get-KbInstalledUpdate -ComputerName $computer -Credential $credential -HotfixId $hotfix.property.id

                        if ($exists) {
                            [pscustomobject]@{
                                ComputerName = $computer
                                HotfixID     = $HotfixId
                                Status       = "Successfully installed. A restart is now required."
                            }
                        } else {
                            Stop-PSFFunction -Message "Failure on $computer" -ErrorRecord $_ -EnableException:$EnableException
                        }
                    } else {
                        Stop-PSFFunction -Message "Failure on $computer" -ErrorRecord $_ -EnableException:$EnableException
                    }
                }
            }
        }
    }
    end {
        if ($warnatbottom) {
            Write-PSFMessage -Level Output -Message "$updatefile still exists on your local drive, and likely other servers as well, in the Downloads directory."
        }
    }
}