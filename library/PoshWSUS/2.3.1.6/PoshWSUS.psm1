<#
To Do:
    1. New-PSWSUSLocalPackage
    2. Get-PSWSUSLocalPackage
    3. Get-PSWSUSUpdateApproval
    4. Set-PSWSUSConfiguration
    5. New-PSWSUSClient
#>

# Set Script Path
$ScriptPath = Split-Path $MyInvocation.MyCommand.Path

# Ensure necessary Registry Settings
if (-not (Test-Path "HKLM:\SOFTWARE\Microsoft\Update Services\Server\Setup"))
{
	# Push to registry node, so New-ItemProperty has the correct PropertyTypes
	Push-Location "HKLM:\"
	
	# Create Container
	New-Item "HKLM:\SOFTWARE\Microsoft\Update Services\Server\Setup" -Force | Out-Null
	
	# Keys necessary for WSUS libraries to function
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Update Services\Server\Setup" -Name "ConfigurationSource" -PropertyType "DWORD" -Value 0 -ErrorAction 'Stop' | Out-Null
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Update Services\Server\Setup" -Name "EnableRemoting" -PropertyType "DWORD" -Value 1 -ErrorAction 'Stop' | Out-Null
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Update Services\Server\Setup" -Name "TargetDir" -PropertyType "String" -Value "$($env:ProgramFiles)\Update Services\" -ErrorAction 'Stop' | Out-Null
	
	# Pop back to where you were
	Pop-Location
}

# Load libraries (32bit)
if ([System.IntPtr]::Size -eq 4)
{
	try
	{
		# Try loading properly installed Assemblies first
		Add-Type -AssemblyName "Microsoft.UpdateServices.Administration" -ErrorAction Stop
	}
	catch
	{
		# Try loading brought along Assemblies second
		Add-Type -Path "$ScriptPath\Libraries\x86\Microsoft.UpdateServices.Administration.dll" -ErrorAction 'SilentlyContinue'
	}
}
# Load libraries (64bit)
else
{
	try
	{
		# Try loading properly installed Assemblies first
		Add-Type -AssemblyName "Microsoft.UpdateServices.Administration" -ErrorAction Stop
	}
	catch
	{
		# Try loading brought along Assemblies second
		Add-Type -Path "$ScriptPath\Libraries\x64\Microsoft.UpdateServices.Administration.dll" -ErrorAction 'SilentlyContinue'
	}
}

# Validate Library
if ( -not ( [appdomain]::CurrentDomain.GetAssemblies() | %{ $_.GetName() } | Where-Object { $_.Name -eq "Microsoft.UpdateServices.Administration" } ) )
{
	Write-Warning "WSUS Libraries could not be loaded"
	break
}

# Load Functions
Try
{
    Get-ChildItem "$ScriptPath\Scripts" | Select-Object -ExpandProperty FullName | ForEach-Object {
        $Function = Split-Path $_ -Leaf
        . $_
    }
}
Catch
{
    Write-Warning ("{0}: {1}" -f $Function,$_.Exception.Message)
    Continue
}

if (-not ($DefaultWsusPort))
{
	$global:DefaultWsusPort = 8530
}


<#
TODO:
$ExecutionContext.SessionState.Module.OnRemove{
    Remove-Variable -Name Wsus -Scope Global -Force
}
#>