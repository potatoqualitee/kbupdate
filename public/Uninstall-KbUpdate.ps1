function Uninstall-KbUpdate {
    param (
        $ComputerName,
        $HotfixId,
        $HotFixPath
    )

    $hotfix = @{
        Name       = 'xHotFix'
        ModuleName = 'xWindowsUpdate'
        Property   = @{
            Id     = $hotfixId
            Path   = $hotfixPath
            Ensure = 'Absent'
        }

    ## uninstall bad param using the KB number, works when using \uninstall \\dscsvr1\Patches\windows10.0-kb4486553-x64_0c3111b07c3e2a33d66fed4a66c67dec989950a0.msu
        ## change xWindowsUpdate?
    ## install works - throws error after set - because of reboot?
    }
    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        param (
            $hotfix
        )
        write-host ("Uninstalling {0} from {1}" -f $hotfix.property.id, $hotfix.property.path)
        if (-not (Invoke-DscResource @hotfix -Method Test -verbose)) {
            Invoke-DscResource @hotfix -Method Set -verbose
        }
    } -ArgumentList $hotfix

}

## xHotFix resource needs to be available on target machine - could we look for it and ship it out if it's needed?
## xHotFix has a log parameter - perhaps could read that back in for output
