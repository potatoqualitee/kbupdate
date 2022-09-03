$modulePath = Split-Path -Path $PSScriptRoot -Parent

# Import the shared modules
Import-Module -Name (Join-Path -Path $modulePath `
    -ChildPath (Join-Path -Path 'xPSDesiredStateConfiguration.Common' `
        -ChildPath 'xPSDesiredStateConfiguration.Common.psm1'))

Import-Module -Name (Join-Path -Path $modulePath -ChildPath 'DscResource.Common')

# Import Localization Strings
$script:localizedData = Get-LocalizedData -DefaultUICulture 'en-US'

# Best Practice Security Settings Block
$insecureProtocols = @("SSL 2.0", "SSL 3.0", "TLS 1.0", "PCT 1.0", "Multi-Protocol Unified Hello")
$secureProtocols = @("TLS 1.1", "TLS 1.2")

<#
    This list corresponds to the ValueMap definition of DisableSecurityBestPractices
    parameter defined in MSFT_xDSCWebService.Schema.mof
#>
$SecureTLSProtocols = 'SecureTLSProtocols'

<#
    .SYNOPSIS
        This function tests if the SChannel protocols are enabled.
#>
function Test-SChannelProtocol
{
    [CmdletBinding()]
    param ()

    foreach ($protocol in $insecureProtocols)
    {
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$protocol\Server"

        if ((Test-Path -Path $registryPath) `
                -and ($null -ne (Get-ItemProperty -Path $registryPath)) `
                -and ((Get-ItemProperty -Path $registryPath).Enabled -ne 0))
        {
            return $false
        }
    }

    foreach ($protocol in $secureProtocols)
    {
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$protocol\Server"

        if ((-not (Test-Path -Path $registryPath)) `
                -or ($null -eq (Get-ItemProperty -Path $registryPath)) `
                -or ((Get-ItemProperty -Path $registryPath).Enabled -eq 0))
        {
            return $false
        }
    }

    return $true
}

<#
    .SYNOPSIS
        This function enables the SChannel protocols.
#>
function Set-SChannelProtocol
{
    [CmdletBinding()]
    param ()

    foreach ($protocol in $insecureProtocols)
    {
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$protocol\Server"
        $null = New-Item -Path $registryPath -Force
        $null = New-ItemProperty -Path $registryPath -Name Enabled -Value 0 -PropertyType 'DWord' -Force
    }

    foreach ($protocol in $secureProtocols)
    {
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$protocol\Server"
        $null = New-Item -Path $registryPath -Force
        $null = New-ItemProperty -Path $registryPath -Name Enabled -Value '0xffffffff' -PropertyType 'DWord' -Force
        $null = New-ItemProperty -Path $registryPath -Name DisabledByDefault -Value 0 -PropertyType 'DWord' -Force
    }
}

<#
    .SYNOPSIS
        This function tests whether the node uses security best practices for non-disabled items
#>
function Test-UseSecurityBestPractice
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter()]
        [System.String[]]
        $DisableSecurityBestPractices
    )

    $usedProtocolsBestPractices = ($DisableSecurityBestPractices -icontains $SecureTLSProtocols) -or (Test-SChannelProtocol)

    return $usedProtocolsBestPractices
}

<#
    .SYNOPSIS
        This function sets the node to use security best practices for non-disabled items
#>
function Set-UseSecurityBestPractice
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.String[]]
        $DisableSecurityBestPractices
    )

    if (-not ($DisableSecurityBestPractices -icontains $SecureTLSProtocols))
    {
        Set-SChannelProtocol
    }
}
