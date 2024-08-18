function Search-CosmosCollection {
    <#
        .SYNOPSIS
            Retrieve one or more Cosmos DB NoSQL API documents by query using the REST API. Uses Master Key or Entra ID Authentication.
        .DESCRIPTION
            Query a Cosmos DB NoSQL Collection for one or more documents. See: https://learn.microsoft.com/en-us/rest/api/cosmos-db/query-documents
        .LINK
            New-CosmosRequestAuthorizationSignature
        .EXAMPLE
            # Master Key Authentication (shown with query parameters)
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
                Endpoint   = 'https://xxxxx.documents.azure.com:443/'
                MasterKey  = $MasterKey
                ResourceId = "dbs/$DatabaseId/colls/$CollectionId"
                Query      = $Query
            }
            Search-CosmosCollection @QueryDocParams
        .EXAMPLE
            # Entra ID Authentication (shown without query parameters)
            $Query = @{
                query = 'SELECT * FROM c'
            }
            $QueryDocParams = @{
                Endpoint     = 'https://xxxxx.documents.azure.com:443/'
                AccessToken  = (Get-AzAccessToken -ResourceUrl ($Endpoint -replace ':443\/?', '') -AsSecureString).Token
                ResourceId   = "dbs/$DatabaseId/colls/$CollectionId"
                Query        = $Query
                PartitionKey = $PartitionKey
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
        [securestring] $AccessToken,

        [Parameter(ParameterSetName = 'Entra ID', Mandatory)]
        [Parameter(ParameterSetName = 'Master Key', Mandatory)]
        [string] $ResourceId,

        [Parameter(ParameterSetName = 'Entra ID')]
        [Parameter(ParameterSetName = 'Master Key')]
        [string] $ResourceType = 'docs',

        [Parameter(ParameterSetName = 'Entra ID', Mandatory)]
        [Parameter(ParameterSetName = 'Master Key', Mandatory)]
        [pscustomobject] $Query,

        [Parameter(ParameterSetName = 'Entra ID')]
        [Parameter(ParameterSetName = 'Master Key')]
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
    $private:Date = [DateTime]::UtcNow.ToString('r')

    # Compute authorization header value
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

    # Define Cosmos DB API request headers
    $private:Headers = @{
        'accept'                                     = 'application/json'
        'authorization'                              = $private:Authorization
        'cache-control'                              = 'no-cache'
        'content-type'                               = 'application/query+json'
        'x-ms-date'                                  = $private:Date
        'x-ms-documentdb-isquery'                    = 'True'
        'x-ms-documentdb-query-enablecrosspartition' = $CrossPartitionQuery
        'x-ms-version'                               = '2018-12-31'
        'x-ms-max-item-count'                        = $MaxItemCount
    }

    if ($PartitionKey) {
        $private:Headers['x-ms-documentdb-partitionkey'] = "[`"$PartitionKey`"]"
    }

    Write-Verbose "Query Cosmos DB Collection [$ResourceId] for documents"
    $private:Documents = do {
        # Add continuation token to headers if it is not null
        if ($ContinuationToken) {
            $private:Headers['x-ms-continuation'] = $ContinuationToken
            Write-Verbose "Page $Page ContinuationToken: $ContinuationToken"
            $Page++
        }

        # Send request to NoSQL REST API
        try {
            $ProgressPreference = 'SilentlyContinue'
            $private:RequestUri = "$Endpoint/$ResourceId/$ResourceType" -replace '(?<!(http:|https:))//+', '/'
            $private:Response = Invoke-WebRequest -Method Post -Uri $private:RequestUri -Headers $private:Headers -Body ($Query | ConvertTo-Json)
            $ProgressPreference = 'Continue'
        } catch {
            throw $_.Exception
            # Write-Error "StatusCode: $($_.Exception.Response.StatusCode.value__) | ExceptionMessage: $($_.Exception.Message) | $_"
            break
        }

        # Get continuation token from response headers
        $ContinuationToken = [string]$private:Response.Headers.'x-ms-continuation'

        # Convert JSON response to PowerShell object
        $private:Response.Content | ConvertFrom-Json | Select-Object -ExpandProperty Documents
    } while ($ContinuationToken)

    # Return array of documents
    return $private:Documents
}