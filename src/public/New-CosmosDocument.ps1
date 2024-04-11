function New-CosmosDocument {
    <#
        .SYNOPSIS
            Create a new Cosmos DB NoSQL API document using the REST API. Uses Master Key or Entra ID Authentication.
        .DESCRIPTION
            Insert a Cosmos DB NoSQL document. See: https://learn.microsoft.com/en-us/rest/api/cosmos-db/create-a-document
        .LINK
            New-CosmosRequestAuthorizationSignature
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
            New-CosmosDocument @NewDocParams
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
        [string] $ResourceType = 'docs',

        [Parameter(ParameterSetName = 'Entra ID', Mandatory)]
        [Parameter(ParameterSetName = 'Master Key', Mandatory)]
        [string] $PartitionKey,

        [Parameter(ParameterSetName = 'Entra ID', Mandatory)]
        [Parameter(ParameterSetName = 'Master Key', Mandatory)]
        [string] $PartitionKeyValue,

        [Parameter(ParameterSetName = 'Entra ID', Mandatory)]
        [Parameter(ParameterSetName = 'Master Key', Mandatory)]
        [pscustomobject] $Document,

        [Parameter(ParameterSetName = 'Entra ID', Mandatory)]
        [Parameter(ParameterSetName = 'Master Key', Mandatory)]
        [string] $DocumentId,

        # Whether to treat the insert operation as an update
        # if the Document ID already exists in the Collection
        [Parameter(ParameterSetName = 'Entra ID')]
        [Parameter(ParameterSetName = 'Master Key')]
        [boolean] $IsUpsert = $true,

        # Whether to hash the Document ID before adding to Cosmos DB
        [Parameter(ParameterSetName = 'Entra ID')]
        [Parameter(ParameterSetName = 'Master Key')]
        [boolean] $HashDocumentId = $true,

        # Max depth of the JSON object that will be added to Cosmos DB
        [Parameter(ParameterSetName = 'Entra ID')]
        [Parameter(ParameterSetName = 'Master Key')]
        [ValidateRange(0, 100)]
        [int] $JsonDocumentDepth = 15
    )

    # Calculate current date for use in Authorization header
    $Date = [DateTime]::UtcNow.ToString('r')

    # Compute Authorization header value and define headers dictionary
    $AuthorizationParameters = @{
        Date       = $Date
        Method     = 'Post'
        ResourceId = $ResourceId
    }
    if ($MasterKey) {
        $AuthorizationParameters += @{ MasterKey = $MasterKey }
    } elseif ($AccessToken) {
        $AuthorizationParameters += @{ AccessToken = $AccessToken }
    }
    $Authorization = New-CosmosRequestAuthorizationSignature @AuthorizationParameters

    $Headers = @{
        'accept'                       = 'application/json'
        'authorization'                = $Authorization
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
    try {
        Write-Verbose 'Add PartitionKey property to document'
        Add-Member -InputObject $Document -MemberType NoteProperty -Name $PartitionKey -Value $PartitionKeyValue
    }
    catch {
        Write-Error "Error adding PartitionKey property to document: $_"
    }

    # Add Document ID
    try {
        if ($Document.id) {
            Write-Verbose 'Remove existing ID property from PSCustomObject'
            $Document.PSObject.Properties.Remove('id')
        }
        Write-Verbose 'Add ID property with provided DocumentId value to document'
        Add-Member -InputObject $Document -MemberType NoteProperty -Name 'id' -Value $DocumentId
    } catch {
        Write-Error "Error adding or updating ID property of document: $_"
    }

    # Send request to NoSQL REST API
    try {
        Write-Verbose "Insert Cosmos DB NosQL document with ID [$DocumentId] into Collection [$ResourceId]"
        $Response = Invoke-RestMethod -Method Post -Uri "$Endpoint$ResourceId/$ResourceType/$DocumentId" -Headers $Headers -Body ($Document | ConvertTo-Json -Depth $JsonDocumentDepth)
        $OutputObject = [pscustomobject]@{
            etag              = $Response.'_etag'
            id                = $Response.id
            partitionKey      = $PartitionKey
            partitionKeyValue = $Response.partitionKey
            timestamp         = $Response.'_ts'
        }

        return $OutputObject
    } catch {
        Write-Error "StatusCode: $($_.Exception.Response.StatusCode.value__) | ExceptionMessage: $($_.Exception.Message) | $_"
    }
}