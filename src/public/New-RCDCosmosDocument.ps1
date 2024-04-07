function New-RCDCosmosDocument {
    <#
        .SYNOPSIS
            Create a new Cosmos DB NoSQL API document using the REST API. Uses Master Key Authentication.
        .LINK
            New-RCDCosmosMasterKeyAuthorizationSignature
        .EXAMPLE
            $NewDocParams = @{
                Endpoint          = 'https://xxxxx.documents.azure.com:443/'
                MasterKey         = $MasterKey
                ResourceId        = "dbs/$DatabaseId/colls/$CollectionId"
                PartitionKey      = $PartitionKey
                PartitionKeyValue = $PartitionKeyValue
                Document          = @{property1 = 'value1'; property2 = @('value1', 'value2')} # Any valid PSObject or hashtable
                DocumentId        = (New-Guid).Guid
            }
            New-RCDCosmosDocument @NewDocParams
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
        [string] $PartitionKey,

        [Parameter(Mandatory)]
        [string] $PartitionKeyValue,

        [Parameter(Mandatory)]
        [psobject] $Document,

        [Parameter(Mandatory)]
        [string] $DocumentId,

        # Whether to treat the insert operation as an update
        # if the Document ID already exists in the Collection
        [Parameter()]
        [boolean] $IsUpsert = $true,

        # Whether to hash the Document ID before adding to Cosmos DB
        [Parameter()]
        [boolean] $HashDocumentId = $true
    )

    # Calculate current date for use in Authorization header
    $Date = [DateTime]::UtcNow.ToString('r')

    # Compute Authorization header value and define headers dictionary
    $AuthorizationKey = New-RCDCosmosMasterKeyAuthorizationSignature -Method Post -ResourceId $ResourceId -Date $Date -MasterKey $MasterKey
    $Headers = @{
        'accept'                       = 'application/json'
        'authorization'                = $AuthorizationKey
        'cache-control'                = 'no-cache'
        'content-type'                 = 'application/json'
        'x-ms-date'                    = $Date
        'x-ms-documentdb-partitionkey' = "[`"$PartitionKeyValue`"]"
        'x-ms-version'                 = '2018-12-31'
    }
    if ($IsUpsert) {
        $Headers += @{ 'x-ms-documentdb-is-upsert' = $true }
    }
    if ($HashDocumentId) {
        $DocumentId = New-Sha256HashedString -String $DocumentId
    }

    # Add Partition Key
    Add-Member -InputObject $Document -MemberType NoteProperty -Name $PartitionKey -Value $PartitionKeyValue

    # Add Document ID
    if ($Document.id) {
        $Document.PSObject.Properties.Remove('id')
    }
    Add-Member -InputObject $Document -MemberType NoteProperty -Name 'id' -Value $DocumentId

    # Send request to NoSQL REST API
    try {
        $Response = Invoke-RestMethod -Uri "$Endpoint$ResourceId/$ResourceType" -Headers $Headers -Method Post -Body ($Document | ConvertTo-Json -Depth 15)
        @{
            etag              = $Response.'_etag'
            id                = $Response.id
            partitionKey      = $PartitionKey
            partitionKeyValue = $Response.partitionKey
            timestamp         = $Response.'_ts'
        }
    } catch {
        Write-Error "StatusCode: $($_.Exception.Response.StatusCode.value__) | ExceptionMessage: $($_.Exception.Message) | $_"
    }
}