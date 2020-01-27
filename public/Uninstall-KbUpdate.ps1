function Uninstall-KbUpdate {

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
            #Stop-Function -EnableException:$EnableException -Message "You must specify either HotfixId or FilePath or pipe in the results from Get-KbUpdate"
            #return
        }

        # moved this from begin because it can be piped in which can only be seen in process
        if (-not $HotfixId.ToUpper().StartsWith("KB") -and $PSBoundParameters.HotfixId) {
            $HotfixId = "KB$HotfixId"
        }

        foreach ($computer in $ComputerName) {
            #null out a couple things to be safe
            $remoteexists = $remotehome = $remotesession = $null

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

            $updatereg = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ArgumentList $HotfixId -ScriptBlock {
                # props https://blog.dbi-services.com/sql-server-change-management-list-all-updates/
                # all other methods are incomplete, boo
                Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall -ErrorAction SilentlyContinue | Get-ItemProperty -ErrorAction SilentlyContinue | Where-Object DisplayName -match $args
            }

            $product = Get-CimInstance -ClassName Win32_Product -Filter 'InstallSource like "%KB4498951%"' -Property Name, Version, IdentifyingNumber

            $Title = $product.Name
            $FilePath = $product.InstallSource
            $localid = $product.IdentifyingNumber

            if ($FilePath.EndsWith("exe")) {
                $type = "exe"
            } else {
                $type = "msu"
            }

            $type = "exe"
            switch ($type) {
                "msu" {
                    if ($PSDscRunAsCredential) {
                        $hotfix = @{
                            Name       = 'xHotFix'
                            ModuleName = 'xWindowsUpdate'
                            Property   = @{
                                Id                   = $HotfixId
                                Path                 = $FilePath
                                Ensure               = 'Absent'
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
                                Ensure = 'Absent'
                            }
                        }
                    }
                }
                "exe" {
                    $hotfix = @{
                        Name       = 'Package'
                        ModuleName = 'PSDesiredStateConfiguration'
                        Property   = @{
                            Ensure     = 'Absent'
                            ProductId  = $localid
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
                        Write-Verbose -Message ("Uninstalling {0} from {1}" -f $hotfix.property.id, $hotfix.property.path)
                        try {
                            if (-not (Invoke-DscResource @hotfix -Method Test)) {
                                $results = Invoke-DscResource @hotfix -Method Set -ErrorAction Stop
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
                            Results      = $results
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
}
# PS C:\Users\ctrlb> Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Sort-Object -Property DisplayName | Where-Object {($_.DisplayName -like "Hotfix*SQL*") -or ($_.DisplayName -like "Service Pack*SQL*")}  | Select UninstallString
## xHotFix resource needs to be available on target machine - could we look for it and ship it out if it's needed?
## xHotFix has a log parameter - perhaps could read that back in for output
