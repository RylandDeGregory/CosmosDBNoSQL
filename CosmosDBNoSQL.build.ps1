#requires -modules InvokeBuild
<#
    .SYNOPSIS
        Build script (https://github.com/nightroman/Invoke-Build)
    .DESCRIPTION
        This script contains the tasks for building the 'PSTagLib' PowerShell module
#>

param (
    [Parameter(ValueFromPipelineByPropertyName)]
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Debug',
    [Parameter(ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [string] $SourceLocation,
    [Parameter()]
    [bool] $NewMajorVersion = $false
)

Set-StrictMode -Version Latest

# Synopsis: Default task
task . Clean, Build

# Install build dependencies
Enter-Build {

    # Installing PSDepend for dependency management
    if (-not (Get-Module -Name PSDepend -ListAvailable)) {
        Install-Module PSDepend -Force
    }
    Import-Module PSDepend

    # Installing dependencies
    Invoke-PSDepend -Force

    # Setting build script variables
    $script:moduleName = 'CosmosDBNoSQL'
    $script:moduleSourcePath = Join-Path -Path $BuildRoot -ChildPath 'src'
    $script:moduleManifestPath = Join-Path -Path $moduleSourcePath -ChildPath "$moduleName.psd1"
    $script:nuspecPath = Join-Path -Path $moduleSourcePath -ChildPath "$moduleName.nuspec"
    $script:buildOutputPath = Join-Path -Path $BuildRoot -ChildPath 'build'

    # Setting base module version and using it if building locally
    $script:newModuleVersion = New-Object -TypeName 'System.Version' -ArgumentList (0, 0, 1)

    # Setting the list of functions ot be exported by module
    $script:functionsToExport = (Test-ModuleManifest $moduleManifestPath).ExportedFunctions
}

# Synopsis: Analyze the project with PSScriptAnalyzer
task Analyze {
    # Get-ChildItem parameters
    $Params = @{
        Path    = $moduleSourcePath
        Recurse = $true
        Include = 'PSSATests.ps1'
    }

    $TestFiles = Get-ChildItem @Params

    # Pester parameters
    $Params = @{
        Path     = $TestFiles
        PassThru = $true
    }

    # Additional parameters on Azure Pipelines agents to generate test results
    if ($env:TF_BUILD) {
        if (-not (Test-Path -Path $buildOutputPath -ErrorAction SilentlyContinue)) {
            New-Item -Path $buildOutputPath -ItemType Directory
        }
        $Timestamp = Get-Date -UFormat '%Y%m%d-%H%M%S'
        $PSVersion = $PSVersionTable.PSVersion.Major
        $TestResultFile = "AnalysisResults_PS$PSVersion`_$TimeStamp.xml"
        $Params.Add('OutputFile', "$buildOutputPath\$TestResultFile")
        $Params.Add('OutputFormat', 'NUnitXml')
    }

    # Invoke all tests
    $TestResults = Invoke-Pester @Params
    if ($TestResults.FailedCount -gt 0) {
        $TestResults | Format-List
        throw 'One or more PSScriptAnalyzer rules have been violated. Build cannot continue!'
    }
}

# Synopsis: Test the project with Pester tests
task Test {
    # Get-ChildItem parameters
    $Params = @{
        Path    = $moduleSourcePath
        Recurse = $true
        Include = 'PesterTests.ps1'
    }

    $TestFiles = Get-ChildItem @Params

    # Pester parameters
    $Params = @{
        Path     = $TestFiles
        PassThru = $true
    }

    # Additional parameters on Azure Pipelines agents to generate test results
    if ($env:TF_BUILD) {
        if (-not (Test-Path -Path $buildOutputPath -ErrorAction SilentlyContinue)) {
            New-Item -Path $buildOutputPath -ItemType Directory
        }
        $Timestamp = Get-Date -UFormat '%Y%m%d-%H%M%S'
        $PSVersion = $PSVersionTable.PSVersion.Major
        $TestResultFile = "TestResults_PS$PSVersion`_$TimeStamp.xml"
        $Params.Add('OutputFile', "$buildOutputPath\$TestResultFile")
        $Params.Add('OutputFormat', 'NUnitXml')
    }

    # Invoke all tests
    $TestResults = Invoke-Pester @Params
    if ($TestResults.FailedCount -gt 0) {
        $TestResults | Format-List
        throw 'One or more Pester tests have failed. Build cannot continue!'
    }
}

# Synopsis: Generate a new module version if creating a release build
task GenerateNewModuleVersion -if ($Configuration -eq 'Release') {
    # Using the current NuGet package version from the feed as a version base when building via Azure DevOps pipeline

    # Define package repository name
    $repositoryName = $moduleName + '-repository'

    # Register a target PSRepository
    try {
        Register-PSRepository -Name $repositoryName -SourceLocation $SourceLocation -InstallationPolicy Trusted
    } catch {
        throw "Cannot register '$repositoryName' repository with source location '$SourceLocation'!"
    }

    # Define variable for existing package
    $existingPackage = $null

    try {
        # Look for the module package in the repository
        $existingPackage = Find-Module -Name $moduleName -Repository $repositoryName
    }
    # In no existing module package was found, the base module version defined in the script will be used
    catch {
        Write-Warning "No existing package for '$moduleName' module was found in '$repositoryName' repository!"
    }

    # if existing module package was found, try to install the module
    if ($existingPackage) {
        # Get the largest module version
        $currentModuleVersion = New-Object -TypeName 'System.Version' -ArgumentList ($existingPackage.Version)

        # Set module version base numbers
        [int]$Major = $currentModuleVersion.Major
        [int]$Minor = $currentModuleVersion.Minor
        [int]$Build = $currentModuleVersion.Build

        try {
            # Install the existing module from the repository
            Install-Module -Name $moduleName -Repository $repositoryName -RequiredVersion $existingPackage.Version
        } catch {
            throw "Cannot import module '$moduleName'!"
        }

        # Get the count of exported module functions
        $existingFunctionsCount = (Get-Command -Module $moduleName | Where-Object -Property Version -EQ $existingPackage.Version | Measure-Object).Count
        # Check if new public functions were added in the current build
        [int]$sourceFunctionsCount = (Get-ChildItem -Path "$moduleSourcePath\public\*.ps1" -Exclude '*.Tests.*' | Measure-Object).Count
        [int]$newFunctionsCount = [System.Math]::Abs($sourceFunctionsCount - $existingFunctionsCount)

        # Increase the major version if a the NewMajorVersion parameter is True
        if ($NewMajorVersion) {
            [int]$Major = $Major + 1
            [int]$Minor = 0
            [int]$Build = 0
        } elseif ($newFunctionsCount -gt 0) { # Increase the minor number if any new public functions have been added
            [int]$Minor = $Minor + 1
            [int]$Build = 0
        } else { # If not, just increase the build number
            [int]$Build = $Build + 1
        }

        # Update the module version object
        $Script:newModuleVersion = New-Object -TypeName 'System.Version' -ArgumentList ($Major, $Minor, $Build)
    }
}

# Synopsis: Generate list of functions to be exported by module
task GenerateListOfFunctionsToExport {
    # Set exported functions by finding functions exported by *.psm1 file via Export-ModuleMember
    $params = @{
        Force    = $true
        PassThru = $true
        Name     = (Resolve-Path (Get-ChildItem -Path $moduleSourcePath -Filter '*.psm1')).Path
    }
    $PowerShell = [Powershell]::Create()
    [void]$PowerShell.AddScript(
        {
            Param ($Force, $PassThru, $Name)
            $module = Import-Module -Name $Name -PassThru:$PassThru -Force:$Force
            $module | Where-Object { $_.Path -notin $module.Scripts }
        }
    ).AddParameters($Params)
    $module = $PowerShell.Invoke()
    $Script:functionsToExport = $module.ExportedFunctions.Keys
}

# Synopsis: Update the module manifest with module version and functions to export
task UpdateModuleManifest GenerateNewModuleVersion, GenerateListOfFunctionsToExport, {
    # Update-ModuleManifest parameters
    $Params = @{
        Path              = $moduleManifestPath
        ModuleVersion     = $newModuleVersion
        FunctionsToExport = $functionsToExport
    }

    # Update the manifest file
    Update-ModuleManifest @Params
}

# Synopsis: Update the NuGet package specification with module version
task UpdatePackageSpecification GenerateNewModuleVersion, {
    # Load the specification into XML object
    $xml = New-Object -TypeName 'XML'
    $xml.Load($nuspecPath)

    # Update package version
    $metadata = Select-Xml -Xml $xml -XPath '//package/metadata'
    $metadata.Node.Version = $newModuleVersion

    # Save XML object back to the specification file
    $xml.Save($nuspecPath)
}

# Synopsis: Build the project
task Build UpdateModuleManifest, UpdatePackageSpecification, {
    # Warning on local builds
    if ($Configuration -eq 'Debug') {
        Write-Warning 'Creating a debug build. This build will not be published'
    }

    # Create versioned output folder
    $moduleOutputPath = Join-Path -Path $buildOutputPath -ChildPath $moduleName -AdditionalChildPath $newModuleVersion
    if (-not (Test-Path $moduleOutputPath)) {
        New-Item -Path $moduleOutputPath -ItemType Directory
    }

    # Copy-Item parameters
    $Params = @{
        Path        = "$moduleSourcePath\*"
        Destination = $moduleOutputPath
        Exclude     = 'PesterTests.ps1', 'PSSATests.ps1'
        Recurse     = $true
        Force       = $true
    }

    # Copy module files to the target build folder
    Copy-Item @Params
}

# Synopsis: Verify the code coverage by tests
task CodeCoverage {
    $acceptableCodeCoveragePercent = 0

    $path = $moduleSourcePath
    $files = Get-ChildItem $path -Recurse -Include '*.ps1', '*.psm1' -Exclude 'PesterTests.ps1', 'PSSATests.ps1'

    $Params = @{
        Path         = $path
        CodeCoverage = $files
        PassThru     = $true
        Show         = 'Summary'
    }

    # Additional parameters on Azure Pipelines agents to generate code coverage report
    if ($env:TF_BUILD) {
        if (-not (Test-Path -Path $buildOutputPath -ErrorAction SilentlyContinue)) {
            New-Item -Path $buildOutputPath -ItemType Directory
        }
        $Timestamp = Get-Date -UFormat '%Y%m%d-%H%M%S'
        $PSVersion = $PSVersionTable.PSVersion.Major
        $TestResultFile = "CodeCoverageResults_PS$PSVersion`_$TimeStamp.xml"
        $Params.Add('CodeCoverageOutputFile', "$buildOutputPath\$TestResultFile")
    }

    $Result = Invoke-Pester @Params

    if ($Result.CodeCoverage) {
        $CodeCoverage = $Result.CodeCoverage
        $CommandsFound = $CodeCoverage.NumberOfCommandsAnalyzed

        # To prevent any "Attempted to divide by zero" exceptions
        if ($CommandsFound -ne 0) {
            $CommandsExercised = $CodeCoverage.NumberOfCommandsExecuted
            [System.Double]$ActualCodeCoveragePercent = [Math]::Round(($CommandsExercised / $CommandsFound) * 100, 2)
        } else {
            [System.Double]$ActualCodeCoveragePercent = 0
        }
    }

    # Fail the task if the code coverage results are not acceptable
    if ($actualCodeCoveragePercent -lt $acceptableCodeCoveragePercent) {
        throw "The overall code coverage by Pester tests is $actualCodeCoveragePercent% which is less than the quality gate of $acceptableCodeCoveragePercent%. Pester ModuleVersion is: $((Get-Module -Name Pester -ListAvailable).Version)."
    }
}

# Synopsis: Clean up the target build directory
task Clean {
    if (Test-Path $buildOutputPath) {
        Remove-Item -Path $buildOutputPath -Recurse
    }
}