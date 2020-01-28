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
        Import-Module "$script:ModuleRoot\library\xWindowsUpdate"
        $localModule = Get-Module $ModuleName

        $fns = Exports "Function" $localModule.ExportedFunctions
        $aliases = Exports "Alias" $localModule.ExportedAliases
        $cmdlets = Exports "Cmdlet" $localModule.ExportedCmdlets
        $vars = Exports "Variable" $localModule.ExportedVariables
        $exports = "Export-ModuleMember $fns $aliases $cmdlets $vars"

        $scriptblock = {
            New-Module -Name $ModuleName {
                $($localModule.Definition)
                $exports
            } | Import-Module
        }
        Invoke-Command -Session $Session -ScriptBlock $scriptblock
    }
}