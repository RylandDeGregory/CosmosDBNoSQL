function New-CosmosMasterKeyAuthorizationSignature {
    <#
        .SYNOPSIS
            Generate Cosmos DB Master Key Authentication header for use with the NoSQL REST API.
        .DESCRIPTION
            Generate an Authentication header based on the Azure Cosmos DB REST API specification:
            https://learn.microsoft.com/en-us/rest/api/cosmos-db/access-control-on-cosmosdb-resources#constructkeytoken
        .EXAMPLE
            $AuthKeyParams = @{
                Method     = Post
                ResourceId = "dbs/$DatabaseId/colls/$CollectionId"
                Date       = [DateTime]::UtcNow.ToString('r')
                MasterKey  = $MasterKey
            }
            $AuthorizationKey = New-CosmosMasterKeyAuthorizationSignature @AuthKeyParams
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet(
            'Get',
            'Post',
            'Put',
            'Patch',
            'Delete'
        )]
        [string] $Method,

        [Parameter(Mandatory)]
        [string] $ResourceId,

        [Parameter()]
        [string] $ResourceType = 'docs',

        [Parameter(Mandatory)]
        [string] $Date,

        [Parameter(Mandatory)]
        [string] $MasterKey
    )

    $KeyType      = 'master'
    $TokenVersion = '1.0'

    Write-Verbose "Generating Master Key Authentication header for a [$Method] request against Collection [$ResourceId]"

    $SigningString        = "$($Method.ToLower())`n$($ResourceType.ToLower())`n$ResourceId`n$($Date.ToString().ToLower())`n`n"
    $HmacSha              = [System.Security.Cryptography.HMACSHA256]@{ Key = [Convert]::FromBase64String($MasterKey) }
    $Signature            = [Convert]::ToBase64String($HmacSha.ComputeHash([Text.Encoding]::UTF8.GetBytes($SigningString)))
    $AuthorizationString  = [System.Web.HttpUtility]::UrlEncode('type=' + $KeyType + '&ver=' + $TokenVersion + '&sig=' + $Signature)
    $HmacSha.Dispose()

    return $AuthorizationString
}