# kbupdate
KB Viewer and Saver

## Install (coming soon)

```powershell
Install-Module kbupdate -Scope CurrentUser
```

## Examples - Get-KbUpdate

```powershell
# Get detailed information about KB4057119. This works for SQL Server or any other KB.
Get-KbUpdate -Name KB4057119

# Get detailed information about KB4057119 and KB4057114.
Get-KbUpdate -Name KB4057119, 4057114

# Faster. Gets, at the very least: Title, Architecture, Language, Hotfix, UpdateId and Link
Get-KbUpdate -Name KB4057119, 4057114 -Simple
```

## Examples - Save-KbUpdate

```powershell
# Download KB4057119 to the current directory. This works for SQL Server or any other KB.
Save-KbUpdate -Name KB4057119

# Download the selected x64 files from KB4057119 to the current directory.
Get-KbUpdate -Name 3118347 -Simple -Architecture x64 | Out-GridView -Passthru | Save-KbUpdate

# Download KB4057119 and the x64 version of KB4057114 to C:\temp.
Save-KbUpdate -Name KB4057119, 4057114 -Architecture x64 -Path C:\temp
```

## More Help

Get more help

```powershell
Get-Help Get-KbUpdate -Detailed
```