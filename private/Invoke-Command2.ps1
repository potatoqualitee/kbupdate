function Invoke-Command2 {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
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
    $computer = [PSFComputer]$ComputerName

    Write-PSFMessage -Level Verbose -Message "Adding ErrorActon Stop to Invoke-Command and Invoke-PSFCommand"
    $PSDefaultParameterValues['Invoke-Command:ErrorAction'] = "Stop"
    $PSDefaultParameterValues['Invoke-PSFCommand:ErrorAction'] = "Stop"

    if ($EnableException) {
        $PSDefaultParameterValues['*:EnableException'] = $true
    } else {
        $PSDefaultParameterValues['*:EnableException'] = $false
    }
    if (-not $computer.IsLocalhost) {
        Write-PSFMessage -Level Verbose -Message "Computer is not localhost, adding $ComputerName to PSDefaultParameterValues"
        $PSDefaultParameterValues['Invoke-Command:ComputerName'] = $ComputerName
    }
    if ($Credential) {
        Write-PSFMessage -Level Verbose -Message "Adding Credential to Invoke-Command and Invoke-PSFCommand"
        $PSDefaultParameterValues['Invoke-Command:Credential'] = $Credential
        $PSDefaultParameterValues['Invoke-PSFCommand:Credential'] = $Credential
    }

    try {
        if (-not (Get-PSFConfigValue -Name PSRemoting.Sessions.Enable) -or $computer.IsLocalhost) {
            Write-PSFMessage -Level Verbose -Message "Sessions disabled, just using Invoke-Command"
            Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
        } else {
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
        }
    } catch {
        Stop-PSFFunction -Message "Failure on $ComputerName" -ErrorRecord $PSItem
    }
}