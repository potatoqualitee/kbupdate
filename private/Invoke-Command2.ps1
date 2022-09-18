function Invoke-Command2 {
    [cmdletbinding()]
    param(
        [psobject]$ComputerName,
        [PSCredential]$Credential,
        [scriptblock]$ScriptBlock,
        [string[]]$ArgumentList
    )

    if (-not (Get-PSFConfigValue -Name PSRemoting.Sessions.Enable)) {
        if ($Credential) {
            Invoke-Command -ComputerName "$ComputerName" -Credential $Credential -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList

        } else {
            Invoke-Command -ComputerName "$ComputerName" -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
        }
    } else {
        $null = Get-PSSession | Where-Object { $PSItem.Name -eq "kbupdate-$ComputerName" -and $PSItem.State -eq "Broken" } | Remove-PSSession
        $session = Get-PSSession | Where-Object Name -eq "kbupdate-$ComputerName"

        if ($session.State -eq "Disconnected") {
            $null = $session | Connect-PSSession -ErrorAction Stop
        }

        if (-not $session) {
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
            if ($Credential) {
                $null = $sessionparm.Add("Credential", $Credential)
            }
            if (Get-PSFConfigValue -FullName PSRemoting.PsSession.UseSSL) {
                $null = $sessionparm.Add("UseSSL", (Get-PSFConfigValue -FullName PSRemoting.PsSession.UseSSL))
            }
            if (Get-PSFConfigValue -FullName PSRemoting.PsSession.Port) {
                $null = $sessionparm.Add("Port", (Get-PSFConfigValue -FullName PSRemoting.PsSession.Port))
            }
            $session = New-PSSession @sessionparm
        }
        Invoke-PSFCommand -ComputerName $session -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
    }
}