function Get-PSWSUSUpdateFile {
    <#  
    .SYNOPSIS  
        Gets the files associated with a specific update or updates.
        
    .DESCRIPTION
        Gets the files associated with a specific update or updates.
        
    .PARAMETER InputObject
        Input object that will be used to locate files. Can be an update object or installablefile object.
           
    .PARAMETER UpdateName
         Name of the Update to check files.
            
    .NOTES  
        Name: Get-PSWSUSUpdateFile
        Author: Boe Prox
        DateCreated: 14NOV2011
               
    .LINK  
        https://learn-powershell.net
        
    .EXAMPLE  
    Get-PSWSUSUpdateFile -UpdateName 2617986
    KnowledgeBaseArticles : {2617986}
    Title                 : Microsoft Silverlight (KB2617986)
    Name                  : silverlighteulapriv-no-717c6af4-d907-42d7-9375-2ca8f225f953.txt
    Modified              : 7/13/2011 12:23:50 PM
    FileUri               : http://j23/Content/86/05AC83F66123073A61E4CF897430FA73F37DD486.txt
    OriginUri             : http://download.windowsupdate.com/msdownload/update/v5/eula/silverlighteulapriv-no-717c6af4-d907-42d7-9375-2ca8f225f953.txt
    TotalBytes            : 40450
    Type                  : None
    IsEula                : True
    Hash                  : {5, 172, 131, 246...}

    KnowledgeBaseArticles : {2617986}
    Title                 : Microsoft Silverlight (KB2617986)
    Name                  : silverlighteulapriv-hr-717c6af4-d907-42d7-9375-2ca8f225f953.txt
    Modified              : 7/13/2011 12:23:50 PM
    FileUri               : http://j23/Content/7A/102BE952441D9A72F7A142F685E127B2C3857B7A.txt
    OriginUri             : http://download.windowsupdate.com/msdownload/update/v5/eula/silverlighteulapriv-hr-717c6af4-d907-42d7-9375-2ca8f225f953.txt
    TotalBytes            : 42154
    Type                  : None
    IsEula                : True
    Hash                  : {16, 43, 233, 82...}

    KnowledgeBaseArticles : {2617986}
    Title                 : Microsoft Silverlight (KB2617986)
    Name                  : silverlighteulapriv-ar-717c6af4-d907-42d7-9375-2ca8f225f953.txt
    Modified              : 7/13/2011 12:23:50 PM
    FileUri               : http://j23/Content/5F/1B3E1C2D3E0FEA562C9EAFCD697D2709B15C6F5F.txt
    OriginUri             : http://download.windowsupdate.com/msdownload/update/v5/eula/silverlighteulapriv-ar-717c6af4-d907-42d7-9375-2ca8f225f953.txt
    TotalBytes            : 35806
    Type                  : None
    IsEula                : True
    Hash                  : {27, 62, 28, 45...}   
    
    Description
    -----------
    Gets the files relating to KB update 2617986.
    
    .EXAMPLE
    Get-PSWSUSUpdate -Update 2617986 | Select -First 1 | Get-PSWSUSInstallableItem | Select -First 1  | Get-PSWSUSUpdateFile
    KnowledgeBaseArticles     Name                                                            FileURI                        TotalBytes
    ---------------------     ----                                                            -------                        ----------
    {2617986}                 silverlighteulapriv-no-717c6af4-d907-42d7-9375-2ca8f225f953.txt http://j23/Content/86/05AC8...      40450
    {2617986}                 silverlighteulapriv-hr-717c6af4-d907-42d7-9375-2ca8f225f953.txt http://j23/Content/7A/102BE...      42154
    {2617986}                 silverlighteulapriv-ar-717c6af4-d907-42d7-9375-2ca8f225f953.txt http://j23/Content/5F/1B3E1...      35806
    {2617986}                 silverlighteulapriv-he-717c6af4-d907-42d7-9375-2ca8f225f953.txt http://j23/Content/C6/267F4...      31410
    {2617986}                 silverlighteulapriv-ko-717c6af4-d907-42d7-9375-2ca8f225f953.txt http://j23/Content/8B/2F335...      22202
    {2617986}                 silverlighteulapriv-en-717c6af4-d907-42d7-9375-2ca8f225f953.txt http://j23/Content/13/33D8A...      39084
    {2617986}                 silverlighteulapriv-hu-717c6af4-d907-42d7-9375-2ca8f225f953.txt http://j23/Content/8D/362C2...      46322
    {2617986}                 silverlighteulapriv-cs-717c6af4-d907-42d7-9375-2ca8f225f953.txt http://j23/Content/D4/377F4...      42314
    {2617986}                 silverlighteulapriv-nl-717c6af4-d907-42d7-9375-2ca8f225f953.txt http://j23/Content/8F/3ACF3...      45342
    {2617986}                 silverlighteulapriv-tr-717c6af4-d907-42d7-9375-2ca8f225f953.txt http://j23/Content/7C/3BC60...      43098
    {2617986}                 silverlighteulapriv-bg-717c6af4-d907-42d7-9375-2ca8f225f953.txt http://j23/Content/0C/45495...      43420
    {2617986}                 silverlighteulapriv-pl-717c6af4-d907-42d7-9375-2ca8f225f953.txt http://j23/Content/51/4DD86...      49774
    {2617986}                 silverlighteulapriv-pt-717c6af4-d907-42d7-9375-2ca8f225f953.txt http://j23/Content/96/64E31...      45660
    {2617986}                 silverlighteulapriv-ja-717c6af4-d907-42d7-9375-2ca8f225f953.txt http://j23/Content/72/73A08...      23150
    {2617986}                 silverlighteulapriv-sk-717c6af4-d907-42d7-9375-2ca8f225f953.txt http://j23/Content/83/78FDE...      43846
    {2617986}                 silverlighteulapriv-sl-717c6af4-d907-42d7-9375-2ca8f225f953.txt http://j23/Content/13/7F990...      43710
    {2617986}                 silverlighteulapriv-fi-717c6af4-d907-42d7-9375-2ca8f225f953.txt http://j23/Content/23/83632...      43826
    {2617986}                 silverlighteulapriv-th-717c6af4-d907-42d7-9375-2ca8f225f953.txt http://j23/Content/21/8C7DE...      38626
    ...        
    
    Description
    -----------
    Accepts pipeline input using Get-PSWSUSUPdate and Get-PSWSUSInstallable Item to list the files that are used by the update.

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
                If ($InputObject -is [Microsoft.UpdateServices.Internal.BaseApi.Update]) {
                    $Items = $InputObject | ForEach {
                        $data = $_.GetInstallableItems() | Add-Member -MemberType NoteProperty -Name KnowledgeBaseArticles -value $_.KnowledgeBaseArticles -PassThru
                        $data | Add-Member -MemberType NoteProperty -Name Title -value $_.Title -PassThru
                    }
                } ElseIf ($InputObject -is [Microsoft.UpdateServices.Internal.BaseApi.InstallableItem]) {
                    $Items = $InputObject
                }   
            }                
            "name" {
                if($wsus)
                {
                    Write-Verbose "Using 'Update Name' set name"
                    #Search for updates
                    Write-Verbose "Searching for update/s"
                    $patches = @($wsus.SearchUpdates($UpdateName))
                    If ($patches -eq 0) {
                        Write-Error "Update $update could not be found in WSUS!"
                        Break
                    } Else {
                        $Items = $patches | ForEach {
                            $Patch = $_
                            Write-Verbose ("Adding NoteProperty for {0}" -f $_.Title)                    
                            $_.GetInstallableItems() | ForEach {
                                $itemdata = $_ | Add-Member -MemberType NoteProperty -Name KnowledgeBaseArticles -value $patch.KnowledgeBaseArticles -PassThru
                                $itemdata | Add-Member -MemberType NoteProperty -Name Title -value $patch.Title -PassThru
                            }
                        }                
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
        ForEach ($item in $items) {
            Write-Verbose ("Getting installable items on {0}" -f $item.Title)
            Try {
                $filedata = $item | Select -Expand Files | Add-Member -MemberType NoteProperty -Name KnowledgeBaseArticles -value $item.KnowledgeBaseArticles -PassThru
                $filedata | Add-Member -MemberType NoteProperty -Name Title -value $item.Title -PassThru
            } Catch {
                Write-Warning ("{0}: {1}" -f $item.id.id,$_.Exception.Message)
            }
        }
    }              
} 
