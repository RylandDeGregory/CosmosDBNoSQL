function New-HashedString {
    <#
        .SYNOPSIS
            Generate the hash of a string
        .DESCRIPTION
            Use the .NET HashAlgorithm Class to generate the hash of a provided string
            https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography.hashalgorithm
        .EXAMPLE
            New-HashedString -String 'Hello'
        .EXAMPLE
            New-HashedString -String 'Hello' -Algorithm 'SHA1'
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $String,

        [Parameter()]
        [ValidateSet('MD5', 'SHA1', 'SHA256')]
        [string] $Algorithm = 'SHA256'
    )

    Write-Verbose 'Generating SHA256 Hashed String'

    $HashAlgorithm = [System.Security.Cryptography.HashAlgorithm]::Create($Algorithm)
    $HashedBytes   = $HashAlgorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($String))
    $HashedString  = [BitConverter]::ToString($HashedBytes) -replace '-', ''
    $HashAlgorithm.Dispose()

    return $HashedString.ToLower()
}