function Remove-CosmosDocument {
    <#
        .SYNOPSIS
            Remove a Cosmos DB NoSQL API document using the REST API. Uses Master Key Authentication.
        .LINK
            New-CosmosMasterKeyAuthorizationSignature
        .EXAMPLE
            $RemoveDocParams = @{
                Endpoint          = 'https://xxxxx.documents.azure.com:443/'
                MasterKey         = $MasterKey
                ResourceId        = "dbs/$DatabaseId/colls/$CollectionId"
                PartitionKeyValue = $PartitionKeyValue
                DocumentId        = $DocumentId
            }
            Remove-CosmosDocument @RemoveDocParams
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $Endpoint,

        [Parameter(Mandatory)]
        [string] $MasterKey,

        [Parameter(Mandatory)]
        [string] $ResourceId,

        [Parameter()]
        [string] $ResourceType = 'docs',

        [Parameter(Mandatory)]
        [string] $PartitionKeyValue,

        [Parameter(Mandatory)]
        [string] $DocumentId
    )

    # Calculate current date for use in Authorization header
    $Date = [DateTime]::UtcNow.ToString('r')

    # Compute Authorization header value and define headers dictionary
    $AuthorizationKey = New-CosmosMasterKeyAuthorizationSignature -Method Delete -ResourceId "$ResourceId/$ResourceType/$DocumentId" -Date $Date -MasterKey $MasterKey
    $Headers = @{
        'accept'                       = 'application/json'
        'authorization'                = $AuthorizationKey
        'cache-control'                = 'no-cache'
        'content-type'                 = 'application/json'
        'x-ms-date'                    = $Date
        'x-ms-documentdb-partitionkey' = "[`"$PartitionKeyValue`"]"
        'x-ms-version'                 = '2018-12-31'
    }

    # Send request to NoSQL REST API
    try {
        Invoke-RestMethod -Uri "$Endpoint$ResourceId/$ResourceType/$DocumentId" -Headers $Headers -Method Delete
    } catch {
        Write-Error "StatusCode: $($_.Exception.Response.StatusCode.value__) | ExceptionMessage: $($_.Exception.Message) | $_"
    }
}