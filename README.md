<img align="left" src=https://user-images.githubusercontent.com/8278033/60797982-97668c00-a170-11e9-8f61-06bd40413c54.png alt="kbupdate logo">

# kbupdate
KB Viewer, Saver, Installer and Uninstaller

## Install

```powershell
Install-Module kbupdate -Scope CurrentUser
```

## Get-KbUpdate

```powershell
# Get detailed information about KB4057119. This works for SQL Server or any other KB.
Get-KbUpdate -Name KB4057119

# Get detailed information about KB4057119 and KB4057114.
Get-KbUpdate -Name KB4057119, 4057114

# Faster. Gets, at the very least: Title, Architecture, Language, Hotfix, UpdateId and Link
Get-KbUpdate -Name KB4057119, 4057114 -Simple
```

## Save-KbUpdate

```powershell
# Download KB4057119 to the current directory. This works for SQL Server or any other KB.
Save-KbUpdate -Name KB4057119

# Download the selected x64 files from KB4057119 to the current directory.
Get-KbUpdate -Name 3118347 -Simple -Architecture x64 | Out-GridView -Passthru | Save-KbUpdate

# Download KB4057119 and the x64 version of KB4057114 to C:\temp.
Save-KbUpdate -Name KB4057119, 4057114 -Architecture x64 -Path C:\temp
```

## Install-KbUpdate

```powershell
# Install KB4534273 from the \\fileshare\sql\ directory on server01
Install-KbUpdate -ComputerName server01 -FilePath \\fileshare\sql\windows10.0-kb4532947-x64_20103b70445e230e5994dc2a89dc639cd5756a66.msu

# Automatically save an update, stores it in Downloads and install it from there
Install-KbUpdate -ComputerName sql2017 -HotfixId kb4486129
```

## Uninstall-KbUpdate

```powershell
# Uninstalls KB4498951 from server01
Uninstall-KbUpdate -ComputerName server01 -HotfixId KB4498951

# Uninstalls KB4498951 on server01 without prompts
Uninstall-KbUpdate -ComputerName server01 -HotfixId KB4498951 -Confirm:$false

# Uninstall kb4498951 from server23 and server24
Get-KbInstalledUpdate -ComputerName server23, server24 -Pattern kb4498951 | Uninstall-KbUpdate
```

## Get-KbInstalledUpdate

```powershell
# Test to see if KB4057119 and get a bunch of info about it on server01
Get-KbInstalledUpdate -ComputerName server01 -Pattern KB4057119

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
## Dependencies

- kbupdate-library - a sqlite db
- PSFramework - for PowerShell goodness
- PSSQLite - to query the included db
- PoshWSUS - to query the WSUS server when `-Source WSUS` is specified


## DSC Considerations
The `Install-KbUpdate` command uses the `Invoke-DscResource` to run a method of the `Package` or `xHotFix` resource against the target node. Using `Invoke-DscResource` bypasses the Local Configuration Manager (LCM) on the target node so should not affect your current configuration.  However, if you are currently using DSC to control the desired state of your target node and you contradict the call to `Invoke-DscResource` you could sees issues. For example if the LCM has a `Package` resource saying that KB4527376 should not be installed, and then you install it with `Install-KbUpdate` after the install finishes the LCM will report it is not in the desired state, and depending on your LCM settings could uninstall the KB.
