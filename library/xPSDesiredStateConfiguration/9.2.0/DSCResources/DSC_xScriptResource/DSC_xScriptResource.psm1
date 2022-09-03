$errorActionPreference = 'Stop'
Set-StrictMode -Version 'Latest'

$modulePath = Join-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -ChildPath 'Modules'

# Import the shared modules
Import-Module -Name (Join-Path -Path $modulePath `
    -ChildPath (Join-Path -Path 'xPSDesiredStateConfiguration.Common' `
        -ChildPath 'xPSDesiredStateConfiguration.Common.psm1'))

Import-Module -Name (Join-Path -Path $modulePath -ChildPath 'DscResource.Common')

# Import Localization Strings
$script:localizedData = Get-LocalizedData -DefaultUICulture 'en-US'

<#
    .SYNOPSIS
        Runs the given get script.

    .PARAMETER GetScript
        A string that can be used to create a PowerShell script block that retrieves
        the current state of the resource. This script block runs when the
        Get-DscConfiguration cmdlet is called. This script block should return a
        hash table containing one key named Result with a string value.

    .PARAMETER SetScript
        Not used in Get-TargetResource.

    .PARAMETER TestScript
        Not used in Get-TargetResource.

    .PARAMETER Credential
        The credential of the user account to run the script under if needed.

    .OUTPUTS
        Returns a hash table.
#>
function Get-TargetResource
{
    [OutputType([System.Collections.Hashtable])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $GetScript,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $SetScript,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $TestScript,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential
    )

    Write-Verbose -Message $script:localizedData.GetTargetResourceStartVerboseMessage

    $invokeScriptParameters = @{
        ScriptBlock = [System.Management.Automation.ScriptBlock]::Create($GetScript)
    }

    if ($PSBoundParameters.ContainsKey('Credential'))
    {
        $invokeScriptParameters['Credential'] = $Credential
    }

    $invokeScriptResult = Invoke-Script @invokeScriptParameters

    if ($invokeScriptResult -is [System.Management.Automation.ErrorRecord])
    {
        New-InvalidOperationException -Message $script:localizedData.GetScriptThrewError -ErrorRecord $invokeScriptResult
    }

    $invokeScriptResultAsHashTable = $invokeScriptResult -as [System.Collections.Hashtable]

    if ($null -eq $invokeScriptResultAsHashTable)
    {
        New-InvalidArgumentException -ArgumentName 'TestScript' -Message $script:localizedData.GetScriptDidNotReturnHashtable
    }

    Write-Verbose -Message $script:localizedData.GetTargetResourceEndVerboseMessage

    return $invokeScriptResultAsHashTable
}

<#
    .SYNOPSIS
        Runs the given set script.

    .PARAMETER GetScript
        Not used in Set-TargetResource.

    .PARAMETER SetScript
        A string that can be used to create a PowerShell script block that sets the
        resource to the desired state. This script block runs conditionally when the
        Start-DscConfiguration cmdlet is called. The TestScript script block will run
        first. If the TestScript block returns False, this script block will run. If
        the TestScript block returns True, this script block will not run. This
        script block should not return.

    .PARAMETER TestScript
        Not used in Set-TargetResource.

    .PARAMETER Credential
        The credential of the user account to run the script under if needed.

    .OUTPUTS
        None.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $GetScript,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $SetScript,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $TestScript,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential
    )

    Write-Verbose -Message $script:localizedData.SetTargetResourceStartVerboseMessage

    $invokeScriptParameters = @{
        ScriptBlock = [System.Management.Automation.ScriptBlock]::Create($SetScript)
    }

    if ($PSBoundParameters.ContainsKey('Credential'))
    {
        $invokeScriptParameters['Credential'] = $Credential
    }

    $invokeScriptResult = Invoke-Script @invokeScriptParameters

    if ($invokeScriptResult -is [System.Management.Automation.ErrorRecord])
    {
        New-InvalidOperationException -Message $script:localizedData.SetScriptThrewError -ErrorRecord $invokeScriptResult
    }

    Write-Verbose -Message $script:localizedData.SetTargetResourceEndVerboseMessage
}

<#
    .SYNOPSIS
        Runs the given test script.

    .PARAMETER GetScript
        Not used in Test-TargetResource.

    .PARAMETER SetScript
        Not used in Test-TargetResource.

    .PARAMETER TestScript
        A string that can be used to create a PowerShell script block that validates whether
        or not the resource is in the desired state. This script block runs when the
        Start-DscConfiguration cmdlet is called or when the Test-DscConfiguration cmdlet is
        called. This script block should return a boolean with True meaning that the resource
        is in the desired state and False meaning that the resource is not in the desired state.

    .PARAMETER Credential
        The credential of the user account to run the script under if needed.

    .OUTPUTS
        Should return true if the resource is in the desired state and false otherwise.
#>
function Test-TargetResource
{
    [OutputType([System.Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $GetScript,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $SetScript,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $TestScript,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential
    )

    Write-Verbose -Message $script:localizedData.TestTargetResourceStartVerboseMessage

    $invokeScriptParameters = @{
        ScriptBlock = [System.Management.Automation.ScriptBlock]::Create($TestScript)
    }

    if ($PSBoundParameters.ContainsKey('Credential'))
    {
        $invokeScriptParameters['Credential'] = $Credential
    }

    $invokeScriptResult = Invoke-Script @invokeScriptParameters

    # If the script is returing multiple objects, then we consider the last object to be the result of the script execution.
    if ($invokeScriptResult -is [System.Object[]] -and $invokeScriptResult.Count -gt 0)
    {
        $invokeScriptResult = $invokeScriptResult[$invokeScriptResult.Count - 1]
    }

    if ($invokeScriptResult -is [System.Management.Automation.ErrorRecord])
    {
        New-InvalidOperationException -Message $script:localizedData.TestScriptThrewError -ErrorRecord $invokeScriptResult
    }

    if ($null -eq $invokeScriptResult -or -not ($invokeScriptResult -is [System.Boolean]))
    {
        New-InvalidArgumentException -ArgumentName 'TestScript' -Message $script:localizedData.TestScriptDidNotReturnBoolean
    }

    Write-Verbose -Message $script:localizedData.TestTargetResourceEndVerboseMessage

    return $invokeScriptResult
}

<#
    .SYNOPSIS
        Invokes the given script block.

        The output of the script will be returned unless the script throws an error.
        If the script throws an error, the ErrorRecord will be returned rather than thrown.

    .PARAMETER ScriptBlock
        The script block to invoke.

    .PARAMETER Credential
        The credential to run the script under if needed.
#>
function Invoke-Script
{
    [OutputType([System.Object])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ScriptBlock]
        $ScriptBlock,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential
    )

    $scriptResult = $null

    try
    {
        Write-Verbose -Message ($script:localizedData.ExecutingScriptMessage -f $ScriptBlock)

        if ($null -ne $Credential)
        {
            $scriptResult = Invoke-Command -ScriptBlock $ScriptBlock -Credential $Credential -ComputerName .
        }
        else
        {
            $scriptResult = & $ScriptBlock
        }
    }
    catch
    {
        # Surfacing the error thrown by the execution of the script
        $scriptResult = $_
    }

    return $scriptResult
}
