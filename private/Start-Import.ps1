$script:imports = @{}

function Start-Import {
    [CmdletBinding()]
    param (
        [scriptblock]$ScriptBlock
    )
    begin {
        if (-not $script:linkhash) {
            write-warning Start-Import
            $script:linkhash = [hashtable]::Synchronized(@{})
            $script:superbyhash = [hashtable]::Synchronized(@{})
            $script:superhash = [hashtable]::Synchronized(@{})
            $script:runspaces = @()

            $script:pool = [RunspaceFactory]::CreateRunspacePool(1, [int]$env:NUMBER_OF_PROCESSORS + 1)
            $pool.ApartmentState = "MTA"
            $pool.Open()

            $script:runspace = [runspacefactory]::CreateRunspace()
            $runspace.Open()
            $runspace.SessionStateProxy.SetVariable("linkhash", $script:linkhash)
            $runspace.SessionStateProxy.SetVariable("basedb", $script:basedb)
            $runspace.SessionStateProxy.SetVariable("superbyhash", $script:superbyhash)
            $runspace.SessionStateProxy.SetVariable("superhash", $script:superhash)
        }
    } process {
        $powershell = [powershell]::Create()
        #$powershell.RunspacePool = $pool
        $powershell.Runspace = $runspace
        $null = $powershell.AddScript($ScriptBlock)

        $script:runspaces += [PSCustomObject]@{
            Pipe   = $powershell
            Status = $powershell.BeginInvoke()
        }
    } end {

    }
}