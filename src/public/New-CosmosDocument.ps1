function New-CosmosDocument {
    <#
        .SYNOPSIS
            Create a new Cosmos DB NoSQL API document using the REST API. Uses Master Key or Entra ID Authentication.
        .DESCRIPTION
            Insert a Cosmos DB NoSQL document. See: https://learn.microsoft.com/en-us/rest/api/cosmos-db/create-a-document
        .LINK
            New-CosmosRequestAuthorizationSignature
        .EXAMPLE
            # Master Key Authentication
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
        .EXAMPLE
            # Entra ID Authentication
            $NewDocParams = @{
                Endpoint          = 'https://xxxxx.documents.azure.com:443/'
                AccessToken       = (Get-AzAccessToken -ResourceUrl ($Endpoint -replace ':443\/?', '')).Token
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
        [boolean] $HashDocumentId = $false,

        # Max depth of the JSON object that will be added to Cosmos DB
        [Parameter(ParameterSetName = 'Entra ID')]
        [Parameter(ParameterSetName = 'Master Key')]
        [ValidateRange(0, 100)]
        [int] $JsonDocumentDepth = 15
    )

    # Calculate current date for use in Authorization header
    $private:Date = [DateTime]::UtcNow.ToString('r')

    # Compute Authorization header value and define headers dictionary
    $AuthorizationParameters = @{
        Date       = $private:Date
        Method     = 'Post'
        ResourceId = $ResourceId
    }
    if ($MasterKey) {
        $AuthorizationParameters += @{ MasterKey = $MasterKey }
    } elseif ($AccessToken) {
        $AuthorizationParameters += @{ AccessToken = $AccessToken }
    }
    $private:Authorization = New-CosmosRequestAuthorizationSignature @AuthorizationParameters

    $private:Headers = @{
        'accept'                       = 'application/json'
        'authorization'                = $private:Authorization
        'cache-control'                = 'no-cache'
        'content-type'                 = 'application/json'
        'x-ms-date'                    = $private:Date
        'x-ms-documentdb-partitionkey' = "[`"$PartitionKeyValue`"]"
        'x-ms-version'                 = '2018-12-31'
    }
    if ($IsUpsert) {
        $private:Headers += @{ 'x-ms-documentdb-is-upsert' = $true }
    }
    if ($HashDocumentId) {
        $private:DocumentId = New-HashedString -String $DocumentId
    } else {
        $private:DocumentId = $DocumentId
    }

    # Create function-local instance of variable
    $private:CosmosDocument = $Document

    # Add Partition Key
    if ($private:CosmosDocument.$PartitionKey -cne $PartitionKeyValue) {
        try {
            Write-Verbose "Add Partition Key property [$PartitionKey] with value [$PartitionKeyValue] to document"
            Add-Member -InputObject $private:CosmosDocument -MemberType NoteProperty -Name $PartitionKey -Value $PartitionKeyValue -Force
        } catch {
            Write-Error "Error adding PartitionKey property to document: $_"
        }
    }

    # Add Document ID
    try {
        if ($private:CosmosDocument.id) {
            Write-Verbose 'Remove existing ID property from PSCustomObject'
            $private:CosmosDocument.PSObject.Properties.Remove('id')
        }
        Write-Verbose "Add ID property with value [$private:DocumentId] to document"
        Add-Member -InputObject $private:CosmosDocument -MemberType NoteProperty -Name 'id' -Value $private:DocumentId -Force
    } catch {
        Write-Error "Error adding or updating ID property of document: $_"
    }

    # Send request to NoSQL REST API
    try {
        $ProgressPreference = 'SilentlyContinue'
        Write-Verbose "Insert Cosmos DB NosQL document with ID [$private:DocumentId] into Collection [$ResourceId]"
        $private:Body = $private:CosmosDocument | ConvertTo-Json -Depth $JsonDocumentDepth
        $private:RequestUri = "$Endpoint/$ResourceId/$ResourceType" -replace '(?<!(http:|https:))//+', '/'
        $private:Response = Invoke-RestMethod -Method Post -Uri $private:RequestUri -Headers $private:Headers -Body $private:Body
        $private:OutputObject = [pscustomobject]@{
            etag              = $private:Response.'_etag'
            id                = $private:Response.id
            partitionKey      = $PartitionKey
            partitionKeyValue = $private:Response.$PartitionKey
            timestamp         = $private:Response.'_ts'
        }
        $ProgressPreference = 'Continue'

        return $private:OutputObject
    } catch {
        throw $_.Exception
        # Write-Error "StatusCode: $($_.Exception.Response.StatusCode.value__) | ExceptionMessage: $($_.Exception.Message) | $_"
    }
}