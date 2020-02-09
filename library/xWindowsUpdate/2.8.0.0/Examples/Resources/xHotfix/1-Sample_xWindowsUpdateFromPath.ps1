<#
    .EXAMPLE
    This sample looks at installing a particular windows update. However, the path and ID properties can be changed
    as per the hotfix that you want to install
 #>

Configuration Example
{
    Import-DscResource -ModuleName xWindowsUpdate

    xHotfix m1 {
        Path   = "c:\WindowsBlue-KB2937982-x64.msu"
        Id     = "KB2937982"
        Ensure = "Present"
    }

}