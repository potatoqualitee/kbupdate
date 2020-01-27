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
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param (
        [string[]]$ComputerName = $env:ComputerName,
        [PSCredential]$Credential,
        [PSCredential]$PSDscRunAsCredential,
        [string]$HotfixId,
        [string]$FilePath,
        [ValidateSet("General", "SQL")]
        [string]$Type = "General",
        [switch]$EnableException
    )
    begin {
        if (-not $HotfixId.ToUpper().StartsWith("KB") -and $PSBoundParameters.HotfixId) {
            $HotfixId = "KB$HotfixId"
        }
    }
    process {
        if (-not $PSBoundParameters.HotfixId -and -not $PSBoundParameters.FilePath) {
            Stop-Function -EnableException:$EnableException -Message "You must specify either HotfixId or FilePath"
            return
        }

        foreach ($computer in $ComputerName) {
            $exists = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ArgumentList $HotfixId -ScriptBlock {
                Get-HotFix -Id $args -ErrorAction SilentlyContinue
            }

            if ($exists) {
                Stop-Function -EnableException:$EnableException -Message "$hotfixid is already installed on $computer" -Continue
            }

            $remotesession = Get-PSSession -ComputerName $computer | Where-Object Availability -eq Available

            if (-not $remotesession) {
                Stop-Function -EnableException:$EnableException -Message "Session for $computer can't be found or no runspaces are available. Please file an issue on the GitHub repo at https://github.com/potatoqualitee/kbupdate/issues" -Continue
            }

            # a lot of the file copy work will be done in the remote $home dir
            $remotehome = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ScriptBlock { $home }

            $sqldscexists = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ArgumentList $HotfixId -ScriptBlock {
                Get-Module -Listavailable -Name SqlServerDsc
            }


            # Copy every time even if remote computer has xWindowsUpdate because this version has Jess' fix
            $null = Copy-Item -Path "$script:ModuleRoot\library\xWindowsUpdate" -Destination "$remotehome\kbupdatetemp\xWindowsUpdate" -ToSession $remotesession -Recurse -Force

            if (-not $sqldscexists) {
                $null = Copy-Item -Path "$script:ModuleRoot\library\sqlserverdsc" -Destination "$remotehome\kbupdatetemp\sqlserverdsc" -ToSession $remotesession -Recurse -Force

            }

            if ($PSBoundParameters.FilePath) {
                $remoteexists = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ArgumentList $FileName -ScriptBlock { Get-ChildItem -Path $args }
            }

            if ((-not $remoteexists -or -not $PSBoundParameters.FilePath)) {
                if ($PSCmdlet.ShouldProcess($computer, "File not detected, downloading now and copying to remote computer")) {
                    if (-not $updatefile) {
                        $updatefile = Get-KbUpdate -ComputerName $computer -Architecture x64 -Credential $credential -Latest -Pattern $HotfixId | Select-Object -First 1 | Save-KbUpdate -Path $home
                    }
                    if (-not $FilePath) {
                        $FilePath = "$remotehome\$(Split-Path -Leaf $updateFile)"
                    }
                    if ($updatefile) {
                        $null = Copy-Item -Path $updatefile -Destination $FilePath -ToSession $remotesession -Force
                    } else {
                        Stop-Function -EnableException:$EnableException -Message "Could not find $HotfixId and no file was specified" -Continue
                    }
                }
            }

            # if user doesnt add kb, try to find it for them from the provided filename
            if (-not $PSBoundParameters.HotfixId) {
                #windows10.0-kb4516115-x64
                $HotfixId = $FilePath.ToUpper() -split "\-" | Where-Object { $psitem.Startswith("KB") }
                if (-not $HotfixId) {
                    Stop-Function -EnableException:$EnableException -Message "Could not determine KB from $FilePath. Looked for '-kbnumber-'" -Continue
                }
            }

            switch ($Type) {
                "General" {
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
                "SQL" {
                    # dont know yet
                }
            }

            if ($PSCmdlet.ShouldProcess($computer, "Installing Hotfix $HotfixId from $FilePath")) {
                Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ScriptBlock {
                    param (
                        $Hotfix,
                        $Verbose
                    )
                    if (-not (Get-Command Invoke-DscResource)) {
                        throw "Invoke-DscResource not found on $env:ComputerName"
                    }
                    # Extract exes, cabs? exe = /extract
                    Import-Module "$home\xWindowsUpdate" -Force
                    Write-Verbose -Message ("Installing {0} from {1}" -f $hotfix.property.id, $hotfix.property.path)
                    try {
                        if (-not (Invoke-DscResource @hotfix -Method Test -Verbose)) {
                            Invoke-DscResource @hotfix -Method Set -Verbose
                        }
                    } catch {
                        # sometimes there's a "Serialized XML" issue that can be ignored becuase
                        # the patch installs successfully anyway. so throw only if there's a real issue
                        if ($_.Exception.Message -notmatch "Serialized XML is nested too deeply") {
                            throw
                        }
                    }
                    Remove-Module xWindowsUpdate -ErrorAction SilentlyContinue
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -Path "$home\kbupdatetemp"
                } -ArgumentList $hotfix, $PSBoundParameters.Verbose
            }
        }

        if ($updatefile) {
            Remove-Item -Path $Path -ErrorAction SilentlyContinue
        }
    }
}

## could also use xPendingReboot to look for pending reboots and handle?

<#
Error - installs the hotfix successfully then :

Serialized XML is nested too deeply. Line 1, position 3507.
    + CategoryInfo          : OperationStopped: (dscsvr2:String) [], PSRemotingTransportException
    + FullyQualifiedErrorId : JobFailure
    + PSComputerName        : dscsvr2

#>