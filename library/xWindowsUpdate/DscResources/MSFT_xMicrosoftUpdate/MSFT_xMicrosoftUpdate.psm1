function Write-DeprecatedMessage
{
    Write-Warning -Message 'xMicrosoftUpdate is deprecated.  Please use xWindows Update Agent'
}

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure
    )

    Write-DeprecatedMessage
    Write-Verbose -Message "Getting Windows Update Agent services..."
    #Get the registered update services
    $UpdateServices = (New-Object -ComObject Microsoft.Update.ServiceManager).Services

    $returnValue = @{
                        Ensure = $Ensure
                    }

    #Check if the microsoft update service is registered
    if($UpdateServices | Where-Object {$_.ServiceID -eq '7971f918-a847-4430-9279-4a52d1efe18d'})
    {
        Write-Verbose -Message "Microsoft Update Present..."
        $returnValue.Ensure = 'Present'
    }
    Else
    {
        Write-Verbose -Message "Microsoft Update Absent..."
        $returnValue.Ensure = 'Absent'
    }
    
    $returnValue
}


function Set-TargetResource
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure
    )

    Write-DeprecatedMessage
    Switch($Ensure)
    {
        'Present'
        {
            If($PSCmdlet.ShouldProcess("Enable Microsoft Update"))
            {
                Try
                {
                    Write-Verbose -Message "Enable the Microsoft Update setting"
                    (New-Object -ComObject Microsoft.Update.ServiceManager).AddService2('7971f918-a847-4430-9279-4a52d1efe18d',7,"")
                    Restart-Service wuauserv -ErrorAction SilentlyContinue
                }
                Catch
                {
                    $ErrorMsg = $_.Exception.Message
                    Write-Verbose $ErrorMsg
                }
            }
        }
        'Absent'
        {
            If($PSCmdlet.ShouldProcess("$Drive","Disable Microsoft Update"))
            {
                Try
                {
                    Write-Verbose -Message "Disable the Microsoft Update setting"
                    (New-Object -ComObject Microsoft.Update.ServiceManager).RemoveService('7971f918-a847-4430-9279-4a52d1efe18d')
                }
                Catch
                {
                    $ErrorMsg = $_.Exception.Message
                    Write-Verbose $ErrorMsg
                }
            }
        }
    }
}

function Test-TargetResource
{
    # Verbose messages are written in Get.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSDSCUseVerboseMessageInDSCResource", "")]
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure
    )

    #Output the result of Get-TargetResource function.
    
    $Get = Get-TargetResource -Ensure $Ensure

    If($Ensure -eq $Get.Ensure)
    {
        return $true
    }
    Else
    {
        return $false
    }
}


Export-ModuleMember -Function *-TargetResource
