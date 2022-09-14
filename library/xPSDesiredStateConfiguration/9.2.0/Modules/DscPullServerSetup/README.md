# DSCPullServerSetup

The DSCPullServerSetup module contains utilities to automate DSC module and
configuration document packaging and deployment on an enterprise DSC Pull
Server, with examples.

## Publish-DscModuleAndMof

Use `Publish-DscModuleAndMof` cmdlet to package a module containing DSC Resources
that are present in `$Source` or in `$ModuleNameList` into zip files with version
info, then publish them with MOF configuration documents that are present
in `$Source` to the Pull server.

- This publishes all the DSC Resources in `$env:ProgramFiles\WindowsPowerShell\DscService\Modules`.
- This publishes all the MOF configuration documents in `$env:ProgramFiles\WindowsPowerShell\DscService\Configuration`.
- Use `-Force` to force packaging the version that exists in $Source folder if
  a different version of the module exists in the PowerShell module path.
- Use `-ModuleNameList` to specify the names of the modules to be published (all
  versions if multiple versions of the module are installed) if no DSC module
  present in local folder `$Source`

```powershell
.EXAMPLE
    Publish-DSCModuleAndMof -Source C:\LocalDepot

.EXAMPLE
    $moduleList = @("xWebAdministration", "xPhp")
    Publish-DSCModuleAndMof -Source C:\LocalDepot -ModuleNameList $moduleList

.EXAMPLE
    Publish-DSCModuleAndMof -Source C:\LocalDepot -Force
```

## How to Configure Pull Server & SQL Server to enable new SQL backend provider feature in DSC

- Install SQL Server on a clean OS
- On the SQL Server Machine:
  - Create a Firewall rule according to this link : https://technet.microsoft.com/en-us/library/ms175043(v=sql.110).aspx
  - Enable TCP/IP :
    - Open "SQL Server Configuration Manager"
    - Now Click on "SQL Server Network Configuration" and Click on "Protocols for Name"
    - Right Click on "TCP/IP" (make sure it is Enabled) Click on Properties
    - Now Select "IP Addresses" Tab -and- Go to the last entry "IP All"
    - Enter "TCP Port" 1433.
    - Now Restart "SQL Server .Name." using "services.msc" (winKey + r)
  - Enable Remote Connections to the SQL Server
    - Go to Server Properties
    - Select Connections
    - Under the Remote server connections - Click the check box next to "Allow remote connections to this server"
  - Create a new User login (This is required as the engine will need this privilege to create the DSC DB and tables)
    - Go to the Login Properties
    - Select Server Roles - select "Public" and "Sysadmin"
    - Select User Mapping - select "db_owner" and "public"
  - On the Pull Server
    - Update the Web.Config with the SQL server connection string
    - Open: C:\inetpub\wwwroot\PSDSCPullServer\Web.config
    - &lt;add key="dbprovider" value="System.Data.OleDb"/&gt;
    - &lt;add key="dbconnectionstr" value="Provider=SQLNCLI11;Data Source=&lt;ServerName&gt;;Initial Catalog=master;User ID=sa;Password=&lt;sapassword&gt;;Initial Catalog=master;"/&gt;
    - If SQL server was installed as a named Instance instead of default one then use
    - &lt;add key="dbconnectionstr" value="Provider=SQLNCLI11;Data Source=&lt;ServerName\InstanceName&gt;;Initial Catalog=master;User ID=sa;Password=&lt;sapassword&gt;;Initial Catalog=master;"/&gt;
  - Run iireset for the Pull server to pick up the new configuration.
