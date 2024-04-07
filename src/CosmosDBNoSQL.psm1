# Get public and private function files
$Public  = Get-ChildItem -Path "$PSScriptRoot\public\*.ps1" -Exclude "*.Tests.*" -ErrorAction SilentlyContinue
$Private = Get-ChildItem -Path "$PSScriptRoot\private\*.ps1" -Exclude "*.Tests.*" -ErrorAction SilentlyContinue

# Dot-source import all PowerShell functions
foreach ($Import in @($Private + $Public)) {
    try {
        . $Import.FullName
    } catch {
        Write-Error "Failed to import function [$($Import.FullName)]: $_"
    }
}

# Export public functions as module members
Export-ModuleMember -Function $Public.BaseName