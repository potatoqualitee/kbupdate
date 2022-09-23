function Get-KbInstalledSoftware {
    <#
    .SYNOPSIS
        Tries its darndest to return all of the software installed on a system.

    .DESCRIPTION
        Tries its darndest to return all of the software installed on a system. It's intended to be a replacement for Get-Hotfix, Get-Package, Windows Update results and searching CIM for install updates and programs.

    .PARAMETER Pattern
        Any pattern. But really, a KB pattern is your best bet.

    .PARAMETER ComputerName
        Used to connect to a remote host

    .PARAMETER Credential
        The optional alternative credential to be used when connecting to ComputerName

    .PARAMETER IncludeHidden
        Include KBs that are hidden due to misconfiguration.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Author: Chrissy LeMaire (@cl), netnerds.net
        Copyright: (c) licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .EXAMPLE
        PS C:\> Get-KbInstalledSoftware

        Gets all the updates installed on the local machine

    .EXAMPLE
        PS C:\> Get-KbInstalledSoftware -ComputerName server01

        Gets all the updates installed on server01

    .EXAMPLE
        PS C:\> Get-KbInstalledSoftware -ComputerName server01 -Pattern KB4057119

        Gets all the updates installed on server01 that match KB4057119

    .EXAMPLE
        PS C:\> Get-KbInstalledSoftware -ComputerName server01 -Pattern KB4057119 | Select -ExpandProperty InstallFile

        Shows alls of the install files for KB4057119 on server01. InstallFile is hidden by default because it has a lot of information.
#>
    [CmdletBinding()]
    param(
        [PSFComputer[]]$ComputerName = $env:COMPUTERNAME,
        [pscredential]$Credential,
        [Alias("Name", "HotfixId", "KBUpdate", "Id")]
        [string[]]$Pattern,
        [switch]$IncludeHidden,
        [switch]$EnableException
    )
    begin {
        $swblock = (Get-Command Get-Software).Definition | ConvertTo-Json -Depth 3 -Compress
    }
    process {
        if ($IsLinux -or $IsMacOs) {
            Stop-PSFFunction -Message "This command using remoting and only supports Windows at this time" -EnableException:$EnableException
            return
        }

        try {
            if ($ComputerName.Count -eq 1) {
                Write-PSFMessage -Level Verbose -Message "Executing command on $computer"
                $computer = $ComputerName | Select-Object -First 1
                $scriptblock = [scriptblock]::Create($((Get-Command Get-Software).Definition))
                Invoke-KbCommand -ComputerName $computer -Credential $Credential -ErrorAction Stop -ScriptBlock $scriptblock -ArgumentList @($Pattern), $IncludeHidden, $VerbosePreference | Sort-Object -Property Name |
                    Select-Object -Property * -ExcludeProperty PSComputerName, RunspaceId | Select-DefaultView -ExcludeProperty InstallFile
            } else {
                $jobs = @()
                foreach ($computer in $ComputerName) {
                    Write-PSFMessage -Level Verbose -Message "Adding job for $computer"
                    $arglist = [pscustomobject]@{
                        ComputerName = $computer
                        Credential   = $Credential
                        ScriptBlock  = $swblock
                        ArgumentList = (@($Pattern), $IncludeHidden, $VerbosePreference)
                        ModulePath   = (Join-Path -Path $script:ModuleRoot -ChildPath kbupdate.psm1)
                    }

                    $invokeblock = {
                        Import-Module $args.ModulePath
                        $sbjson = $args.ScriptBlock | ConvertFrom-Json
                        $sb = [scriptblock]::Create($sbjson)
                        $parms = @{
                            ComputerName = $args.ComputerName
                            Credential   = $args.Credential
                            ScriptBlock  = $sb
                            ArgumentList = $args.ArgumentList
                        }
                        Invoke-KbCommand @parms -ErrorAction Stop
                    }
                    $jobs += Start-Job -Name $computer -ScriptBlock $invokeblock -ArgumentList $arglist -ErrorAction Stop
                }
            }

            if ($jobs.Name) {
                try {
                    $jobs | Start-JobProcess -Activity "Getting installed software" -Status "getting installed software" | Select-Object -Property * -ExcludeProperty PSComputerName, RunspaceId | Select-DefaultView -ExcludeProperty InstallFile
                } catch {
                    Stop-PSFFunction -Message "Failure" -ErrorRecord $PSItem -EnableException:$EnableException -Continue
                }
            }
        } catch {
            Stop-PSFFunction -EnableException:$EnableException -Message "Failure" -ErrorRecord $_ -Continue
        }
    }
}