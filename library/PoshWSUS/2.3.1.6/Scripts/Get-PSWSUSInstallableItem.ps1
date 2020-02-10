function Get-PSWSUSInstallableItem {
    <#  
    .SYNOPSIS  
        Retrieve a collection of installable items related to an update or updates.
        
    .DESCRIPTION
        Retrieve a collection of installable items related to an update or updates.
        
    .PARAMETER InputObject
        Update object/s to get list of installable items
           
    .PARAMETER UpdateName
        Name of update to get list of installable items.          
            
    .NOTES  
        Name: Get-PSWSUSInstallableItem 
        Author: Boe Prox
        DateCreated: 14NOV2011
               
    .LINK  
        https://learn-powershell.net
        
    .EXAMPLE  
    Get-PSWSUSInstallableItem -UpdateName 2617986
    KnowledgeBaseArticles : {2617986}
    Title                 : Microsoft Silverlight (KB2617986)
    Id                    : Microsoft.UpdateServices.Administration.UpdateRevisionId
    Languages             : {all}
    Files                 : {silverlighteulapriv-no-717c6af4-d907-42d7-9375-2ca8f225f953.txt, silverlighteulapriv-hr-717c6af4-d907-42d7-9375-2ca8f225f953
                            .txt, silverlighteulapriv-ar-717c6af4-d907-42d7-9375-2ca8f225f953.txt, silverlighteulapriv-he-717c6af4-d907-42d7-9375-2ca8f22
                            5f953.txt...}

    KnowledgeBaseArticles : {2617986}
    Title                 : Microsoft Silverlight (KB2617986)
    Id                    : Microsoft.UpdateServices.Administration.UpdateRevisionId
    Languages             : {all}
    Files                 : {Silverlight.exe}

    KnowledgeBaseArticles : {2617986}
    Title                 : Security Update for Microsoft Silverlight (KB2617986)
    Id                    : Microsoft.UpdateServices.Administration.UpdateRevisionId
    Languages             : {all}
    Files                 : {Silverlight.exe}

    KnowledgeBaseArticles : {2617986}
    Title                 : Security Update for Microsoft Silverlight (KB2617986)
    Id                    : Microsoft.UpdateServices.Administration.UpdateRevisionId
    Languages             : {all}
    Files                 : {Silverlight_Developer.exe}

    Description
    -----------
    Lists all of the installable items for KB2617986      
    
    .EXAMPLE
    Get-PSWSUSUpdate -Update 2607712 | Get-PSWSUSInstallableItem | Format-Table
    KnowledgeBaseArticles                 Id                                    Languages                            Files
    ---------------------                 --                                    ---------                            -----
    {2607712}                             Microsoft.UpdateServices.Administr... {all}                                {windows6.1-kb2607712-x86.cab}
    {2607712}                             Microsoft.UpdateServices.Administr... {all}                                {windows6.1-kb2607712-x64.cab}
    {2607712}                             Microsoft.UpdateServices.Administr... {pt}                                 {windowsserver2003-kb2607712-x86-...
    {2607712}                             Microsoft.UpdateServices.Administr... {es}                                 {windowsserver2003-kb2607712-x86-...
    {2607712}                             Microsoft.UpdateServices.Administr... {it}                                 {windowsserver2003-kb2607712-x86-...
    {2607712}                             Microsoft.UpdateServices.Administr... {cs}                                 {windowsserver2003-kb2607712-x86-...
    {2607712}                             Microsoft.UpdateServices.Administr... {pl}                                 {windowsserver2003-kb2607712-x86-...
    {2607712}                             Microsoft.UpdateServices.Administr... {pt-br}                              {windowsserver2003-kb2607712-x86-...
    {2607712}                             Microsoft.UpdateServices.Administr... {hu}                                 {windowsserver2003-kb2607712-x86-...
    {2607712}                             Microsoft.UpdateServices.Administr... {nl}                                 {windowsserver2003-kb2607712-x86-...
    {2607712}                             Microsoft.UpdateServices.Administr... {zh-tw}                              {windowsserver2003-kb2607712-x86-...
    {2607712}                             Microsoft.UpdateServices.Administr... {fr}                                 {windowsserver2003-kb2607712-x86-...
    {2607712}                             Microsoft.UpdateServices.Administr... {en}                                 {windowsserver2003-kb2607712-x86-...
    {2607712}                             Microsoft.UpdateServices.Administr... {de}                                 {windowsserver2003-kb2607712-x86-...
    {2607712}                             Microsoft.UpdateServices.Administr... {sv}                                 {windowsserver2003-kb2607712-x86-...
    {2607712}                             Microsoft.UpdateServices.Administr... {tr}                                 {windowsserver2003-kb2607712-x86-...
    {2607712}                             Microsoft.UpdateServices.Administr... {zh-cn}                              {windowsserver2003-kb2607712-x86-...
    {2607712}                             Microsoft.UpdateServices.Administr... {ja}                                 {windowsserver2003-kb2607712-x86-...    
    ... 
    
    Description
    -----------
    Example showing that Get-PSWSUSInstallableItem accepts the pipleline result from Get-PSWSUSUpdate to locate the installable items.
    #> 
    [cmdletbinding(
    	DefaultParameterSetName = 'Name'
    )]
    Param(
        [Parameter(            
            Mandatory = $False,
            Position = 0,
            ParameterSetName = 'object',
            ValueFromPipeline = $True)]
            [system.object]
            [ValidateNotNullOrEmpty()]
            $InputObject,     
        [Parameter(
            Mandatory = $False,
            Position = 0,
            ParameterSetName = 'Name',
            ValueFromPipeline = $True)]
            [string]$UpdateName                                
        )                   
    Process {
        #Perform appropriate action based on Parameter set name
        Switch ($pscmdlet.ParameterSetName) {            
            "object" {
                Write-Verbose "Using 'Collection' set name"
                #Change the variable that will hold the objects
                $patches = $inputobject    
            }                
            "name" {
                if($wsus)
                {
                    Write-Verbose "Using 'String' set name"
                    #Search for updates
                    Write-Verbose "Searching for update/s"
                    $patches = @($wsus.SearchUpdates($UpdateName))
                    If ($patches -eq 0) {
                        Write-Error "Update $update could not be found in WSUS!"
                        Break
                    }
                }#endif
                else
                {
                    Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server"
                    Break
                }                     
            }
            Default {
                Write-Warning "An error occurred while processing this request!"
            }                
        } 
        ForEach ($patch in $patches) {
            Write-Verbose ("Getting installable items on {0}" -f $patch.Title)
            Try {
                $data = $Patch.GetInstallableItems() | Add-Member -MemberType NoteProperty -Name KnowledgeBaseArticles -value $Patch.KnowledgeBaseArticles -PassThru
                $data | Add-Member -MemberType NoteProperty -Name Title -value $Patch.Title -PassThru
            } Catch {
                Write-Warning ("{0}: {1}" -f $patch.Title,$_.Exception.Message)
            }
        }
    }              
} 
