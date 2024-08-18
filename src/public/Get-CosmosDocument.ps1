function Get-CosmosDocument {
    <#
        .SYNOPSIS
            Retrieve a Cosmos DB NoSQL API document by ID using the REST API. Uses Master Key or Entra ID Authentication.
        .DESCRIPTION
            Get a Cosmos DB NoSQL document by ID. See: https://learn.microsoft.com/en-us/rest/api/cosmos-db/get-a-document
        .LINK
            New-CosmosRequestAuthorizationSignature
        .EXAMPLE
            # Master Key Authentication
            $GetDocParams = @{
                Endpoint          = 'https://xxxxx.documents.azure.com:443/'
                MasterKey         = $MasterKey
                ResourceId        = "dbs/$DatabaseId/colls/$CollectionId"
                PartitionKeyValue = $PartitionKeyValue
                DocumentId        = $DocumentId
            }
            Get-CosmosDocument @GetDocParams
        .EXAMPLE
            # Entra ID Authentication
            $GetDocParams = @{
                Endpoint          = 'https://xxxxx.documents.azure.com:443/'
                AccessToken       = (Get-AzAccessToken -ResourceUrl ($Endpoint -replace ':443\/?', '') -AsSecureString).Token
                ResourceId        = "dbs/$DatabaseId/colls/$CollectionId"
                PartitionKeyValue = $PartitionKeyValue
                DocumentId        = $DocumentId
            }
            Get-CosmosDocument @GetDocParams
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
        [securestring] $AccessToken,

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
    $private:Date = [DateTime]::UtcNow.ToString('r')

    # Compute Authorization header value and define headers dictionary
    $AuthorizationParameters = @{
        Date       = $private:Date
        Method     = 'Get'
        ResourceId = "$ResourceId/$ResourceType/$DocumentId"
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

    # Send request to NoSQL REST API
    try {
        $ProgressPreference = 'SilentlyContinue'
        Write-Verbose "Get Cosmos DB NoSQL document with ID [$DocumentId] from Collection [$ResourceId]"
        $private:RequestUri = "$Endpoint/$ResourceId/$ResourceType/$DocumentId" -replace '(?<!(http:|https:))//+', '/'
        $private:Document = Invoke-RestMethod -Method Get -Uri $private:RequestUri -Headers $private:Headers
        $ProgressPreference = 'Continue'

        return $private:Document
    } catch {
        throw $_.Exception
        # Write-Error "StatusCode: $($_.Exception.Response.StatusCode.value__) | ExceptionMessage: $($_.Exception.Message) | $_"
    }
}