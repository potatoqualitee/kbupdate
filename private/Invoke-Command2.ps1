function Invoke-Command2 {
    [cmdletbinding()]
    param(
        [string]$ComputerName,
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        [object[]]$ArgumentList,
        [PSCredential]$Credential,
        [switch]$HideComputerName,
        [int]$ThrottleLimit = 32,
        [switch]$EnableException
    )
    if (-not (Get-Module PSFramework)) {
        Import-Module PSFramework 4>$null
    }

    if ($EnableException) {
        $PSDefaultParameterValues["*:EnableException"] = $true
    } else {
        $PSDefaultParameterValues["*:EnableException"] = $false
    }

    $computer = [PSFComputer]$ComputerName
    if (-not $computer.IsLocalhost) {
        Write-PSFMessage -Level Verbose -Message "Computer is not localhost, adding $ComputerName to PSDefaultParameterValues"
        $PSDefaultParameterValues['Invoke-Command:ComputerName'] = $ComputerName
    }
    if ($Credential) {
        Write-PSFMessage -Level Verbose -Message "Adding Credential to Invoke-Command and Invoke-PSFCommand"
        $PSDefaultParameterValues['Invoke-Command:Credential'] = $Credential
        $PSDefaultParameterValues['Invoke-PSFCommand:Credential'] = $Credential
    }
    if (-not (Get-PSFConfigValue -Name PSRemoting.Sessions.Enable)) {
        Write-PSFMessage -Level Verbose -Message "Sessions disabled, just using Invoke-Command"
        try {
            Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList -ErrorAction Stop
        } catch {
            Stop-PSFFunction -Message "Failed to invoke command on $ComputerName" -ErrorRecord $PSItem
            return
        }
    } else {
        try {
            Write-PSFMessage -Level Verbose -Message "Sessions enabled, using Invoke-PSFCommand"
            $null = Get-PSSession | Where-Object { $PSItem.Name -eq "kbupdate-$ComputerName" -and $PSItem.State -eq "Broken" } | Remove-PSSession
            $session = Get-PSSession | Where-Object Name -eq "kbupdate-$ComputerName"

            if ($session.State -eq "Disconnected") {
                Write-PSFMessage -Level Verbose -Message "Session is disconnected, reconnecting"
                $null = $session | Connect-PSSession -ErrorAction Stop
            }

            if (-not $session) {
                Write-PSFMessage -Level Verbose -Message "Creating session objects"
                $sessionoptions = @{
                    IncludePortInSPN    = Get-PSFConfigValue -FullName PSRemoting.PsSessionOption.IncludePortInSPN
                    SkipCACheck         = Get-PSFConfigValue -FullName PSRemoting.PsSessionOption.SkipCACheck
                    SkipCNCheck         = Get-PSFConfigValue -FullName PSRemoting.PsSessionOption.SkipCNCheck
                    SkipRevocationCheck = Get-PSFConfigValue -FullName PSRemoting.PsSessionOption.SkipRevocationCheck
                }
                $sessionOption = New-PSSessionOption @sessionoptions

                $sessionparm = @{
                    ComputerName  = $ComputerName
                    Name          = "kbupdate-$ComputerName"
                    SessionOption = $sessionOption
                    ErrorAction   = "Stop"
                }
                if (Get-PSFConfigValue -FullName PSRemoting.PsSession.UseSSL) {
                    $null = $sessionparm.Add("UseSSL", (Get-PSFConfigValue -FullName PSRemoting.PsSession.UseSSL))
                }
                if (Get-PSFConfigValue -FullName PSRemoting.PsSession.Port) {
                    $null = $sessionparm.Add("Port", (Get-PSFConfigValue -FullName PSRemoting.PsSession.Port))
                }

                Write-PSFMessage -Level Verbose -Message "Creating new session"
                $session = New-PSSession @sessionparm
            }
            Write-PSFMessage -Level Verbose -Message "Connecting to session using Invoke-PSFCommand"
            Invoke-PSFCommand -ComputerName $session -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
        } catch {
            Stop-PSFFunction -Message "Failed to invoke command against $ComputerName" -ErrorRecord $PSItem
            return
        }
    }
}