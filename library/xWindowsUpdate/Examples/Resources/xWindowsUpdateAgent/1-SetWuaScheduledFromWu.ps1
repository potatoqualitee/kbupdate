<#
    .EXAMPLE
    Sets the Windows Update Agent to use the Windows Update service and sets
    the notifications to scheduled install.  Does not install updates during
    the configuration.
#>

Configuration Example
{
    Import-DscResource -ModuleName xWindowsUpdate
    
    xWindowsUpdateAgent MuSecurityImportant
    {
        IsSingleInstance = 'Yes'
        UpdateNow        = $false
        Source           = 'WindowsUpdate'
        Notifications    = 'ScheduledInstallation'
    }
}
