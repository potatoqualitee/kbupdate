function Get-KbNeededUpdate {
    <#
    .SYNOPSIS
        Scan for missing Windows updates.

    .DESCRIPTION
        This cmdlet scans for missing Windows updates. It can scan against:

        - Windows Server Update Service (WSUS) server
        - Windows Update (cloud service)
        - Windows Update offline scan file (wsusscn2.cab - see https://learn.microsoft.com/windows/win32/wua_sdk/using-wua-to-scan-for-updates-offline)

        The offline scan file can be downloaded using Save-KbScanFile from an internet-connected computer.

    .PARAMETER ComputerName
        Used to connect to a remote host. Connects to localhost by default -- if scanning the local computer, the command must be run as administrator.

    .PARAMETER Credential
        The optional alternative credential to be used when connecting to ComputerName

    .PARAMETER UseWindowsUpdate
        This optional parameter will force the Windows Update Agent (WUA) to scan for needed updates against Windows Update (cloud service) instead of WSUS, regardless if the device is configured to use a WSUS server.

    .PARAMETER ScanFilePath
        If the Windows Update Agent (WUA) does not have access to WSUS or Windows Update a local copy of the catalog can be provided.

        The local copy of the catalog is the Windows Update offline scan file (wsusscn2.cab - see https://learn.microsoft.com/windows/win32/wua_sdk/using-wua-to-scan-for-updates-offline).

        This optional parameter will force the command to use a local update database instead of WSUS or Windows Update.

        The scan file catalog/database can be downloaded using Save-KbScanFile from an internet-connected computer. UNC paths are staged automatically in the target computer's temporary directory because WUA requires a local path. A cached file with the same name and size is reused.

    .PARAMETER Force
        Copies a controller-local scan file to a temporary directory on a remote target. UNC scan files are staged automatically and do not require Force.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Author: Chrissy LeMaire (@cl), netnerds.net
        Copyright: (c) licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .EXAMPLE
        PS C:\> Get-KbNeededUpdate

        Gets all the updates needed on the local machine

    .EXAMPLE
        PS C:\> Get-KbNeededUpdate -ComputerName server01

        Gets all the updates needed on server01

    .EXAMPLE
        PS C:\> Get-KbNeededUpdate -ComputerName server01 -ScanFilePath $scanfile | Install-KbUpdate

        Installs needed updates on server01

    .EXAMPLE
        PS C:\> Get-KbNeededUpdate -ComputerName server01 -ScanFilePath \\fileserver\updates\wsusscn2.cab

        Stages the UNC scan file in server01's temporary directory when needed, then scans with the target-local copy.

    .EXAMPLE
        PS C:\> Get-KbNeededUpdate | Save-KbUpdate -Path C:\temp

        Saves all the updates needed on the local machine to C:\temp

    .EXAMPLE
        PS C:\> Get-KbNeededUpdate -ScanFilePath D:\wsusscn2.cab | Export-Clixml D:\needed-updates.clixml

        Exports the exact update identities and download links found on an offline computer. Move the CLIXML file to an internet-connected computer and pipe Import-Clixml to Save-KbUpdate.
#>
    [CmdletBinding(DefaultParameterSetName = 'UseWUA')]
    param(
        [PSFComputer[]]$ComputerName = $env:COMPUTERNAME,
        [pscredential]$Credential,
        [parameter(ParameterSetName = 'UseWUA')]
        [switch]$UseWindowsUpdate,
        [parameter(ParameterSetName = 'UseScanFile', ValueFromPipeline)]
        [Alias("FullName")]
        [string]$ScanFilePath,
        [parameter(ParameterSetName = 'UseScanFile')]
        [switch]$Force,
        [switch]$EnableException
    )
    begin {
        $remotescriptblock = (Get-Command Get-Needed).Definition | ConvertTo-Json -Depth 3 -Compress
        $jobs = @()
    }
    process {
        if ($IsLinux -or $IsMacOs) {
            Stop-PSFFunction -Message "This command using remoting and only supports Windows at this time" -EnableException:$EnableException
            return
        }
        foreach ($computer in $ComputerName) {
            if ($computer.IsLocalHost -and -not (Test-ElevationRequirement -ComputerName $computer)) {
                continue
            }

            try {
                Write-PSFMessage -Level Verbose -Message "Adding job for $computer"
                if ($ScanFilePath -and -not $UseWindowsUpdate) {
                    $cabPath = Resolve-KbScanFilePath -ScanFilePath $ScanFilePath -ComputerName $computer -Credential $Credential -Force:$Force
                } else {
                    $cabPath = $ScanFilePath
                }
                $arglist = [pscustomobject]@{
                    ComputerName     = $computer
                    Credential       = $Credential
                    UseWindowsUpdate = $UseWindowsUpdate
                    ScanFilePath     = $cabPath
                    EnableException  = $EnableException
                    ScriptBlock      = $remotescriptblock
                    ModulePath       = $script:dependencies
                }

                $invokeblock = {
                    foreach ($path in $args.ModulePath) {
                        $null = Import-Module $path 4>$null
                    }
                    $sbjson           = $args.ScriptBlock | ConvertFrom-Json
                    $sb               = [scriptblock]::Create($sbjson)
                    $machine          = $args.ComputerName
                    $Credential       = $args.Credential
                    $UseWindowsUpdate = $args.UseWindowsUpdate
                    $ScanFilePath     = $args.ScanFilePath
                    $EnableException  = $args.EnableException
                    $ScriptBlock      = $sb

                    $computer = $machine.ComputerName
                    $null = $completed++

                    function Test-ElevationRequirement {
                        [CmdletBinding(DefaultParameterSetName = 'Stop')]
                        param (
                            [PSFComputer]$ComputerName,
                            [Parameter(ParameterSetName = 'Stop')]
                            [switch]$Continue,
                            [Parameter(ParameterSetName = 'Stop')]
                            [string]$ContinueLabel,
                            [Parameter(ParameterSetName = 'Stop')]
                            [switch]$SilentlyContinue,
                            [Parameter(ParameterSetName = 'NoStop')]
                            [switch]$NoStop,
                            [bool]$EnableException = $EnableException
                        )

                        $isElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                        $testResult = $true
                        if ($ComputerName.IsLocalHost -and (-not $isElevated)) { $testResult = $false }

                        if ($PSCmdlet.ParameterSetName -like "NoStop") {
                            return $testResult
                        } elseif ($PSCmdlet.ParameterSetName -like "Stop") {
                            if ($testResult) { return $testResult }

                            $splatStopFunction = @{
                                Message = "Console not elevated, but elevation is required to perform some actions on localhost for this command."
                            }

                            if ($PSBoundParameters.Continue) { $splatStopFunction["Continue"] = $Continue }
                            if ($PSBoundParameters.ContinueLabel) { $splatStopFunction["ContinueLabel"] = $ContinueLabel }
                            if ($PSBoundParameters.SilentlyContinue) { $splatStopFunction["SilentlyContinue"] = $SilentlyContinue }

                            . Stop-PSFFunction @splatStopFunction -FunctionName (Get-PSCallStack)[1].Command
                            return $testResult
                        }
                    }
                    if ($machine.IsLocalHost -and -not (Test-ElevationRequirement -ComputerName $computer)) {
                        continue
                    }
                    Invoke-PSFCommand -Computer $computer -Credential $Credential -ErrorAction Stop -ScriptBlock $scriptblock -ArgumentList $computer, $cabpath, $UseWindowsUpdate, $VerbosePreference
                }

                $jobs += Start-Job -Name $computer -ScriptBlock $invokeblock -ArgumentList $arglist -ErrorAction Stop
            } catch {
                Stop-PSFFunction -EnableException:$EnableException -Message "Failure on $computer" -ErrorRecord $PSItem -Continue
            }
        }
        if ($jobs.Name) {
            try {
                foreach ($result in ($jobs | Start-JobProcess -Activity "Getting needed updates" -Status "getting needed updates" | Select-Object -Property * -ExcludeProperty PSComputerName, RunspaceId | Select-DefaultView -ExcludeProperty InstallFile | Select-DefaultView -Property ComputerName, Title, KBUpdate, UpdateId, Description, LastModified, RebootBehavior, RequestsUserInput, NetworkRequired, Link)) {
                    $result | Resolve-KbNeededUpdateLink -Credential $Credential
                }
            } catch {
                Stop-PSFFunction -Message "Failure" -ErrorRecord $PSItem -EnableException:$EnableException -Continue
            }
        }
    }
}