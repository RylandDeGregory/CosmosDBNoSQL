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
        .EXAMPLE
            New-HashedString -String 'Hello' -Algorithm 'SHA256' -OutputType 'Base64'
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param (
        # The string to hash
        [Parameter(Mandatory)]
        [string] $String,

        # The hashing algorithm to use
        [Parameter()]
        [ValidateSet('MD5', 'SHA1', 'SHA256')]
        [string] $Algorithm = 'SHA256',

        # The output format of the hashed string
        [Parameter()]
        [ValidateSet('HexString', 'Base64')]
        [string] $OutputType = 'HexString'
    )

    try {
        Write-Verbose "Generating [$Algorithm] Hashed String"
        $HashAlgorithm = [System.Security.Cryptography.HashAlgorithm]::Create($Algorithm)
        $HashedBytes   = $HashAlgorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($String))
    } catch {
        Write-Error "Failed generating [$Algorithm] hashed string: $_"
    } finally {
        $HashAlgorithm.Dispose()
    }

    try {
        Write-Verbose "Converting [$Algorithm] Hashed Bytes to [$OutputType] format"
        switch ($OutputType) {
            'HexString' {
                $HashedString = [Convert]::ToHexString($HashedBytes)
                return $HashedString.ToLower()
            }
            'Base64' {
                $HashedString = [Convert]::ToBase64String($HashedBytes)
                return $HashedString
            }
        }
    } catch {
        throw "Failed converting [$Algorithm] Hashed Bytes to [$OutputType] format: $_"
    }
}
