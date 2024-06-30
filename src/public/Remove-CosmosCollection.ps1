function Get-CosmosCollection {
    <#
        .SYNOPSIS
            Remove a Cosmos DB collection with the provided name.
        .DESCRIPTION
            Delete a Cosmos DB collection by name. See: https://learn.microsoft.com/en-us/rest/api/cosmos-db/delete-a-collection
        .LINK
            New-CosmosRequestAuthorizationSignature
        .EXAMPLE
            # Master Key Authentication
            $RemoveCollectionParams = @{
                Endpoint     = 'https://xxxxx.documents.azure.com:443/'
                MasterKey    = $MasterKey
                ResourceId   = "dbs/$DatabaseId"
                CollectionId = 'MyCollection'
            }
            Remove-CosmosCollection @GetCollectionParams
        .EXAMPLE
            # Entra ID Authentication
            $RemoveCollectionParams = @{
                Endpoint     = 'https://xxxxx.documents.azure.com:443/'
                AccessToken  = (Get-AzAccessToken -ResourceUrl ($Endpoint -replace ':443\/?', '')).Token
                ResourceId   = "dbs/$DatabaseId"
                CollectionId = 'MyCollection'
            }
            Remove-CosmosCollection @GetCollectionParams
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding(DefaultParameterSetName = 'Master Key')]
    param (
        [Parameter(ParameterSetName = 'Entra ID', Mandatory)]
        [Parameter(ParameterSetName = 'Master Key', Mandatory)]
        [string] $Endpoint,

        [Parameter(ParameterSetName = 'Master Key', Mandatory)]
        [string] $MasterKey,

        [Parameter(ParameterSetName = 'Entra ID', Mandatory)]
        [string] $AccessToken,

        [Parameter(ParameterSetName = 'Entra ID', Mandatory)]
        [Parameter(ParameterSetName = 'Master Key', Mandatory)]
        [string] $ResourceId,

        [Parameter(ParameterSetName = 'Entra ID')]
        [Parameter(ParameterSetName = 'Master Key')]
        [string] $ResourceType = 'colls',

        [Parameter(ParameterSetName = 'Entra ID', Mandatory)]
        [Parameter(ParameterSetName = 'Master Key', Mandatory)]
        [string] $CollectionId
    )

    # Calculate current date for use in Authorization header
    $private:Date = [DateTime]::UtcNow.ToString('r')

    # Compute Authorization header value and define headers dictionary
    $AuthorizationParameters = @{
        Date         = $private:Date
        Method       = 'Delete'
        ResourceId   = $ResourceId
        ResourceType = $ResourceType
    }
    if ($MasterKey) {
        $AuthorizationParameters += @{ MasterKey = $MasterKey }
    } elseif ($AccessToken) {
        $AuthorizationParameters += @{ AccessToken = $AccessToken }
    }
    $private:Authorization = New-CosmosRequestAuthorizationSignature @AuthorizationParameters

    $private:Headers = @{
        'accept'        = 'application/json'
        'authorization' = $private:Authorization
        'content-type'  = 'application/json'
        'x-ms-date'     = $private:Date
        'x-ms-version'  = '2018-12-31'
    }

    # Define request URI
    $private:RequestUri = "$Endpoint/$ResourceId/$ResourceType/$CollectionId" -replace '(?<!(http:|https:))//+', '/'

    # Send request to NoSQL REST API
    try {
        $ProgressPreference = 'SilentlyContinue'
        Write-Verbose "Remove Cosmos DB NosQL Collection with ID [$CollectionId] in Database [$ResourceId]"
        $null = Invoke-RestMethod -Method Delete -Uri $private:RequestUri -Headers $private:Headers
        $ProgressPreference = 'Continue'
    } catch {
        Write-Error "StatusCode: $($_.Exception.Response.StatusCode.value__) | ExceptionMessage: $($_.Exception.Message) | $_"
    }
}