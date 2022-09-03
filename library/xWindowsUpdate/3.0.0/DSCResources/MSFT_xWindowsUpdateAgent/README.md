# Description

The resource is responsible for configuring the Windows Update Agent on the node.

The resource can configure the source download settings for the node, update
notifications on the system, and can automatically initiate installation of
the updates.

For more information around Windows Update, please refer to the article
[Best Practices for Applying Service Packs, Hotfixes and Security Patches](https://docs.microsoft.com/en-us/previous-versions/tn-archive/cc750077(v=technet.10)).

## Notifications

See the article [AutomaticUpdatesNotificationLevel enumeration](https://docs.microsoft.com/en-us/windows/win32/api/wuapi/ne-wuapi-automaticupdatesnotificationlevel)
for more information about the different options for notification.

## Category

Please note that category `'Security'` is not mutually exclusive with the
category `'Important'` and `'Optional'`, so selecting category `'Important'`
may install some security updates, etcetera.
