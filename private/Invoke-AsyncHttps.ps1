function Invoke-AsyncHttps {
    <#
        .SYNOPSIS
        Uses Runspaces to issue async http requests.

        .EXAMPLE
        Invoke-AsyncHttps -DnsName www.contoso.com -UriPaths $('dir1','dir2','dir3')
    #>

    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true)]
        [ValidateScript( { Resolve-DnsName $_ })]
        [System.String]
        # DNS name of target website
        $DnsName
        ,
        [parameter(Mandatory = $true)]
        [System.String[]]
        # Uri Paths to request.
        $UriPaths
        ,
        [parameter(Mandatory = $false)]
        [ValidateRange(3, 10000)]
        [System.Int32]
        # Max number of threads for RunspacePool.
        $MaxThreads = 10
        ,
        [parameter(Mandatory = $false)]
        [ValidateRange(1, 100000)]
        [System.Int32]
        # Milliseconds to wait for jobs.
        $WaitTime = 1000
    )
    begin {
        # TESTING - Hardcode PowerShell to not validate certificates
        add-type @'
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
'@
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

        # TESTING - Hardcode PowerShell to use insecure protocols if necessary
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'

        # Script to run in each thread.
        [System.Management.Automation.ScriptBlock]$ScriptBlock = {
            param($dnsName, $path)

            $uriRoot = New-Object System.UriBuilder('https', $dnsName)
            $uriRoot.Path = $path

            $result = New-Object PSObject -Property @{  'Uri' = $uriRoot.Uri.AbsoluteUri;
                'Status'                                      = '00'
                'BeginTime'                                   = Get-Date -Format 'yyyy/MM/dd HH:mm:ss.fff'
                'EndTime'                                     = Get-Date -Format 'yyyy/MM/dd HH:mm:ss.fff'  
            }

            try {

                $httpResponse = Invoke-WebRequest -Uri $result.Uri

                if ($null -ne $httpResponse) {
                    $result.Status = $httpResponse.StatusCode
                    $result.EndTime = Get-Date -Format 'yyyy/MM/dd HH:mm:ss.fff'
                    $httpResponse.Dispose()
                }

            } catch [System.Net.WebException] {

                $e = $_

                $result.EndTime = Get-Date -Format 'yyyy/MM/dd HH:mm:ss.fff'

                $responseCode = [int]([regex]::Match($e.Exception.Message, '[0-9]{3}')).Value

                if ($responseCode -gt 0) {

                    $result.Status = $responseCode

                } else {

                    $result.Status = $e.Exception.Message
                }

            } catch {

                $e = $_

                $result.EndTime = Get-Date -Format 'yyyy/MM/dd HH:mm:ss.fff'

                $result.Status = $e.Exception.Message

            } finally {

                if ($null -ne $httpResponse) {
                    $httpResponse.Dispose()
                }

                if ($result.Status -eq '00') {
                    $result.EndTime = Get-Date -Format 'yyyy/MM/dd HH:mm:ss.fff'
                }
            }

            return $result

        } # End $ScriptBlock
    }
    process {
        $Start = Get-Date

        $Results = @()

        $AllJobs = New-Object System.Collections.ArrayList

        $HostRunspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(2, $MaxThreads, $Host)

        $HostRunspacePool.Open()

        Write-Verbose -Message "Submitting async jobs."

        foreach ($uriPath in $UriPaths) {
            $asyncJob = [System.Management.Automation.PowerShell]::Create().AddScript($ScriptBlock).AddParameter('dnsName', $DnsName).AddParameter('path', $uriPath)

            $asyncJob.RunspacePool = $HostRunspacePool

            $asyncJobObj = @{ JobHandle = $asyncJob;
                AsyncHandle             = $asyncJob.BeginInvoke()    
            }

            $AllJobs.Add($asyncJobObj) | Out-Null
        }

        Write-Verbose -Message "Finished submitting async jobs."
        Write-Verbose -Message "Processing completed jobs."

        $ProcessingJobs = $true

        Do {

            $CompletedJobs = $AllJobs | Where-Object { $_.AsyncHandle.IsCompleted }

            if ($null -ne $CompletedJobs) {
                foreach ($job in $CompletedJobs) {
                    $result = $job.JobHandle.EndInvoke($job.AsyncHandle)

                    if ($null -ne $result) {
                        $Results += $result
                    }

                    $job.JobHandle.Dispose()

                    $AllJobs.Remove($job)
                }

            } else {

                if ($AllJobs.Count -eq 0) {
                    $ProcessingJobs = $false

                } else {

                    Start-Sleep -Milliseconds $WaitTime
                }
            }

            Write-Verbose -Message "Jobs in progress $($AllJobs.Count)"

        } While ($ProcessingJobs)

        $HostRunspacePool.Close()
        $HostRunspacePool.Dispose()

        Write-Verbose -Message "Start  $($Start.ToString('yyyy/MM/dd HH:mm:ss.fff'))"
        Write-Verbose -Message "Finish $(Get-Date -Format 'yyyy/MM/dd HH:mm:ss.fff')"

        return $Results

    } # End function Invoke-AsyncHttps
}