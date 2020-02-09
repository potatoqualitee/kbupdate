<#
    .EXAMPLE
    Enables Mircosoft Update on Server1, Server2 and Server3
#>

Configuration Example
{
    Import-DscResource -Module xWindowsUpdate

    Node localhost
    {
        xMicrosoftUpdate "EnableMSUpdate" {
            Ensure = "Present"
        }
    }
}