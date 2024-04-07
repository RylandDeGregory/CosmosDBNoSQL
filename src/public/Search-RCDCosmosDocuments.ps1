function Search-RCDCosmosDocuments {
    <#
        .SYNOPSIS
            Retrieve one or more Cosmos DB NoSQL API documents by query using the REST API. Uses Master Key Authentication.
        .LINK
            New-RCDCosmosMasterKeyAuthorizationSignature
        .EXAMPLE
            $Query = @{
                query      = 'SELECT * FROM c WHERE c[@PartitionKey] = @PartitionKeyValue'
                parameters = @(
                    @{
                        name  = '@PartitionKey'
                        value = $PartitionKey
                    }
                    @{
                        name  = '@PartitionKeyValue'
                        value = $PartitionKeyValue
                    }
                )
            }
            $QueryDocParams = @{
                Endpoint          = 'https://xxxxx.documents.azure.com:443/'
                MasterKey         = $MasterKey
                ResourceId        = "dbs/$DatabaseId/colls/$CollectionId"
                Query             = $Query
            }
            Search-RCDCosmosDocuments @QueryDocParams
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
        [psobject] $Query,

        [Parameter()]
        [string] $PartitionKey,

        [Parameter()]
        [int] $MaxItemCount = 1000,

        [Parameter()]
        [bool] $CrossPartitionQuery = $true
    )

    # Validate parameters
    if (-not $CrossPartitionQuery -and -not $PartitionKey) {
        Write-Error 'PartitionKey is required when CrossPartitionQuery is set to false'
        return
    }

    # Calculate current date for use in Authorization header
    $Date = [DateTime]::UtcNow.ToString('r')

    # Compute authorization header value
    $AuthorizationKey = New-RCDCosmosMasterKeyAuthorizationSignature -Method Post -ResourceId $ResourceId -Date $Date -MasterKey $MasterKey
    # Initialize continuation token
    $ContinuationToken = $null
    $Page = 1

    # Define Cosmos DB API request headers
    $Headers = @{
        'accept'                                     = 'application/json'
        'authorization'                              = $AuthorizationKey
        'cache-control'                              = 'no-cache'
        'content-type'                               = 'application/query+json'
        'x-ms-date'                                  = $Date
        'x-ms-documentdb-isquery'                    = 'True'
        'x-ms-documentdb-query-enablecrosspartition' = $CrossPartitionQuery
        'x-ms-version'                               = '2018-12-31'
        'x-ms-max-item-count'                        = $MaxItemCount
    }

    if ($PartitionKey) {
        $Headers['x-ms-documentdb-partitionkey'] = "[`"$PartitionKey`"]"
    }

    $Documents = do {
        # Add continuation token to headers if it is not null
        if ($ContinuationToken) {
            $Headers['x-ms-continuation'] = $ContinuationToken
            Write-Verbose "Page $Page ContinuationToken: $ContinuationToken"
            $Page++
        }

        # Send request to NoSQL REST API
        try {
            $Response = Invoke-WebRequest -Uri "$Endpoint$ResourceId/$ResourceType" -Headers $Headers -Method Post -Body ($Query | ConvertTo-Json) -ProgressAction SilentlyContinue
        } catch {
            Write-Error "StatusCode: $($_.Exception.Response.StatusCode.value__) | ExceptionMessage: $($_.Exception.Message) | $_"
        }

        # Get continuation token from response headers
        $ContinuationToken = [string]$Response.Headers.'x-ms-continuation'

        # Convert JSON response to PowerShell object
        $Response.Content | ConvertFrom-Json -Depth 10 | Select-Object -ExpandProperty Documents
    } while ($ContinuationToken)

    # Return array of documents
    return $Documents
}