# xWindowsUpdate Module

master: [![Build status](https://ci.appveyor.com/api/projects/status/t4bw4lnmxy1dg3ys/branch/master?svg=true)](https://ci.appveyor.com/project/PowerShell/xwindowsupdate/branch/master)
[![codecov](https://codecov.io/gh/PowerShell/xWindowsUpdate/branch/master/graph/badge.svg)](https://codecov.io/gh/PowerShell/xWindowsUpdate)

dev: [![Build status](https://ci.appveyor.com/api/projects/status/t4bw4lnmxy1dg3ys/branch/dev?svg=true)](https://ci.appveyor.com/project/PowerShell/xwindowsupdate/branch/dev)
[![codecov](https://codecov.io/gh/PowerShell/xWindowsUpdate/branch/dev/graph/badge.svg)](https://codecov.io/gh/PowerShell/xWindowsUpdate)

The **xWindowsUpdate** module contains the **xHotfix** and
**xWindowsUpdateAgent** DSC resources.  **xHotfix** installs a
Windows Update (or hotfix) from a given path.
**xWindowsUpdateAgent** will configure the source download settings for the machine,
update notifications on the system, and can automatically initiate installation of the updates.
For more information on Windows Update and Hotfix, please refer to
[this TechNet article](http://technet.microsoft.com/en-us/library/cc750077.aspx).
**xMicrosoftUpdate** enables or disables Microsoft Update.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/)
or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any
additional questions or comments.

## Contributing

Please check out common DSC Resources
[contributing guidelines](https://github.com/PowerShell/DscResource.Kit/blob/master/CONTRIBUTING.md).

## Resources

### xHotfix

* **Path**: The path from where the hotfix should be installed
* **Log**: The name of the log where installation/uninstallation details
    are stored.
    If no log is used, a temporary log name is created by the resource.
* **Id**: The hotfix ID of the Windows update that uniquely identifies
    the hotfix.
* **Ensure**: Ensures that the hotfix is **Present** or **Absent**.

### xWindowsUpdateAgent

* **UpdateNow**: Indicates if the resource should trigger an update during
    consistency (including initial.)
* **Category**: Indicates the categories (one or more) of updates the resource
    should update for.  'Security', 'Important', 'Optional'.
    Default: 'Security' (please note that security is not mutually
    exclusive with Important and Optional, so selecting Important may
    install some security updates, etc.)
* **Notifications**: Sets the windows update agent notification setting.
    Supported options are 'disabled' and 'ScheduledInstallation'.
    [Documentation from Windows Update](https://msdn.microsoft.com/en-us/library/windows/desktop/aa385806%28v=vs.85%29.aspx?f=255&MSPPError=-2147217396)
* **Source**: Sets the service windows update agent will use for searching
    for updates.  Supported options are 'MicrosoftUpdate' and 'WindowsUpdate'.
    Note 'WSUS' is currently reserver for future use.
* **IsSingleInstance**: Should always be yes.  Ensures you can only have
    one instance of this resource in a configuration.

### xMicrosoftUpdate

**Note:** `xMicrosoftUpdate` is deprecated.  Please use `xWindowsUpdateAgent`.

* **Ensure**: Determines whether the Microsoft Update service should be
    enabled (ensure) or disabled (absent) in Windows Update.

## Versions

### Unreleased

### 2.8.0.0

* xWindowsUpdateAgent: Fixed verbose statement returning incorrect variable
* Tests no longer fail on `Assert-VerifiableMocks`, these are now renamed
  to `Assert-VerifiableMock` (breaking change in Pester v4).
* README.md has been updated with correct description of the resources
  ([issue #58](https://github.com/PowerShell/xWindowsUpdate/issues/58)).
* Updated appveyor.yml to use the correct parameters to call the test framework.
* Update appveyor.yml to use the default template.
* Added default template files .gitattributes, and .gitignore, and
  .vscode folder.

### 2.7.0.0

* xWindowsUpdateAgent: Fix Get-TargetResource returning incorrect key

### 2.6.0.0

* Converted appveyor.yml to install Pester from PSGallery instead of from
    Chocolatey.
* Fixed PSScriptAnalyzer issues.
* Fixed common test breaks (markdown style, and example style).
* Added CodeCov.io reporting
* Deprecated xMicrosoftUpdate as it's functionality is replaced by xWindowsUpdateAgent

### 2.5.0.0

* Added xWindowsUpdateAgent

### 2.4.0.0

* Fixed PSScriptAnalyzer error in examples

### 2.3.0.0

* MSFT_xWindowsUpdate: Fixed an issue in the Get-TargetResource function,
    resulting in the Get-DscConfiguration cmdlet now working appropriately
    when the resource is applied.
* MSFT_xWindowsUpdate: Fixed an issue in the Set-TargetResource function
    that was causing the function to fail when the installation of a hotfix
    did not provide an exit code.

### 2.2.0.0

* Minor fixes

### 2.1.0.0

* Added xMicrosoftUpdate DSC resource which can be used to enable/disable
    Microsoft Update in the Windows Update Settings.

### 1.0.0.0

* Initial release with the xHotfix resource

## Examples

### xHotfix Examples 1

This configuration will install the hotfix from the .msu file given.
If the hotfix with the required hotfix ID is already present on the system,
the installation is skipped.

```powershell
Configuration UpdateWindowsWithPath
{
    Node 'NodeName'
    {
        xHotfix HotfixInstall
        {
            Ensure = "Present"
            Path = "c:/temp/Windows8.1-KB2908279-v2-x86.msu"
            Id = "KB2908279"
        }
    }
}
```

### Installs a hotfix from a given URI

This configuration will install the hotfix from a URI that is connected to
a particular hotfix ID.

```powershell
Configuration UpdateWindowsWithURI
{
    Node 'NodeName'
    {
        xHotfix HotfixInstall
        {
            Ensure = "Present"
            Path = "http://hotfixv4.microsoft.com/Microsoft%20Office%20SharePoint%20Server%202007/sp2/officekb956056fullfilex64glb/12.0000.6327.5000/free/358323_intl_x64_zip.exe"
            Id = "KB2937982"
        }
    }
}
```

### Enable Microsoft Update

This configuration will enable the Microsoft Update Settings (checkbox) in
the Windows Update settings

```powershell
Configuration MSUpdate
{
    Import-DscResource -Module xWindowsUpdate
    xMicrosoftUpdate "EnableMSUpdate"
    {
        Ensure = "Present"
    }
}
```

### xWindowsUpdateAgent Sample 1

Set Windows Update Agent to use Microsoft Update.  Disables notification of
future updates.  Install all Security and Important updates from Microsoft
Update during the configuration using `UpdateNow = $true`.

```PowerShell
Configuration MuSecurityImportant
{
    Import-DscResource -ModuleName xWindowsUpdate
    xWindowsUpdateAgent MuSecurityImportant
    {
        IsSingleInstance = 'Yes'
        UpdateNow        = $true
        Category         = @('Security','Important')
        Source           = 'MicrosoftUpdate'
        Notifications    = 'Disabled'
    }
}
```

### xWindowsUpdateAgent Sample 2

Sets the Windows Update Agent to use the Windows Update service
(vs Microsoft Update or WSUS) and sets the notifications to scheduled install
(no notifications, just automatically install the updates.)  Does not install
updates during the configuration `UpdateNow = $false`.

```PowerShell
Configuration WuScheduleInstall
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
```
