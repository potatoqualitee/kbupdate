function Set-PoshWSUSProduct {
    
    <#
    .SYNOPSIS  
        Sets whether the product representing the category of updates to synchronize is enabled or disabled.
    
    .DESCRIPTION
        The Set-PoshWSUSProduct cmdlet enables or disables the product representing the category of updates to synchronized.
        In order to use this cmdlet, the Get-PoshWSUSUpdateCategory cmdlet must be run (optionally using the Where-Object cmdlet to
        filter its results) with its results piped into this cmdlet.
    
    .PARAMETER Product
        Specifies the product for which the updates are to be synchronized. If the Disable parameter is used, then this parameter
        specifies the product for which the updates are not to be synchronized. This parameter value is piped from the Get-PoshWSUSUpdateCategory cmdlet.
    
    .PARAMETER Disable
        Specifies that updates are not to be synchronized for the specified product.
        
    .NOTES  
        Name: Set-PoshWSUSProduct
        Author: Dubinsky Evgeny
        DateCreated: 10MAY2013
        
    .EXAMPLE
        Get-PoshWSUSUpdateCategory | where { $_.Title -in @(
            'Office 2010',
            'Office 2013',
            'Windows 7',
            'Windows 8',
            'Windows Server 2008 R2',
            'Windows Server 2008',
            'Windows Server 2012 Language Packs',
            'Windows Server 2012',
            'Windows XP'
            'Silverlight'
        )} | Set-PoshWSUSProduct
    
        Description
        -----------
        This command will choose Products that you will synchronize from MS Windows Update.

    .EXAMPLE
        Get-PoshWSUSUpdateCategory | where {$_.Title -eq "Silverlight"} | Set-PoshWSUSProduct -Disable
    
        Description
        -----------
        This command will disable Silverlight product from synchronize with MS Windows Update.
    #>
    [CmdletBinding()]
    Param
    (
        [Parameter(
            Mandatory = $True,
            Position = 0,
            ValueFromPipeline = $True)]
            [Microsoft.UpdateServices.Internal.BaseApi.UpdateCategory]$Product,
        [Parameter(
            Mandatory = $false,
            Position = 1,
            ValueFromPipeline = $false)]
            [switch]$Disable
    )

    Begin
    {
        if ($wsus)
        {
            if($PSBoundParameters['Disable'])
            {
                $Collection = $wsus.GetSubscription().GetUpdateCategories()
            }
            else 
            {
                $Collection = New-Object -TypeName Microsoft.UpdateServices.Administration.UpdateCategoryCollection
                
            }
            $Subscription = $wsus.GetSubscription()
        }
        else
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server."
            Break
        }

    }
    Process
    {            
        if($PSBoundParameters['Disable'])
        {
            foreach ($ProductObject in $Product)
            {
                $ProductTitle = $ProductObject.Title
                $ProductType = $ProductObject.Type
                if ($Collection -notcontains $ProductTitle)
                {
                    Write-Warning "$ProductType $ProductTitle not enable."
                }
                else
                {
                    $Product | % { $Collection.Remove($_) } 
                }
            }
        }
        else 
        {
            $Product | % { $Collection.Add($_) | Out-Null }
        }
        $Subscription.SetUpdateCategories($Collection)
    }
    End
    {
        $Subscription.Save()
    }
}
