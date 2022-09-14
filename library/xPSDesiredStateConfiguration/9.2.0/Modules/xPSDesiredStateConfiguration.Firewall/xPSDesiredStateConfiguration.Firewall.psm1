$modulePath = Split-Path -Path $PSScriptRoot -Parent

# Import the shared modules
Import-Module -Name (Join-Path -Path $modulePath `
    -ChildPath (Join-Path -Path 'xPSDesiredStateConfiguration.Common' `
        -ChildPath 'xPSDesiredStateConfiguration.Common.psm1'))

Import-Module -Name (Join-Path -Path $modulePath -ChildPath 'DscResource.Common')

# Import Localization Strings
$script:localizedData = Get-LocalizedData -DefaultUICulture 'en-US'

New-Variable -Name FireWallRuleDisplayName -Value 'DSCPullServer_IIS_Port' -Option ReadOnly -Scope Script -Force
New-Variable -Name netsh -Value "$env:windir\system32\netsh.exe" -Option ReadOnly -Scope Script -Force

<#
    .SYNOPSIS
        Create a firewall exception so that DSC clients are able to access the configured Pull Server
    .PARAMETER Port
        The TCP port used to create the firewall exception
#>
function Add-PullServerFirewallConfiguration
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateRange(1, 65535)]
        [System.UInt32]
        $Port
    )

    Write-Verbose -Message 'Disable Inbound Firewall Notification'
    $null = & $script:netsh advfirewall set currentprofile settings inboundusernotification disable

    $ruleName = $FireWallRuleDisplayName

    # Remove all existing rules with that displayName
    $null = & $script:netsh advfirewall firewall delete rule name=$ruleName protocol=tcp localport=$Port

    Write-Verbose -Message "Add Firewall Rule for port $Port"
    $null = & $script:netsh advfirewall firewall add rule name=$ruleName dir=in action=allow protocol=TCP localport=$Port
}

<#
    .SYNOPSIS
        Delete the Pull Server firewall exception
    .PARAMETER Port
        The TCP port for which the firewall exception should be deleted
#>
function Remove-PullServerFirewallConfiguration
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateRange(1, 65535)]
        [System.UInt32]
        $Port
    )

    if (Test-PullServerFirewallConfiguration -Port $Port)
    {
        # remove all existing rules with that displayName
        Write-Verbose -Message "Delete Firewall Rule for port $Port"
        $ruleName = $FireWallRuleDisplayName

        # backwards compatibility with old code
        if (Get-Command -Name Get-NetFirewallRule -CommandType Cmdlet -ErrorAction:SilentlyContinue)
        {
            # Remove all rules with that name
            Get-NetFirewallRule -DisplayName $ruleName | Remove-NetFirewallRule
        }
        else
        {
            $null = & $script:netsh advfirewall firewall delete rule name=$ruleName protocol=tcp localport=$Port
        }
    }
    else
    {
        Write-Verbose -Message "No DSC PullServer firewall rule found with port $Port. No cleanup required"
    }
}

<#
    .SYNOPSIS
        Tests if a Pull Server firewall exception exists for a specific port
    .PARAMETER Port
        The TCP port for which the firewall exception should be tested
#>
function Test-PullServerFirewallConfiguration
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter()]
        [ValidateRange(1, 65535)]
        [System.UInt32]
        $Port
    )

    # Remove all existing rules with that displayName
    Write-Verbose -Message "Testing Firewall Rule for port $Port"
    $ruleName = $FireWallRuleDisplayName
    $result = & $script:netsh advfirewall firewall show rule name=$ruleName | Select-String -Pattern "LocalPort:\s*$Port"
    return -not [string]::IsNullOrWhiteSpace($result)
}
