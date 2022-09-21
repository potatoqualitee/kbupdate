<img align="left" src=https://user-images.githubusercontent.com/8278033/60797982-97668c00-a170-11e9-8f61-06bd40413c54.png alt="kbupdate logo">

# KB Viewer, Saver, Installer and Uninstaller

kbupdate finds, downloads, installs and uninstalls Windows patches. This toolset can greatly simplify the patching process for organizations that need to install specific patches that were not pushed out by their organization's WSUS server or Windows Update.

kbupdate started as a command-line Windows Update Catalog but can now support a number of patching tasks. It can gather and list what's already installed on a system, it can check if any updates are needed on a system (either from Microsoft Update or from Microsoft's monthly catalog) and as previously mentioned, it can install and uninstall updates, on both local and remote systems.

kbupdate can even install patches on remote systems from centralized repositories and it works on older and new versions of PowerShell. Many commands work on Linux and mac OS too.

## Install

You can install this module using the PowerShell Gallery.

```powershell
Install-Module kbupdate
```

Alternatively, to use the module offline, you can save it to a local directory then copy to usb and transfer to offline machine.

```powershell
Save-Module kbupdate -Path C:\temp\copy_to_usb\
```

## Examples

kbupdate has about 10 commands that help simplify your patching process.

### Get-KbUpdate

This command gets detailed information about KB patches using the web, a local database or WSUS as the source. If the machine running kbupdate has an internet connection, it will default to WSUS and database. If it's entirely offline, it will just use the local database unless `-Source` is used.

```powershell
# Get detailed information about KB4057119. This works for SQL Server or any other KB.
Get-KbUpdate -Name KB4057119

# Get detailed information about KB4057119 and KB4057114 using only the kbupdate-library database as the source.
Get-KbUpdate -Name KB4057119, 4057114 -Source Database

# Faster. Gets, at the very least: Title, Architecture, Language, Hotfix, UpdateId and Link
Get-KbUpdate -Name KB4057119, 4057114 -Simple

# Filter out any patches that have been superseded by other patches in the batch
Get-KbUpdate -Pattern 2416447, 979906 -Latest
```

### Save-KbUpdate

This command will save KB patches with input from itself, Get-KbUpdate and Get-KBNeededUpdate.

```powershell
# Download KB4057119 to the current directory. This works for SQL Server or any other KB.
Save-KbUpdate -Name KB4057119

# Download the selected x64 files from KB4057119 to the current directory.
Get-KbUpdate -Name 3118347 -Simple -Architecture x64 | Out-GridView -Passthru | Save-KbUpdate

# Download KB4057119 and the x64 version of KB4057114 to C:\temp.
Save-KbUpdate -Name KB4057119, 4057114 -Architecture x64 -Path C:\temp

# Download needed patches to the local client
Get-KBNeededUpdate -ComputerName server01 | Save-KbUpdate -Path C:\temp

# Download needed patches to the remote client
Get-KBNeededUpdate -ComputerName server01 | Save-KbUpdate -Path '\\server01\c$\temp'
```

### Install-KbUpdate

This command is awesome! It will install patches on local or remote machines. It will even copy files to the target host if needed to bypass Kerberos issues.

```powershell
# Install KB4534273 from the \\fileshare\sql\ directory on server01
Install-KbUpdate -ComputerName server01 -FilePath \\fileshare\sql\windows10.0-kb4532947-x64_20103b70445e230e5994dc2a89dc639cd5756a66.msu

# Automatically save an update, stores it in Downloads and install it from there
Install-KbUpdate -ComputerName server01 -HotfixId kb4486129
```

When more than one computer is supplied, background jobs will be used to speed up the process. If you use the `-AllNeeded` switch, all needed patches will be installed.

```powershell
# Install all needed updates
Install-KbUpdate -ComputerName localhost, sqlcs, sql01 -AllNeeded

# Install all needed updates
Install-KbUpdate -ComputerName localhost, sqlcs, sql01 -AllNeeded
```

### Get-KbNeededUpdate

Checks the target machines for needed updates.  If Windows Update does not have access to WSUS or Microsoft's update catalog, a [local copy of the catalog](#Save-KbScanFile) can be provided.


```powershell
# Get all the updates needed on the local machine using whatever upstream is set by Windows Update
Get-KbNeededUpdate

# Get all the updates needed on server01 using the locally saved cab file
$scanfile = Save-KbScanFile -Path \\server01\c$\temp
Get-KbNeededUpdate -ComputerName server01 -ScanFilePath $scanfile

# Get all the updates needed on server01, then selecting which ones you want to install, then install it
Get-KbNeededUpdate -ComputerName server01 | Out-GridView -Passthru | Install-KbUpdate
```

### Get-KbInstalledSoftware

Tries its darndest to return all of the software installed on a system. It's intended to be a replacement for Get-Hotfix, Get-Package, Windows Update results and searching CIM for install updates and programs.

```powershell
# Returns all software (updates and programs) installed on a computer
Get-KbInstalledSoftware -ComputerName server01

# Returns all software including updates listsed as hidden
Get-KbInstalledSoftware -ComputerName server01 -IncludeHidden

# Test to see if KB4057119 and get a bunch of info about it on server01
Get-KbInstalledSoftware -ComputerName server01 -Pattern KB4057119
```

### Uninstall-KbUpdate

Quietly uninstalls updates. If the package provides a QuietUninstallString, this command tries its best to figure it out.

```powershell
# Uninstalls KB4498951 from server01
Uninstall-KbUpdate -ComputerName server01 -HotfixId KB4498951

# Uninstalls KB4498951 on server01 without prompts
Uninstall-KbUpdate -ComputerName server01 -HotfixId KB4498951 -Confirm:$false

# Uninstall kb4498951 from server23 and server24
Get-KbInstalledSoftware -ComputerName server23, server24 -Pattern kb4498951 | Uninstall-KbUpdate

# Or uninstall allll software, what what
Get-KbInstalledSoftware -ComputerName server23 | Uninstall-KbUpdate
```

If you receive the message `Couldn't determine a way to uninstall $($update.Name). It may be marked as a permanent install or part of another package that contains the unintaller`, you can pass the uninstaller argument string.

```powershell
# Or uninstall allll software, what what
Get-KbInstalledSoftware -ComputerName server23 -ArgumentList "/S" | Uninstall-KbUpdate
```

### Save-KbScanFile

 Windows Update Agent (WUA) plus [the wsusscn2.cab catalog file](https://learn.microsoft.com/en-us/windows/win32/wua_sdk/using-wua-to-scan-for-updates-offline) can be used to scan computers for security updates without connecting to Windows Update or to a Windows Server Update Services (WSUS) server, which enables computers that are not connected to the Internet to be scanned for security updates.

```powershell
# Saves the cab file to a temporary directory and returns the results of Get-ChildItem for the cab file
Save-KbScanFile

# Saves the cab file to C:\temp and overwrite file if it exists. Returns the results of Get-ChildItem for the cab file
Save-KbScanFile -Path C:\temp -AllowClobber
```

### Select-KbLatest

Gets the latest patches from a batch of patches, based on Supersedes and SupersededBy. This command basically exposes the routine that is used to filter using -Latest in Get-KbUpdate.

```powershell
# Selects latest from a batch of patches based on Supersedes and SupersededBy
Get-KbUpdate -Pattern 'sql 2017' | Where-Object Classification -eq Updates | Select-KbLatest
```

## Screenshots

![image](https://user-images.githubusercontent.com/8278033/60805564-c127af00-a180-11e9-843a-e7d159a50aa7.png)

![image](https://user-images.githubusercontent.com/8278033/60806212-ad7d4800-a182-11e9-8948-95842e8adef0.png)

![image](https://user-images.githubusercontent.com/8278033/60805580-c97fea00-a180-11e9-9ad9-315812eae144.png)

![image](https://user-images.githubusercontent.com/8278033/73614221-69113800-45fd-11ea-89b5-465728f61ed7.png)

![image](https://user-images.githubusercontent.com/8278033/73614293-f9e81380-45fd-11ea-89af-72fc78698660.png)

## More Help

Get more help

```powershell
Get-Help Get-KbUpdate -Detailed
```

## Methodolgy

kbupdate uses [Invoke-DscResource](https://devblogs.microsoft.com/powershell/invoking-powershell-dsc-resources-directly/) to install patches on remote machines. `Invoke-DscResource` was introduced in the WMF 5.0 Preview in February 2015 and is included in Windows Server 2016+, and Windows 10+.

If you need it on older systems (going back to Windows Server 2008 R2 and Windows 7 SP1), you can find the binaries on [Microsoft's site](https://learn.microsoft.com/en-us/powershell/scripting/windows-powershell/wmf/setup/install-configure?view=powershell-7.2).

If you can't update to WMF 5.0+, `PSWindowsUpdate` is probably your best bet.

## PSWindowsUpdate

If you're wondering about the difference between `kbupdate` and `PSWindowsUpdate`, `PSWindowsUpdate` only gets you updates your systems needs, either from WSUS or from WU. You can exclude some, but you won't get anything that your system doesn't currently need. `PSWindowsUpdate` also uses Schedule Tasks and Windows Update to get around security restrictions, while `kbupdate` uses `Invoke-DscResource` on remote machines and attempts to use Windows Update on local systems if the Windows Update service is not disabled.

It's possible you'll end up using `PSWindowsUpdate` and `kbudpate` together.

## DSC Considerations

The `Install-KbUpdate` command uses the `Invoke-DscResource` to run a method of the `Package` or `xHotFix` resource against the target node. Using `Invoke-DscResource` bypasses the Local Configuration Manager (LCM) on the target node so should not affect your current configuration.  However, if you are currently using DSC to control the desired state of your target node and you contradict the call to `Invoke-DscResource` you could sees issues. For example if the LCM has a `Package` resource saying that KB4527376 should not be installed, and then you install it with `Install-KbUpdate` after the install finishes the LCM will report it is not in the desired state, and depending on your LCM settings could uninstall the KB.

## Dependencies

- kbupdate-library - a sqlite db
- PSFramework - for PowerShell goodness
- PSSQLite - to query the included db
- PoshWSUS - to query the WSUS server when `-Source WSUS` is specified

## Thank you!

Thanks to all of the contributors and downloaders! Also, thanks to the [redditor who helped with the description](https://www.reddit.com/r/PowerShell/comments/f3rusq/comment/fhmli61/).