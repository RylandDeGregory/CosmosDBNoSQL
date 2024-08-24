function New-CosmosRequestAuthorizationSignature {
    <#
        .SYNOPSIS
            Generate Cosmos DB Master Key Authorization header for use with the NoSQL REST API.
        .DESCRIPTION
            Generate an Authorization header signature based on the Azure Cosmos DB REST API specification:
            https://learn.microsoft.com/en-us/rest/api/cosmos-db/access-control-on-cosmosdb-resources#constructkeytoken
        .EXAMPLE
            # Entra ID Authentication
            $AuthKeyParams = @{
                Method      = Post
                ResourceId  = "dbs/MyDatabase/colls/MyCollection"
                Date        = [DateTime]::UtcNow.ToString('r')
                AccessToken = (Get-AzAccessToken -ResourceUrl ($Endpoint -replace ':443\/?', '') -AsSecureString).Token
            }
            $Authorization = New-CosmosRequestAuthorizationSignature @AuthKeyParams
        .EXAMPLE
            # Master Key Authentication
            $AuthKeyParams = @{
                Method     = Post
                ResourceId = "dbs/MyDatabase/colls/MyCollection"
                Date       = [DateTime]::UtcNow.ToString('r')
                MasterKey  = $MasterKey
            }
            $Authorization = New-CosmosRequestAuthorizationSignature @AuthKeyParams
    #>
    [OutputType([string])]
    [CmdletBinding(DefaultParameterSetName = 'Master Key')]
    param (
        [Parameter(ParameterSetName = 'Entra ID', Mandatory)]
        [Parameter(ParameterSetName = 'Master Key', Mandatory)]
        [ValidateSet(
            'Get',
            'Post',
            'Put',
            'Patch',
            'Delete'
        )]
        [string] $Method,

        [Parameter(ParameterSetName = 'Entra ID', Mandatory)]
        [Parameter(ParameterSetName = 'Master Key', Mandatory)]
        [string] $ResourceId,

        [Parameter(ParameterSetName = 'Entra ID')]
        [Parameter(ParameterSetName = 'Master Key')]
        [string] $ResourceType = 'docs',

        [Parameter(ParameterSetName = 'Entra ID', Mandatory)]
        [Parameter(ParameterSetName = 'Master Key', Mandatory)]
        [string] $Date,

        [Parameter(ParameterSetName = 'Master Key', Mandatory)]
        [string] $MasterKey,

        [Parameter(ParameterSetName = 'Entra ID', Mandatory)]
        [securestring] $AccessToken
    )

    if ($AccessToken) {
        $KeyType = 'aad'
    } elseif ($MasterKey) {
        $KeyType = 'master'
    }

    $TokenVersion = '1.0'

    if ($KeyType -eq 'master') {
        try {
            # Generate Signature from the Master Key
            $SigningString = "$($Method.ToLower())`n$($ResourceType.ToLower())`n$ResourceId`n$($Date.ToString().ToLower())`n`n"
            $HmacSha       = [System.Security.Cryptography.HMACSHA256]@{ Key = [Convert]::FromBase64String($MasterKey) }
            $Signature     = [Convert]::ToBase64String($HmacSha.ComputeHash([Text.Encoding]::UTF8.GetBytes($SigningString)))
        } catch {
            throw "Error generating Cosmos DB NoSQL REST API Authorization signature from Master Key: $_"
        } finally {
            $HmacSha.Dispose()
        }
    } elseif ($KeyType -eq 'aad') {
        # Signature is the Entra ID Access Token
        $Signature = (New-Object System.Management.Automation.PSCredential ('null', $AccessToken)).GetNetworkCredential().Password
    }

    try {
        # Url Encode the Authorization string
        $AuthorizationString = [System.Web.HttpUtility]::UrlEncode('type=' + $KeyType + '&ver=' + $TokenVersion + '&sig=' + $Signature)
    } catch {
        throw "Error URL encoding Cosmos DB NoSQL REST API Authorization signature: $_"
    }

    Write-Verbose "Generated [$KeyType] Authorization header for a [$Method] request against Cosmos DB NoSQL Collection [$ResourceId]"

    return $AuthorizationString
}