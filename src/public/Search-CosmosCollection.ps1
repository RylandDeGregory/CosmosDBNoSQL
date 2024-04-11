function Search-CosmosCollection {
    <#
        .SYNOPSIS
            Retrieve one or more Cosmos DB NoSQL API documents by query using the REST API. Uses Master Key or Entra ID Authentication.
        .DESCRIPTION
            Query a Cosmos DB NoSQL Collection for one or more documents. See: https://learn.microsoft.com/en-us/rest/api/cosmos-db/query-documents
        .LINK
            New-CosmosRequestAuthorizationSignature
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
            Search-CosmosCollection @QueryDocParams
    #>
    [OutputType([pscustomobject[]])]
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
        [pscustomobject] $Query,

        [Parameter(ParameterSetName = 'Entra ID', Mandatory)]
        [Parameter(ParameterSetName = 'Master Key', Mandatory)]
        [string] $PartitionKey,

        [Parameter(ParameterSetName = 'Entra ID')]
        [Parameter(ParameterSetName = 'Master Key')]
        [ValidateRange(1, 1000)]
        [int] $MaxItemCount = 1000,

        [Parameter(ParameterSetName = 'Entra ID')]
        [Parameter(ParameterSetName = 'Master Key')]
        [bool] $CrossPartitionQuery = $true
    )

    # Validate parameters
    if (-not $CrossPartitionQuery -and -not $PartitionKey) {
        Write-Error 'PartitionKey is required when CrossPartitionQuery is set to false'
        return
    }

    # Initialize continuation token
    $ContinuationToken = $null
    $Page = 1

    # Calculate current date for use in Authorization header
    $Date = [DateTime]::UtcNow.ToString('r')

    # Compute authorization header value
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

    # Define Cosmos DB API request headers
    $Headers = @{
        'accept'                                     = 'application/json'
        'authorization'                              = $Authorization
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

    Write-Verbose "Query Cosmos DB Collection [$ResourceId] for documents"
    $Documents = do {
        # Add continuation token to headers if it is not null
        if ($ContinuationToken) {
            $Headers['x-ms-continuation'] = $ContinuationToken
            Write-Verbose "Page $Page ContinuationToken: $ContinuationToken"
            $Page++
        }

        # Send request to NoSQL REST API
        try {
            $Response = Invoke-WebRequest -Method Post -Uri "$Endpoint$ResourceId/$ResourceType" -Headers $Headers -Body ($Query | ConvertTo-Json) -ProgressAction SilentlyContinue
        } catch {
            Write-Error "StatusCode: $($_.Exception.Response.StatusCode.value__) | ExceptionMessage: $($_.Exception.Message) | $_"
            break
        }

        # Get continuation token from response headers
        $ContinuationToken = [string]$Response.Headers.'x-ms-continuation'

        # Convert JSON response to PowerShell object
        $Response.Content | ConvertFrom-Json | Select-Object -ExpandProperty Documents
    } while ($ContinuationToken)

    # Return array of documents
    return $Documents
}