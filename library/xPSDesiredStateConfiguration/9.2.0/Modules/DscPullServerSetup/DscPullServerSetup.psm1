$errorActionPreference = 'Stop'
Set-StrictMode -Version 'Latest'

$modulePath = Split-Path -Path $PSScriptRoot -Parent

# Import the Networking Resource Helper Module
Import-Module -Name (Join-Path -Path $modulePath `
    -ChildPath (Join-Path -Path 'xPSDesiredStateConfiguration.Common' `
        -ChildPath 'xPSDesiredStateConfiguration.Common.psm1'))

Import-Module -Name (Join-Path -Path $modulePath -ChildPath 'DscResource.Common')

# Import Localization Strings
$script:localizedData = Get-LocalizedData -DefaultUICulture 'en-US'

<#
    .SYNOPSIS
        Package DSC modules and mof configuration document and publish them on an enterprise DSC pull server in the required format.

    .DESCRIPTION
        Uses Publish-DscModulesAndMof function to package DSC modules into zip files with the version info.
        Publishes the zip modules on "$env:ProgramFiles\WindowsPowerShell\DscService\Modules".
        Publishes all mof configuration documents that are present in the $Source folder on "$env:ProgramFiles\WindowsPowerShell\DscService\Configuration"-
        Use $Force to overwrite the version of the module that exists in the PowerShell module path with the version from the $source folder.
        Use $ModuleNameList to specify the names of the modules to be published if the modules do not exist in $Source folder.

    .PARAMETER Source
        The folder that contains the configuration mof documents and modules to be published on Pull server.
        Everything in this folder will be packaged and published.

    .PARAMETER Force
        Switch to overwrite the module in PSModulePath with the version provided in $Sources.

    .PARAMETER ModuleNameList
        Package and publish the modules listed in $ModuleNameList based on PowerShell module path content.

    .EXAMPLE
        $ModuleList = @("xWebAdministration", "xPhp")
        Publish-DscModuleAndMof -Source C:\LocalDepot -ModuleNameList $ModuleList

    .EXAMPLE
        Publish-DscModuleAndMof -Source C:\LocalDepot -Force
#>
function Publish-DscModuleAndMof
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateScript({
            Test-Path -Path $_ -PathType Container
        })]
        [System.String]
        $Source,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $Force,

        [Parameter()]
        [System.String[]]
        $ModuleNameList
    )

    # Create working directory
    $tempFolder = Join-Path -Path $Source -ChildPath 'temp'
    New-Item -Path $tempFolder -ItemType Directory -Force -ErrorAction SilentlyContinue

    # Copy the mof documents from the $Source to working dir
    $mofPath = Join-Path -Path $Source -ChildPath '*.mof'
    Copy-Item -Path $mofPath -Destination $tempFolder -Force

    # Start Deployment!
    Write-LogEntry -Scope $MyInvocation -Message $script:localizedData.StartDeploymentMessage
    New-ZipFromPSModulePath -ListModuleNames $ModuleNameList -Destination $tempFolder
    New-ZipFromSource -Source $Source -Destination $tempFolder

    # Generate the checkSum file for all the zip and mof files.
    New-DSCCheckSum -Path $tempFolder -Force

    # Publish mof and modules to pull server repositories
    Publish-ModulesAndChecksum -Source $tempFolder
    Publish-MofsInSource -Source $tempFolder

    # Deployment is complete!
    Remove-Item -Path $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
    Write-LogEntry -Scope $MyInvocation -Message $script:localizedData.EndDeploymentMessage
}

<#
    .SYNOPSIS
        Creates a zip archive containing all the modules whose module name was assigned to the parameter ListModuleNames.
        The zip archive is created in the path assigned to the parameter Destination.

    .PARAMETER ListModuleNames
        List of Modules to package

    .PARAMETER Destination
        Destionation path to copy packaged modules to
#>
function New-ZipFromPSModulePath
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.String[]]
        $ListModuleNames,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_ -PathType Container})]
        [System.String]
        $Destination
    )

    # Move all required  modules from powershell module path to a temp folder and package them
    if ([System.String]::IsNullOrEmpty($ListModuleNames))
    {
        Write-LogEntry -Scope $MyInvocation -Message $script:localizedData.NoAdditionalModulesPackagedMessage
    }

    foreach ($module in $ListModuleNames)
    {
        $allVersions = Get-Module -Name $module -ListAvailable

        # Package all versions of the module
        foreach ($moduleVersion in $allVersions)
        {
            $name = $moduleVersion.Name
            $source = "$Destination\$name"

            # Create package zip
            $path = $moduleVersion.ModuleBase
            $version = $moduleVersion.Version.ToString()
            Write-LogEntry -Scope $MyInvocation -Message "Zipping $name ($version)"
            Compress-Archive -Path "$path\*" -DestinationPath "$source.zip" -Force
            $newName = "$Destination\$name" + '_' + "$version" + '.zip'

            # Rename the module folder to contain the version info.
            if (Test-Path -Path $newName)
            {
                $null = Remove-Item -Path $newName -Recurse -Force
            }

            $null = Rename-Item -Path "$source.zip" -NewName $newName -Force
        }
    }
}

<#
    .SYNOPSIS
        Deploys all DSC resource modules in the path assigned to the parameter Source. The DSC resource modules are copied
        to the path '$env:ProgramFiles\WindowsPowerShell\Modules', and also packaged into a zip archive that is saved to
        the path assigned to the parameter Destination.

    .PARAMETER Source
        Folder containing DSC Resource Modules to package

    .PARAMETER Destination
        Destination path to copy zipped DSC Resources to
#>
function New-ZipFromSource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path -Path $_ -PathType Container})]
        [System.String]
        $Source,

        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path -Path $_ -PathType Container})]
        $Destination
    )

    # For each module under $Source folder create a zip package that has the same name as the folder.
    $allModulesInSource = Get-ChildItem -Path $Source -Directory
    $modules = @()

    foreach ($item in $allModulesInSource)
    {
        $name = $Item.Name
        $alreadyExists = Get-Module -Name $name -ListAvailable

        if (($null -eq $alreadyExists) -or ($Force))
        {
            # Install the modules into PowerShell module path and overwrite the content
            Copy-Item -Path $item.FullName -Recurse -Force -Destination "$env:ProgramFiles\WindowsPowerShell\Modules"
        }
        else
        {
            Write-Warning -Message ($script:localizedData.SkippingModuleOverwriteMessage -f $name, $Source)
        }

        $modules += @("$name")
    }

    # Package the module in $destination
    New-ZipFromPSModulePath -ListModuleNames $modules -Destination $Destination
}

<#
    .SYNOPSIS
        Deploy modules to the Pull sever repository.

    .PARAMETER Source
        Folder containing zipped DSC Resources to publish
#>
function Publish-ModulesAndChecksum
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path -Path $_ -PathType Container})]
        [System.String]
        $Source
    )

    # Check if the current machine is a server sku.
    $moduleRepository = "$env:ProgramFiles\WindowsPowerShell\DscService\Modules"

    if ((Get-Module -Name ServerManager -ListAvailable) -and (Test-Path -Path $moduleRepository))
    {
        Write-LogEntry -Scope $MyInvocation -Message ($script:localizedData.CopyingModulesAndChecksumsMessage -f $moduleRepository)
        $zipPath = Join-Path -Path $Source -ChildPath '*.zip*'
        Copy-Item -Path $zipPath -Destination $moduleRepository -Force
    }
    else
    {
        Write-Warning -Message $script:localizedData.CopyingModulesToPullServerMessage
    }
}

<#
    .SYNOPSIS
        Deploy configurations and their checksums.

    .PARAMETER Source
        Folder containing MOFs to publish
#>
function Publish-MofsInSource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path -Path $_ -PathType Container})]
        [System.String]
        $Source
    )

    # Check if the current machine is a server sku.
    $mofRepository = "$env:ProgramFiles\WindowsPowerShell\DscService\Configuration"

    if ((Get-Module -Name ServerManager -ListAvailable) -and (Test-Path -Path $mofRepository))
    {
        Write-LogEntry -Scope $MyInvocation -Message ($script:localizedData.CopyingMOFsAndChecksumsMessage -f $mofRepository)
        $mofPath = Join-Path -Path $Source -ChildPath '*.mof*'
        Copy-Item -Path $mofPath -Destination $mofRepository -Force
    }
    else
    {
        Write-Warning -Message $script:localizedData.CopyingConfigurationsToPullServerMessage
    }
}

<#
    .SYNOPSIS
        Writes a version message with the current time, caller, and message.
#>
function Write-LogEntry
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.DateTime]
        $Date = $(Get-Date),

        [Parameter(Mandatory = $true)]
        [System.Object]
        $Scope,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message
    )

    Write-Verbose -Message "$Date [$($Scope.MyCommand)] :: $Message"
}

<#
    .SYNOPSIS
        Deploy DSC modules to the pullserver.

    .DESCRIPTION
        Publish DSC module using Module Info object as an input.
        The cmdlet will figure out the location of the module repository using web.config of the pullserver.

    .PARAMETER Name
        Name of the module.

    .PARAMETER ModuleBase
        This is the location of the base of the module.

    .PARAMETER Version
        This is the version of the module

    .PARAMETER PullServerWebConfig
        Path to the Pull Server web.config file, i.e.
        "$env:SystemDrive\inetpub\wwwroot\PSDSCPullServer\web.config"

    .PARAMETER OutputFolderPath
        Path to the Location where the MOF files should be published.
        This should be used when the PullServer is a SMB share pull server.
        (https://docs.microsoft.com/nl-nl/powershell/dsc/pull-server/pullserversmb)
        Defaults to $null

    .EXAMPLE
       Get-Module <ModuleName> | Publish-ModuleToPullServer

    .EXAMPLE
       Get-Module <ModuleName> | Publish-ModuleToPullServer -OutputFolderPath "\\Server01\DscService\Module"
#>
function Publish-ModuleToPullServer
{
    [CmdletBinding()]
    [OutputType([System.Void])]
    param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
        [System.String]
        $ModuleBase,

        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 2)]
        [Version]
        $Version,

        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
        [System.String]
        $PullServerWebConfig,

        [Parameter()]
        [System.String]
        $OutputFolderPath = $null
    )

    begin
    {
        if (-not($OutputFolderPath) -or -not (Test-Path -Path $OutputFolderPath))
        {
            if (-not(Test-Path -Path $PullServerWebConfig))
            {
                New-InvalidArgumentException `
                    -Message ($script:localizedData.InvalidWebConfigPathError -f $PullServerWebConfig) `
                    -ArgumentName 'PullServerWebConfig'
            }
            else
            {
                <#
                    Web.Config of Pull Server found so figure out the module path of the pullserver.
                    Use this value as output folder path.
                #>
                $webConfigXml = [System.Xml.XmlDocument] (Get-Content -Path $PullServerWebConfig)
                $moduleXElement = $webConfigXml.SelectNodes("//appSettings/add[@key = 'ModulePath']")
                $OutputFolderPath = $moduleXElement.Value
            }
        }
    }

    process
    {
        Write-Verbose -Message ($script:localizedData.PublishModuleMessage -f $Name, $Version, $ModuleBase)
        $targetPath = Join-Path -Path $OutputFolderPath -ChildPath "$($Name)_$($Version).zip"

        if (Test-Path -Path $targetPath)
        {
            Compress-Archive -DestinationPath $targetPath -Path "$($ModuleBase)\*" -Update
        }
        else
        {
            Compress-Archive -DestinationPath $targetPath -Path "$($ModuleBase)\*"
        }
    }

    end
    {
        # Now that all the modules are published generate their checksum.
        New-DscChecksum -Path $OutputFolderPath
    }
}

<#
    .SYNOPSIS
        Deploy DSC Configuration document to the pullserver.

    .DESCRIPTION
        Publish MOF file to the pullserver. It takes File Info object as
        pipeline input. It also auto detects the location of the configuration
        repository using the web.config of the pullserver.

    .PARAMETER FullName
        MOF File Name

    .PARAMETER PullServerWebConfig
        Path to the Pull Server web.config file, i.e.
        "$env:SystemDrive\inetpub\wwwroot\PSDSCPullServer\web.config"

    .PARAMETER OutputFolderPath
        Path to the Location where the MOF files should be published.
        This should be used when the PullServer is a SMB share pull server.
        (https://docs.microsoft.com/nl-nl/powershell/dsc/pull-server/pullserversmb)
        Defaults to $null

    .EXAMPLE
        Dir <path>\*.mof | Publish-MOFToPullServer

    .EXAMPLE
        Dir <path>\*.mof | Publish-MOFToPullServer -OutputFolderPath "\\Server01\DscService\Configuration"
#>
function Publish-MofToPullServer
{
    [CmdletBinding()]
    [OutputType([System.Void])]
    param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
        [System.String]
        $FullName,

        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
        [System.String]
        $PullServerWebConfig,

        [Parameter()]
        [System.String]
        $OutputFolderPath = $null
    )

    begin
    {
        if (-not($OutputFolderPath) -or -not (Test-Path -Path $OutputFolderPath))
        {
            <#
                Web.Config of Pull Server found so figure out the module path of the pullserver.
                Use this value as output folder path.
            #>
            $webConfigXml = [System.Xml.XmlDocument] (Get-Content -Path $PullServerWebConfig)
            $configXElement = $webConfigXml.SelectNodes("//appSettings/add[@key = 'ConfigurationPath']")
            $OutputFolderPath = $configXElement.Value
        }
    }

    process
    {
        $fileItem = Get-Item -Path $FullName

        if ($fileItem.Extension -eq '.mof')
        {
            Copy-Item -Path $FullName -Destination $OutputFolderPath -Force
        }
        else
        {
            New-InvalidArgumentException `
                -Message ($script:localizedData.InvalidFileTypeError -f $FullName) `
                -ArgumentName 'FullName'
        }
    }

    end
    {
        New-DscChecksum -Path $OutputFolderPath -Force
    }
}
