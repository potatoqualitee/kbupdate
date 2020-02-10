function Set-PSWSUSConfigProduct {
<#
.SYNOPSIS  
    Sets whether the product representing the category of updates to synchronize is enabled or disabled.
    
.DESCRIPTION
    The Set-PSWSUSProduct cmdlet enables or disables the product representing the category of updates to synchronized.
    In order to use this cmdlet, the Get-PSWSUSUpdateCategory cmdlet must be run (optionally using the Where-Object cmdlet to
    filter its results) with its results piped into this cmdlet.
    
.PARAMETER Product
    Specifies the product for which the updates are to be synchronized. If the Disable parameter is used, then this parameter
    specifies the product for which the updates are not to be synchronized. This parameter value is piped from the Get-PSWSUSUpdateCategory cmdlet.
    
.PARAMETER Disable
    Specifies that updates are not to be synchronized for the specified product.
        
.NOTES  
    Name: Set-PSWSUSConfigProduct
    Author: Dubinsky Evgeny
    DateCreated: 10MAY2013]
    Modified 05 Feb 2014 -- Boe Prox
        -Add -WhatIf support
        
.EXAMPLE
    Get-PSWSUSUpdateCategory | where { $_.Title -in @(
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
    )} | Set-PSWSUSConfigProduct
    
    Description
    -----------
    This command will choose Products that you will synchronize from MS Windows Update.

.EXAMPLE
    Get-PSWSUSUpdateCategory | where {$_.Title -eq "Silverlight"} | Set-PSWSUSConfigProduct -Disable
    
    Description
    -----------
    This command will disable Silverlight product from synchronize with MS Windows Update.

.LINK
    http://blog.itstuff.in.ua/?p=62#Set-PSWSUSConfigProduct
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
        if (-NOT $wsus)
        {
            Write-Warning "Use Connect-PSWSUSServer to establish connection with your Windows Update Server."
            Break
        }
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
    Process
    {            
        foreach ($ProductObject in $Product)
        {
            If ($PSCmdlet.ShouldProcess($productobject,'Set Configuration Product')) {
                if($PSBoundParameters['Disable'])
                {
                    $ProductTitle = $ProductObject.Title
                    $ProductType = $ProductObject.Type
                    if ($Collection.Title -notcontains $ProductTitle)
                    {
                        Write-Warning "$ProductType $ProductTitle not enable."
                    }
                    else
                    {
                        $Product | ForEach { 
                            $Collection.Remove($_) 
                        } 
                    }
                }
                else
                {
                    $Collection.Add($productobject) | Out-Null
                }
            }
        }
        
    }
    End
    {
        If ($PSCmdlet.ShouldProcess($wsus.ServerName,'Set Configuration Product')) {
            $Subscription.SetUpdateCategories($Collection)
            $Subscription.Save()
        }
    }
}
