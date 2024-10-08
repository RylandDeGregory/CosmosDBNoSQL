function New-CosmosCollection {
    <#
        .SYNOPSIS
            Create a new collection in Cosmos DB with the provided name and partition key.
        .DESCRIPTION
            Create a new Cosmos DB Collection. See: https://learn.microsoft.com/en-us/rest/api/cosmos-db/create-a-collection
        .NOTES
            Cosmos DB SQL Data Plane does not support management operations using Entra ID Authentication.
            See: https://learn.microsoft.com/en-us/azure/cosmos-db/how-to-setup-rbac#permission-model
        .LINK
            New-CosmosRequestAuthorizationSignature
        .EXAMPLE
            # Master Key Authentication
            $NewCollectionParams = @{
                Endpoint     = 'https://xxxxx.documents.azure.com:443/'
                MasterKey    = $MasterKey
                ResourceId   = "dbs/$DatabaseId"
                CollectionId = 'MyCollection'
                PartitionKey = 'MyPartitionKey'
            }
            New-CosmosCollection @NewCollectionParams
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding(DefaultParameterSetName = 'Master Key')]
    param (
        [Parameter(ParameterSetName = 'Master Key', Mandatory)]
        [string] $Endpoint,

        [Parameter(ParameterSetName = 'Master Key', Mandatory)]
        [string] $MasterKey,

        [Parameter(ParameterSetName = 'Master Key', Mandatory)]
        [string] $ResourceId,

        [Parameter(ParameterSetName = 'Master Key')]
        [string] $ResourceType = 'colls',

        [Parameter(ParameterSetName = 'Master Key', Mandatory)]
        [string] $CollectionId,

        [Parameter(ParameterSetName = 'Master Key', Mandatory)]
        [string] $PartitionKey
    )

    # Calculate current date for use in Authorization header
    $private:Date = [DateTime]::UtcNow.ToString('r')

    # Compute Authorization header value and define headers dictionary
    $AuthorizationParameters = @{
        Date         = $private:Date
        MasterKey    = $MasterKey
        Method       = 'Post'
        ResourceId   = $ResourceId
        ResourceType = $ResourceType
    }
    $private:Authorization = New-CosmosRequestAuthorizationSignature @AuthorizationParameters

    $private:Headers = @{
        'accept'        = 'application/json'
        'authorization' = $private:Authorization
        'content-type'  = 'application/json'
        'x-ms-date'     = $private:Date
        'x-ms-version'  = '2018-12-31'
    }

    # Define request body and URI
    $private:Body = @{
        'id'             = $CollectionId
        'partitionKey'   = @{
            'paths'   = @("/$PartitionKey")
            'kind'    = 'Hash'
            'version' = 2
        }
    } | ConvertTo-Json
    $private:RequestUri = "$Endpoint/$ResourceId/$ResourceType" -replace '(?<!(http:|https:))//+', '/'

    # Send request to NoSQL REST API
    try {
        $ProgressPreference = 'SilentlyContinue'
        Write-Verbose "Create Cosmos DB NosQL Collection with ID [$CollectionId] in Database [$ResourceId]"
        $private:Response = Invoke-RestMethod -Method Post -Uri $private:RequestUri -Headers $private:Headers -Body $private:Body
        $private:OutputObject = [pscustomobject]@{
            id           = $private:Response.id
            partitionKey = $private:Response.partitionKey.paths
        }
        $ProgressPreference = 'Continue'

        return $private:OutputObject
    } catch {
        throw $_
        # Write-Error "StatusCode: $($_.Exception.Response.StatusCode.value__) | ExceptionMessage: $($_.Exception.Message) | $_"
    }
}