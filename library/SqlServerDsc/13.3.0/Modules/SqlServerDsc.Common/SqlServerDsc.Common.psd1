@{
    RootModule = 'SqlServerDsc.Common.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # ID used to uniquely identify this module
    GUID = 'b8e5084a-07a8-4135-8a26-00614e56ba71'

    # Author of this module
    Author = 'DSC Community'

    # Company or vendor of this module
    CompanyName = 'DSC Community'

    # Copyright statement for this module
    Copyright = 'Copyright the DSC Community contributors. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Functions used by the DSC resources in SqlServerDsc.'

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'New-InvalidArgumentException'
        'New-InvalidOperationException'
        'New-ObjectNotFoundException'
        'New-InvalidResultException'
        'New-NotImplementedException'
        'Get-LocalizedData'
        'Test-DscParameterState'
        'Get-RegistryPropertyValue'
        'Format-Path'
        'Copy-ItemWithRobocopy'
        'Get-TemporaryFolder'
        'Invoke-InstallationMediaCopy'
        'Connect-UncPath'
        'Disconnect-UncPath'
        'Test-PendingRestart'
        'Start-SqlSetupProcess'
        'Connect-SQL'
        'Connect-SQLAnalysis'
        'Get-SqlInstanceMajorVersion'
        'Import-SQLPSModule'
        'Restart-SqlService'
        'Restart-ReportingServicesService'
        'Invoke-Query'
        'Update-AvailabilityGroupReplica'
        'Test-LoginEffectivePermissions'
        'Test-AvailabilityReplicaSeedingModeAutomatic'
        'Get-PrimaryReplicaServerObject'
        'Test-ImpersonatePermissions'
        'Split-FullSqlInstanceName'
        'Test-ClusterPermissions'
        'Test-ActiveNode'
        'Invoke-SqlScript'
        'Get-ServiceAccount'
        'Find-ExceptionByNumber'

    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{

        PSData = @{
        } # End of PSData hashtable

    } # End of PrivateData hashtable
}

