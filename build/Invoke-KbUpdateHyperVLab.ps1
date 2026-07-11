<#
.SYNOPSIS
Discovers an available local Hyper-V lab and runs read-only kbupdate integration tests.

.DESCRIPTION
Uses KBUPDATE_LAB_COMPUTERS when set. Otherwise, discovers running local Hyper-V guests, checks DNS and WinRM, and prompts once for an in-memory credential. Only guests that accept the credential are passed to Invoke-KbUpdateIntegration.ps1.

A supplied credential is cached only in KbUpdateLabCredential in the current PowerShell process. It is never serialized. The optional public lab credential is intentionally embedded for the disposable open-source lab. This helper does not expose update installation parameters. Use Invoke-KbUpdateIntegration.ps1 with one explicit target and KB for an authorized mutation test.

.PARAMETER ComputerName
Optional authorized lab computer names. When omitted, uses KBUPDATE_LAB_COMPUTERS or discovers running local Hyper-V guests.

.PARAMETER Credential
Optional lab credential. When omitted, reuses KbUpdateLabCredential from the current PowerShell process or prompts with Get-Credential.

.PARAMETER UsePublicLabCredential
Uses the intentionally public credential for the disposable open-source lab. Do not use this option for any private or production environment.

.PARAMETER ProbeOnly
Returns DNS and WinRM availability without prompting for a credential or running integration tests.

.PARAMETER ScanNeededUpdates
Runs read-only Windows Update Agent needed-update scans on every authenticated guest.

.PARAMETER ScanFilePath
Uses an existing offline scan CAB for needed-update scans. Supplying this parameter also enables ScanNeededUpdates.

.EXAMPLE
./build/Invoke-KbUpdateHyperVLab.ps1 -ProbeOnly

Shows which running Hyper-V guests resolve in DNS and expose WinRM.

.EXAMPLE
./build/Invoke-KbUpdateHyperVLab.ps1 -ScanNeededUpdates

Discovers and authenticates the available lab, then runs catalog, remoting, inventory, and needed-update tests.
#>
[CmdletBinding()]
param(
    [string[]]$ComputerName,
    [pscredential]$Credential,
    [switch]$UsePublicLabCredential,
    [switch]$ProbeOnly,
    [switch]$ScanNeededUpdates,
    [string]$ScanFilePath
)

$ErrorActionPreference = 'Stop'

function Test-KbUpdateTcpPort {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,
        [Parameter(Mandatory)]
        [int]$Port,
        [int]$TimeoutMilliseconds = 750
    )

    $client = New-Object Net.Sockets.TcpClient
    $asyncResult = $null
    try {
        $asyncResult = $client.BeginConnect($ComputerName, $Port, $null, $null)
        if (-not $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMilliseconds, $false)) {
            return $false
        }
        $client.EndConnect($asyncResult)
        return $true
    } catch {
        return $false
    } finally {
        if ($asyncResult -and $asyncResult.AsyncWaitHandle) {
            $asyncResult.AsyncWaitHandle.Close()
        }
        $client.Close()
    }
}

if (-not $ComputerName -and $env:KBUPDATE_LAB_COMPUTERS) {
    $ComputerName = @(
        $env:KBUPDATE_LAB_COMPUTERS -split ',' |
            ForEach-Object { $PSItem.Trim() } |
            Where-Object { $PSItem }
    )
}

if (-not $ComputerName) {
    if (-not (Get-Command -Name Get-VM -ErrorAction Ignore)) {
        throw 'No ComputerName or KBUPDATE_LAB_COMPUTERS was supplied, and the Hyper-V Get-VM command is unavailable.'
    }
    $ComputerName = @(
        Get-VM |
            Where-Object State -eq 'Running' |
            Select-Object -ExpandProperty Name
    )
}

$ComputerName = @($ComputerName | Where-Object { $PSItem } | Sort-Object -Unique)
if (-not $ComputerName) {
    throw 'No authorized lab computers were supplied or discovered.'
}

$probe = foreach ($computer in $ComputerName) {
    $dnsReady = $false
    try {
        $dnsReady = @([Net.Dns]::GetHostAddresses($computer)).Count -gt 0
    } catch {
    }
    $winRmReady = $false
    if ($dnsReady) {
        $winRmReady = Test-KbUpdateTcpPort -ComputerName $computer -Port 5985
    }
    [pscustomobject]@{
        ComputerName = $computer
        DnsReady     = $dnsReady
        WinRMReady   = $winRmReady
    }
}

if ($ProbeOnly) {
    $probe
    return
}

$candidates = @($probe | Where-Object { $PSItem.DnsReady -and $PSItem.WinRMReady })
if (-not $candidates) {
    throw 'No discovered lab computer resolves in DNS and exposes WinRM on port 5985.'
}

if (-not $Credential -and $UsePublicLabCredential) {
    $publicLabPassword = ConvertTo-SecureString 'dbatools.IO' -AsPlainText -Force
    $Credential = New-Object Management.Automation.PSCredential('lab\dba', $publicLabPassword)
}

if (-not $Credential) {
    $cachedCredential = Get-Variable -Name KbUpdateLabCredential -Scope Global -ValueOnly -ErrorAction Ignore
    if ($cachedCredential -is [pscredential]) {
        $Credential = $cachedCredential
    }
}

if (-not $Credential) {
    $credentialParameters = @{
        Message = 'Enter the authorized kbupdate lab credential. It will remain in memory only.'
    }
    if ($env:KBUPDATE_LAB_USERNAME) {
        $credentialParameters.UserName = $env:KBUPDATE_LAB_USERNAME
    }
    $Credential = Get-Credential @credentialParameters
    if (-not $Credential) {
        throw 'A lab credential is required.'
    }
    $global:KbUpdateLabCredential = $Credential
}

$authenticatedComputers = @(
    foreach ($candidate in $candidates) {
        try {
            $null = Test-WSMan -ComputerName $candidate.ComputerName -Credential $Credential -Authentication Negotiate -ErrorAction Stop
            $candidate.ComputerName
        } catch {
            Write-Warning "Skipping $($candidate.ComputerName) because the supplied credential was rejected."
        }
    }
)

if (-not $authenticatedComputers) {
    throw 'No discovered lab computer accepted the supplied credential.'
}

if ($ScanFilePath) {
    $ScanNeededUpdates = $true
}

$integrationParameters = @{
    ComputerName      = $authenticatedComputers
    Credential        = $Credential
    ScanNeededUpdates = $ScanNeededUpdates
}
if ($ScanFilePath) {
    $integrationParameters.ScanFilePath = $ScanFilePath
}

& (Join-Path $PSScriptRoot 'Invoke-KbUpdateIntegration.ps1') @integrationParameters
