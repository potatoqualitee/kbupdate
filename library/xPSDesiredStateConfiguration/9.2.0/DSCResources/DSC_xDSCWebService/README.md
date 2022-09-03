# Description

This resource is used to configure a DSC Pull Server on a Windows Server with
IIS.

## Notes

Configuring a Windows Firewall rule (exception) for a DSC Pull Server instance
by using the xDscWebService resource is **considered deprecated** and thus will
be removed in the future.

DSC will issue a warning when the **ConfigureFirewall** property is set to
**true**. Currently the default value is **true** to maintain backwards
compatibility with existing configurations. At a later time the default value
will be set to **false** and in the last step the  support to create a
firewall rule using xDscWebService will be removed.

All users are requested to adjust existing configurations so that the
**ConfigureFirewall** is set to **false** and a required Windows Firewall rule
is created by using the **Firewall** resource from the
[NetworkingDsc](https://github.com/dsccommunity/NetworkingDsc) module.

## Creating a custom Application Pool

If the `ApplicationPoolName` parameter is specified the default pool name of 'PSWS'
will not be used. In this case a new pool will need to be created. Preferably
the new application pool is created by using the __xWebAppPool__ resource from the
[xWebAdministration](https://github.com/dsccommunity/xWebAdministration) DSC module.

## Using Security Best Practices

Setting the `UseSecurityBestPractices` parameter to `$true` will reset registry
values under `HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL`.
This environment change enforces the use of stronger encryption cypher and may
affect legacy applications. More information can be found at
https://support.microsoft.com/en-us/kb/245030 and
https://technet.microsoft.com/en-us/library/dn786418(v=ws.11).aspx.
