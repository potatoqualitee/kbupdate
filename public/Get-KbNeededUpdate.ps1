function Get-KbNeededUpdate {
    <#
    .SYNOPSIS
         Checks for needed updates.

    .DESCRIPTION
         Checks for needed updates.

    .PARAMETER ComputerName
        Used to connect to a remote host. Connects to localhost by default -- if scanning the local computer, the command must be run as administrator.

    .PARAMETER Credential
        The optional alternative credential to be used when connecting to ComputerName

    .PARAMETER ScanFilePath
        If Windows Update does not have access to WSUS or Microsoft's update catalog, a local copy of the catalog can be provided.

        This optional parameter will force the command to use a local update database instead of WSUS or Microsoft's online update catalog.

        The scan file catalog/database can be downloaded using Save-KbScanFile from an internet-connected computer.

    .PARAMETER Force
        Force will copies the scan file to a temporary directory on the remote system if required.

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
        PS C:\> Get-KbNeededUpdate | Save-KbUpdate -Path C:\temp

        Saves all the updates needed on the local machine to C:\temp
#>
    [CmdletBinding()]
    param(
        [PSFComputer[]]$ComputerName = $env:COMPUTERNAME,
        [pscredential]$Credential,
        [parameter(ValueFromPipeline)]
        [Alias("FullName")]
        [string]$ScanFilePath,
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
            if ($machine.IsLocalHost -and -not (Test-ElevationRequirement -ComputerName $computer)) {
                continue
            }

            try {
                Write-PSFMessage -Level Verbose -Message "Adding job for $computer"
                $arglist = [pscustomobject]@{
                    ComputerName    = $computer
                    Credential      = $Credential
                    ScanFilePath    = $ScanFilePath
                    EnableException = $EnableException
                    Force           = $Force
                    ScriptBlock     = $remotescriptblock
                }

                $invokeblock = {
                    $sbjson = $args.ScriptBlock | ConvertFrom-Json
                    $sb = [scriptblock]::Create($sbjson)
                    $machine = $args.ComputerName
                    $Credential = $args.Credential
                    $ScanFilePath = $args.ScanFilePath
                    $EnableException = $args.EnableException
                    $Force = $args.Force
                    $ScriptBlock = $sb

                    $computer = $machine.ComputerName
                    $null = $completed++

                    if ($ScanFilePath -and $Force -and -not $machine.IsLocalhost) {
                        Write-PSFMessage -Level Verbose -Message "Initializing remote session to $computer and getting the path to the temp directory"

                        $scanfile = Get-ChildItem -Path $ScanFilePath
                        $temp = Invoke-PSFCommand -Computer $computer -Credential $Credential -ErrorAction Stop -ScriptBlock {
                            [system.io.path]::GetTempPath()
                        }
                        $filename = Split-Path -Path $ScanFilePath -Leaf
                        $cabpath = Join-PSFPath -Path $temp -Child $filename

                        Write-PSFMessage -Level Verbose -Message "Checking to see if $cabpath already exists on $computer"

                        $exists = Invoke-PSFCommand -Computer $computer -Credential $Credential -ArgumentList $cabpath -ErrorAction Stop -ScriptBlock {
                            Get-ChildItem -Path $args -ErrorAction Ignore
                        }

                        if ($exists.BaseName -and $scanfile.Length -eq $exists.Length) {
                            Write-PSFMessage -Level Verbose -Message "File exists and is of the same size. Skipping copy"
                        } else {
                            Write-PSFMessage -Level Verbose -Message "File does not exist"
                            if ($Credential) {
                                $PSDefaultParameterValues["*:Credential"] = $Credential
                            }

                            $remotesession = Get-PSSession | Where-Object Name -eq "kbupdate-$computer"

                            if (-not $remotesession) {
                                $remotesession = Invoke-KbCommand -ComputerName $computer -ScriptBlock { Get-ChildItem }
                                $remotesession = Get-PSSession | Where-Object Name -eq "kbupdate-$computer"
                            }

                            if (-not $remotesession) {
                                Stop-PSFFunction -EnableException:$EnableException -Message "Session for $computer can't be found or no runspaces are available. Please file an issue on the GitHub repo at https://github.com/potatoqualitee/kbupdate/issues" -Continue
                            }

                            Write-PSFMessage -Level Verbose -Message "Copying $ScanFilePath to $temp on $computer"
                            $null = Copy-Item -Path $ScanFilePath -Destination $temp -ToSession $remotesession -Force
                        }
                    } else {
                        $cabpath = $ScanFilePath
                    }

                    if ($machine.IsLocalHost -and -not (Test-ElevationRequirement -ComputerName $computer)) {
                        continue
                    }

                    $result = Invoke-PSFCommand -Computer $computer -Credential $Credential -ErrorAction Stop -ScriptBlock $scriptblock -ArgumentList $computer, $cabpath, $VerbosePreference
                    if (-not $result.Link) {
                        Write-PSFMessage -Level Verbose -Message "No link found for $($result.KBUpdate.Trim()). Looking it up."
                        $link = (Get-KbUpdate -Pattern "$($result.KBUpdate.Trim())" -Simple -Computer $computer | Where-Object Title -match $result.KBUpdate).Link
                        if ($link) {
                            $result.Link = $link
                        }
                    }
                    $result
                }

                $jobs += Start-Job -Name $computer -ScriptBlock $invokeblock -ArgumentList $arglist -ErrorAction Stop
            } catch {
                Stop-PSFFunction -EnableException:$EnableException -Message "Failure on $computer" -ErrorRecord $PSItem -Continue
            }
        }
        if ($jobs.Name) {
            try {
                $jobs | Start-JobProcess -Activity "Getting needed updates" -Status "getting needed updates" | Select-Object -Property * -ExcludeProperty PSComputerName, RunspaceId | Select-DefaultView -ExcludeProperty InstallFile | Select-DefaultView -Property ComputerName, Title, KBUpdate, UpdateId, Description, LastModified, RebootBehavior, RequestsUserInput, NetworkRequired, Link
            } catch {
                Stop-PSFFunction -Message "Failure" -ErrorRecord $PSItem -EnableException:$EnableException -Continue
            }
        }
    }
}