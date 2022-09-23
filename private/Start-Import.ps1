$script:imports = @{}

function Start-Import {
    [CmdletBinding()]
    param (
        [string]$Name,
        [scriptblock]$ScriptBlock
    )
    begin {
        if (-not $script:linkhash) {
            Write-PSFMessage -Level Verbose -Message "Creating database hashtables"
            $script:linkhash = [hashtable]::Synchronized(@{})
            $script:superbyhash = [hashtable]::Synchronized(@{})
            $script:superhash = [hashtable]::Synchronized(@{})
            $global:runspaces = @()
            Write-PSFMessage -Level Verbose -Message "Done database hashtables"
        }
    }
    process {
        Write-PSFMessage -Level Verbose -Message "Creating Link process"
        $ps = [PowerShell]::Create()
        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.Name = $Name
        $runspace.Open()
        $runspace.SessionStateProxy.SetVariable("linkhash", $script:linkhash)
        $runspace.SessionStateProxy.SetVariable("basedb", $script:basedb)
        $runspace.SessionStateProxy.SetVariable("superbyhash", $script:superbyhash)
        $runspace.SessionStateProxy.SetVariable("superhash", $script:superhash)
        $ps.Runspace = $runspace
        $null = $ps.AddScript($ScriptBlock)
        $global:runspaces += [PSCustomObject]@{
            Pipe   = $ps
            Status = $ps.BeginInvoke()
        }
    }
}