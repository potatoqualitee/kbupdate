function Install-KbUpdate {
    param (
        $ComputerName,
        $HotfixId,
        $HotFixPath#,
        #$cred = (get-credential)
    )

    $hotfix = @{
        Name       = 'xHotFix'
        ModuleName = 'xWindowsUpdate'
        Property   = @{
            Id     = $hotfixId
            Path   = $hotfixPath
            Ensure = 'Present'
            #PSDscRunAsCredential = $cred -- this would mean it doesn't run as system on the target node
        }

    }
    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        param (
            $hotfix
        )
        write-host ("Installing {0} from {1}" -f $hotfix.property.id, $hotfix.property.path)
        if (-not (Invoke-DscResource @hotfix -Method Test -verbose)) {
            Invoke-DscResource @hotfix -Method Set -verbose
            write-host 'done'
        }
    } -ArgumentList $hotfix


}

## xHotFix resource needs to be available on target machine - could we look for it and ship it out if it's needed?
## could also use xPendingReboot to look for pending reboots and handle?

<#
Error - installs the hotfix successfully then :

Serialized XML is nested too deeply. Line 1, position 3507.
    + CategoryInfo          : OperationStopped: (dscsvr2:String) [], PSRemotingTransportException
    + FullyQualifiedErrorId : JobFailure
    + PSComputerName        : dscsvr2

#>