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

    .PARAMETER AllNeeded
        Installs all needed updates

    .PARAMETER ArgumentList
        This is an advanced parameter for those of you who need special argumentlists for your platform-specific update.

        The argument list required by SQL updates are already accounted for.

    .PARAMETER InputObject
        Allows infos to be piped in from Get-KbUpdate

    .PARAMETER NoMultithreading
        Don't use jobs to install updates

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Author: Chrissy LeMaire (@cl), Jess Pomfret (@jpomfret)
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
        PS C:\> Get-KbNeededUpdate -OutVariable needed | Save-KbUpdate -Path C:\temp
        PS C:\> $needed | Install-KbUpdate -RepositoryPath C:\temp

        Saves the files for needed updates then installs them from that path

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
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias("UpdateId")]
        [string]$Guid,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Title,
        [string]$ArgumentList,
        [Parameter(ValueFromPipeline)]
        [pscustomobject[]]$InputObject,
        [switch]$AllNeeded,
        [switch]$NoMultithreading,
        [switch]$EnableException
    )
    begin {
        # create code blocks for  jobs
        $cmd2 = $((Get-Command Invoke-Command2).Definition)
        $wublock = [scriptblock]::Create($((Get-Command Start-WindowsUpdate).Definition))
        $dscblock = [scriptblock]::Create($((Get-Command Start-DscUpdate).Definition).Replace("# function Invoke-PSFCommand", "function Invoke-PSFCommand { $cmd2 }"))
        # cleanup
        $null = Get-Job -ChildJobState Completed | Where-Object Name -in $ComputerName.ComputerName | Remove-Job -Force
    }
    process {
        if (-not $PSBoundParameters.HotfixId -and -not $PSBoundParameters.FilePath -and -not $PSBoundParameters.InputObject -and -not $AllNeeded) {
            Stop-PSFFunction -EnableException:$EnableException -Message "You must specify either HotfixId or FilePath or AllNeeded or pipe in the results from Get-KbUpdate"
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

        $jobs = @()
        $added = 0
        $totalsteps = ($ComputerName.Count * 2) + 1 # The plus one is for pretty

        foreach ($computer in $ComputerName) {
            $hostname = $computer.ComputerName
            $null = $completed++
            $null = $added++
            $method = $null

            if ($computer.IsLocalHost -and -not (Test-ElevationRequirement -ComputerName $hostname)) {
                Stop-PSFFunction -EnableException:$EnableException -Message "You must be an administrator to run this command on the local host" -Continue
            }
            $parms = @{
                Computer        = $hostname
                FilePath        = $FilePath
                HotfixId        = $HotfixId
                RepositoryPath  = $RepositoryPath
                Guid            = $Guid
                Title           = $Title
                ArgumentList    = $ArgumentList
                InputObject     = $InputObject
                EnableException = $EnableException
                IsLocalHost     = $computer.IsLocalHost
                AllNeeded       = $AllNeeded
            }

            $null = $PSDefaultParameterValues["Start-Job:ArgumentList"] = $parms
            $null = $PSDefaultParameterValues["Start-Job:Name"] = $hostname

            Write-Progress -Activity "Installing updates" -Status "Added $($computer.ComputerName) to queue. Processing $added computers..." -PercentComplete ($added / $totalsteps * 100)

            Write-PSFMessage -Level Verbose -Message "Processing $($parms.ComputerName)"

            if ($computer.IsLocalhost) {
                if ((Get-Service wuauserv | Where-Object StartType -ne Disabled) -and $InputObject.InputObject) {

                    Write-PSFMessage -Level Verbose -Message "Setting method to Windows Update $($parms.ComputerName)"
                    $method = "WindowsUpdate"
                }
                if ($AllNeeded -and -not $PSBoundParameters.InputObject.InputObject) {
                    Write-PSFMessage -Level Verbose -Message "Setting method to Windows Update $($parms.ComputerName) then getting all needed windows updates"
                    $method = "WindowsUpdate"
                    $InputObject = @(Get-KbNeededUpdate -ComputerName $computer)
                }
            } elseif ($AllNeeded -and -not $PSBoundParameters.InputObject.InputObject) {
                Write-PSFMessage -Level Verbose -Message "Getting all needed Windows Updates on $($parms.ComputerName)"
                $InputObject = Get-KbNeededUpdate -ComputerName $computer
            }

            try {
                if ($method -eq "WindowsUpdate") {
                    Write-PSFMessage -Level Verbose -Message "Method is WindowsUpdate"
                    if ($ComputerName.Count -eq 1 -or $NoMultithreading) {
                        Write-PSFMessage -Level Verbose -Message "Not using jobs"
                        Start-WindowsUpdate @parms
                    } else {
                        Write-PSFMessage -Level Verbose -Message "Using jobs"
                        $job = Start-Job -ScriptBlock $wublock
                    }
                } else {
                    Write-PSFMessage -Level Verbose -Message "Method is DSC"
                    if ($ComputerName.Count -eq 1 -or $NoMultithreading) {
                        Write-PSFMessage -Level Verbose -Message "Not using jobs"
                        Start-DscUpdate @parms -ErrorAction Stop
                    } else {
                        Write-PSFMessage -Level Verbose -Message "Using jobs"
                        $job = Start-Job -ScriptBlock $dscblock -ErrorAction Stop
                    }
                }
            } catch {
                write-warning hello
                Stop-PSFFunction -Message "Failure on $hostname" -ErrorRecord $PSItem -EnableException:$EnableException
            }
        }
        $jobs += $job

        if ($jobs.Name) {
            try {
                while ($kbjobs = Get-Job | Where-Object Name -in $jobs.Name) {
                    foreach ($item in $kbjobs) {
                        try {
                            $item | Receive-Job -ErrorAction Stop -OutVariable kbjob | Select-Object -Property * -ExcludeProperty RunspaceId
                        } catch {
                            Stop-PSFFunction -Message "Failure on $($item.Name)" -ErrorRecord $PSItem -EnableException:$EnableException -Continue
                        }

                        if ($kbjob.Output) {
                            $kbjob.Output | Write-Output
                        }
                        if ($kbjob.Warning) {
                            $kbjob.Warning | Write-Warning
                        }
                        if ($kbjob.Verbose) {
                            $kbjob.Verbose | Write-Verbose
                        }
                        if ($kbjob.Debug) {
                            $kbjob.Debug | Write-Debug
                        }
                        if ($kbjob.Information) {
                            $kbjob.Information | Write-Information
                        }
                    }
                    $null = Remove-Variable -Name kbjob
                    foreach ($kbjob in ($kbjobs | Where-Object State -ne 'Running')) {
                        Write-PSFMessage -Level Verbose -Message "Finished installing updates on $($kbjob.Name)"
                        $null = $added++
                        $done = $kbjobs | Where-Object Name -ne $kbjob.Name
                        $progressparms = @{
                            Activity        = "Installing updates"
                            Status          = "Still installing updates on $($done.Name -join ', ')"
                            PercentComplete = ($added / $totalsteps * 100)
                        }

                        Write-Progress @progressparms
                        $jorbs | Where-Object Name -eq $kbjob.name
                        $kbjob | Remove-Job
                    }
                    Start-Sleep -Seconds 1
                }
                Write-Progress -Activity "Installing updates" -Completed
            } catch {
                Stop-PSFFunction -Message "Failure on $hostname" -ErrorRecord $PSItem -EnableException:$EnableException
            }
        }
    }
}