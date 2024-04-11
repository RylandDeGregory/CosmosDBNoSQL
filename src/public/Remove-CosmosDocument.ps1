function Remove-CosmosDocument {
    <#
        .SYNOPSIS
            Remove a Cosmos DB NoSQL API document using the REST API. Uses Master Key or Entra ID Authentication.
        .DESCRIPTION
            Delete a Cosmos DB NoSQL document. See: https://learn.microsoft.com/en-us/rest/api/cosmos-db/delete-a-document
        .LINK
            New-CosmosRequestAuthorizationSignature
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
        [string] $PartitionKeyValue,

        [Parameter(ParameterSetName = 'Entra ID', Mandatory)]
        [Parameter(ParameterSetName = 'Master Key', Mandatory)]
        [string] $DocumentId
    )

    # Calculate current date for use in Authorization header
    $Date = [DateTime]::UtcNow.ToString('r')

    # Compute Authorization header value and define headers dictionary
    $AuthorizationParameters = @{
        Date       = $Date
        Method     = 'Delete'
        ResourceId = "$ResourceId/$ResourceType/$DocumentId"
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

    # Send request to NoSQL REST API
    try {
        Write-Verbose "Remove Cosmos DB NoSQL document with ID [$DocumentId] from Collection [$ResourceId]"
        $Result = Invoke-RestMethod -Method Delete -Uri "$Endpoint$ResourceId/$ResourceType/$DocumentId" -Headers $Headers

        return $Result
    } catch {
        Write-Error "StatusCode: $($_.Exception.Response.StatusCode.value__) | ExceptionMessage: $($_.Exception.Message) | $_"
    }
}