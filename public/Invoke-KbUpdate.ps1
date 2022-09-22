function Invoke-KbCommand {
    <#
	.SYNOPSIS
        An Invoke-Command and Invoke-PSFCommand wrapper with even more integrated session management.

        This command really isn't intended to run anything for the end-user, I just had to export
        it to make jobs easier.

	.DESCRIPTION
        An Invoke-Command and Invoke-PSFCommand wrapper with even more integrated session management.

        This command really isn't intended to run anything for the end-user, I just had to export
        it to make jobs easier.

	.PARAMETER ComputerName
		The computer(s) to invoke the command on.
		Accepts all kinds of things that legally point at a computer, including DNS names, ADComputer objects, IP Addresses, SQL Server connection strings, CimSessions or PowerShell Sessions.
		It will reuse PSSession objects if specified (and not include them in its session management).

	.PARAMETER ScriptBlock
		The code to execute.

	.PARAMETER ArgumentList
		The arguments to pass into the scriptblock.

	.PARAMETER Credential
		Credentials to use when establishing connections.
		Note: These will be ignored if there already exists an established connection.

	.PARAMETER HideComputerName
		Indicates that this cmdlet omits the computer name of each object from the output display. By default, the name of the computer that generated the object appears in the display.

	.PARAMETER ThrottleLimit
		Specifies the maximum number of concurrent connections that can be established to run this command. If you omit this parameter or enter a value of 0, the default value, 32, is used.

	.EXAMPLE
		PS C:\> Invoke-KbCommand -ScriptBlock $ScriptBlock

		Runs the $scriptblock against the local computer.

	.EXAMPLE
		PS C:\> Invoke-KbCommand -ComputerName sql01, sql02 -ScriptBlock $ScriptBlock

		Runs the $scriptblock against sql01 and sql02
    #>
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
    $PSDefaultParameterValues['*:ErrorAction'] = "Stop"
    $PSDefaultParameterValues['*:ErrorAction'] = "Stop"

    if ($EnableException) {
        $null = $PSDefaultParameterValues.Remove('*:EnableException')
        $PSDefaultParameterValues['*:EnableException'] = $true
    } else {
        $null = $PSDefaultParameterValues.Remove('*:EnableException')
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

            $commandparm = @{
                ComputerName = $session
                ScriptBlock  = $ScriptBlock
                ArgumentList = $ArgumentList
            }

            Invoke-PSFCommand @commandparm
        }
    } catch {
        Stop-PSFFunction -Message "Failure on $ComputerName" -ErrorRecord $PSItem
    }
}