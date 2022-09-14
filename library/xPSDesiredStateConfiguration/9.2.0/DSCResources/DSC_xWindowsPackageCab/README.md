# Description

Provides a mechanism to install or uninstall a package from a windows cabinet
(cab) file on a target node. This resource works on Nano Server.

## Requirements

- Target machine must have access to the DISM PowerShell module.

## Parameters

* **[String] Name** _(Key)_: The name of the package to install or uninstall.
* **[String] Ensure** _(Required)_: Specifies whether the package should be
  installed or uninstalled. To install the package, set this property to
  Present. To uninstall the package, set the property to Absent. { *Present* |
  Absent }.
* **[String] SourcePath** _(Required)_: The path to the cab file to install or
  uninstall the package from.
* **[String] LogPath** _(Write)_: The path to a file to log the operation to.
  There is no default value, but if not set, the log will appear at
  %WINDIR%\Logs\Dism\dism.log.
