function New-Sha256HashedString {
    <#
        .SYNOPSIS
            Generate the SHA256 hash of a string
        .DESCRIPTION
            Use the .NET HashAlgorithm Class to generate a SHA256 hash of a provided string
            https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography.hashalgorithm
        .EXAMPLE
            New-Sha256HashedString -String 'Hello'
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $String
    )

    Write-Verbose 'Generating SHA256 Hashed String'

    $Sha256       = [System.Security.Cryptography.HashAlgorithm]::Create('SHA256')
    $HashedBytes  = $Sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes($String))
    $HashedString = [BitConverter]::ToString($HashedBytes) -replace '-', ''
    $Sha256.Dispose()

    return $HashedString.ToLower()
}