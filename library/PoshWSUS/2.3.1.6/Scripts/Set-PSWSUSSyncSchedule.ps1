function Set-PSWSUSSyncSchedule {
<#
	.SYNOPSIS
		Determines whether the WSUS server synchronizes the updates and sets the number of server-to-server synchronizations a day.

	.PARAMETER SynchronizeAutomatically
        Determines whether the WSUS server synchronizes the updates automatically. 
        $True if the WSUS server automatically synchronizes the updates at the specified time. 
        $False if synchronization is invoked manually. 

	.PARAMETER SynchronizeAutomaticallyTimeOfDay
        Sets the time of day when the WSUS server automatically synchronizes the updates.
        Time of day when the WSUS server automatically synchronizes the updates. Specify the value as a time span since midnight.
        Express the time in Coordinated Universal Time (UTC). The smallest allowable unit of time is a second;
        fractions of a second will be truncated. 
        The time span cannot be greater than or equal to 24 hours or set to a negative time value.

    .PARAMETER NumberOfSynchronizationsPerDay
        Sets the number of server-to-server synchronizations a day. 
        The number of server-to-server synchronizations a day (between 1 and 24).

    .EXAMPLE
		Set-PSWSUSSyncSchedule -SynchronizeAutomatically $false

        Description
        -----------
        Synchronization is invoked manually
	
    .EXAMPLE
		[System.TimeSpan]$TimeSnap = New-TimeSpan -Hours 18 
        Set-PSWSUSSyncSchedule -SynchronizeAutomatically $true -SynchronizeAutomaticallyTimeOfDay $TimeSnap -NumberOfSynchronizationsPerDay 2

        Description
        -----------
        Automatically synchronizes. Start at 18 PM. Sync 2 times per day.

    .EXAMPLE
		[System.TimeSpan]$TimeSnap = New-TimeSpan -Hours 4  -Minutes 30
        Set-PSWSUSSyncSchedule -SynchronizeAutomatically $true -SynchronizeAutomaticallyTimeOfDay $TimeSnap -NumberOfSynchronizationsPerDay 3

        Description
        -----------
        Automatically synchronizes. Start at 4:30 AM. Sync 3 times per day.

    .INPUTS
		System.TimeSpan, Boolean, Integer

	.NOTES
		Name: Set-PSWSUSSyncSchedule
        Author: Dubinsky Evgeny
        DateCreated: 1DEC2013

	.LINK
		http://blog.itstuff.in.ua/?p=62#Set-PSWSUSSyncSchedule

#>

    [CmdletBinding()]
    Param
    (
        [Parameter(Position = 0,Mandatory=$true)]
        [Boolean]$SynchronizeAutomatically,
        [System.TimeSpan]$SynchronizeAutomaticallyTimeOfDay,
        [ValidateRange(1, 24)][int]
        $NumberOfSynchronizationsPerDay
    )

    Begin
    {
        if($wsus)
        {
            $subscription = $wsus.GetSubscription()
        }#endif
        else
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
            Break
        }
    }
    Process
    {        
        if ($SynchronizeAutomatically)
        {
            $subscription.SynchronizeAutomatically = $SynchronizeAutomatically
            
            if ($PSBoundParameters['SynchronizeAutomaticallyTimeOfDay'])
            {
                # -------------------------------------------------- #
                # SynchronizeAutomaticallyTimeOfDay Property
                # WSUS stores dates and times in Coordinated Universal Time, 
                # so convert the local time to Coordinated Universal Time.
                # http://msdn.microsoft.com/en-us/library/microsoft.updateservices.administration.isubscription.synchronizeautomaticallytimeofday(v=vs.85).aspx
                # -------------------------------------------------- #
                
                [System.DateTime]$localSyncHour = [System.DateTime]::Today + $SynchronizeAutomaticallyTimeOfDay
                $subscription.SynchronizeAutomaticallyTimeOfDay = $localSyncHour.ToUniversalTime().TimeOfDay
            
            }#endif
            
            if ($PSBoundParameters['NumberOfSynchronizationsPerDay'])
            {
                $subscription.NumberOfSynchronizationsPerDay = $NumberOfSynchronizationsPerDay
            }#endif
        }#endif
        else
        {
            $subscription.SynchronizeAutomatically = $false
        }#endElse
    }#endProcess
    End
    {
        $subscription.Save()
    }
}
