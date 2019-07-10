$script:ModuleRoot = $PSScriptRoot
$script:site = "https://sharepoint2016"
$script:mylist = "My Test List"
$script:filename = "$script:ModuleRoot\$script:mylist.xml"
$script:onlinesite = "https://netnerds.sharepoint.com"
if ($env:sponlinecred) {
    $secpasswd = ConvertTo-SecureString $env:sponlinecred -AsPlainText -Force
    $script:onlinecred = New-Object System.Management.Automation.PSCredential ("test@netnerds.onmicrosoft.com", $secpasswd)
}
elseif (Test-Path "$home\Documents\sponline.xml") {
    $script:onlinecred = Import-CliXml -Path "$home\Documents\sponline.xml"
}