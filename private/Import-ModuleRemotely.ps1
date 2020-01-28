# thanks https://stackoverflow.com/a/36716601/2610398
function Import-ModuleRemotely {
    param (
        [string]$ModuleName = "xWindowsUpdate",
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    begin {
        function Exports ([string] $paramName, $dictionary) {
            if ($dictionary.Keys.Count -gt 0) {
                $keys = $dictionary.Keys -join ","
                return " -$paramName $keys"
            }
        }
    }
    process {
        Import-Module "$script:ModuleRoot\library\xWindowsUpdate\DscResources\MSFT_xMicrosoftUpdate\MSFT_xMicrosoftUpdate.psm1" -Force
        Import-Module "$script:ModuleRoot\library\xWindowsUpdate\xWindowsUpdate.psd1" -Force
        $localmodule = Get-Module $ModuleName

        $fns = Exports "Function" $localmodule.ExportedFunctions
        $aliases = Exports "Alias" $localmodule.ExportedAliases
        $cmdlets = Exports "Cmdlet" $localmodule.ExportedCmdlets
        $vars = Exports "Variable" $localmodule.ExportedVariables
        $dscs = @{ "DscResource" = $localmodule.ExportedDscResources }
        $exports = "Export-ModuleMember $fns $aliases $cmdlets $vars $dscs"

        $scriptblock = {
            param (
                $ModuleName,
                $localmodule,
                $exports,
                $VerbosePreference
            )
            Remove-Module -Name $ModuleName -ErrorAction SilentlyContinue
            New-Module -Name $ModuleName -ScriptBlock {
                param (
                    $localmodule,
                    $exports,
                    $VerbosePreference
                )
                $localmodule.Definition
                $exports
            } -ArgumentList $localmodule, $exports, $VerbosePreference | Import-Module
            (Get-Module $ModuleName).ExportedDscResources
        }
        Invoke-Command -Session $Session -ScriptBlock $scriptblock -ArgumentList $ModuleName, $localmodule, $exports, $VerbosePreference
    }
}