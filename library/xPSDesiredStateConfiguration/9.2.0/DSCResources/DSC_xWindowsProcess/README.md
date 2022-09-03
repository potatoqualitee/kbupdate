# Description

Provides a mechanism to start and stop a Windows process.

#### Parameters

* **[String] Path** _(Key)_: The executable file of the process. This can be
  defined as either the full path to the file or as the name of the file if it
  is accessible through the environment path. Relative paths are not supported.
* **[String] Arguments** _(Key)_: A single string containing all the arguments
  to pass to the process. Pass in an empty string if no arguments are needed.
* **[PSCredential] Credential** _(Write)_: The credential of the user account
  to run the process under. If this user is from the local system, the
  StandardOutputPath, StandardInputPath, and WorkingDirectory parameters cannot
  be provided at the same time.
* **[String] Ensure** _(Write)_: Specifies whether or not the process should be
  running. To start the process, specify this property as Present. To stop the
  process, specify this property as Absent. { *Present* | Absent }.
* **[String] StandardOutputPath** _(Write)_: The file path to which to write
  the standard output from the process. Any existing file at this file path
  will be overwritten. This property cannot be specified at the same time as
  Credential when running the process as a local user.
* **[String] StandardErrorPath** _(Write)_: The file path to which to write the
  standard error output from the process. Any existing file at this file path
  will be overwritten.
* **[String] StandardInputPath** _(Write)_: The file path from which to receive
  standard input for the process. This property cannot be specified at the same
  time as Credential when running the process as a local user.
* **[String] WorkingDirectory** _(Write)_: The file path to the working
  directory under which to run the process. This property cannot be specified
  at the same time as Credential when running the process as a local user.
