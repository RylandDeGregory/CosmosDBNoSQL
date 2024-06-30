$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulePath = $here
$ModuleName = 'CosmosDBNoSQL'

Describe "$ModuleName Module Analysis with PSScriptAnalyzer" {
    BeforeAll {
        $ModulePath = $here
        $ModuleName = 'CosmosDBNoSQL'
        # Define PSScriptAnalyzer rules once
        $ScriptAnalyzerRules = Get-ScriptAnalyzerRule | Where-Object { $_.RuleName -ne 'PSUseShouldProcessForStateChangingFunctions' }
    }
    BeforeEach {
        $ModuleScript = "$ModulePath\$ModuleName.psm1"
    }

    Context 'Standard Rules' {
        It "should pass all script analyzer rules" {
            Invoke-ScriptAnalyzer -Path $ModuleScript -IncludeRule $ScriptAnalyzerRules | Should -BeNullOrEmpty
        }
    }
}

# Dynamically defining the functions to analyze
$FunctionPaths = @()
if (Test-Path -Path "$ModulePath\private\*.ps1") {
    $FunctionPaths += Get-ChildItem -Path "$ModulePath\private\*.ps1" -Exclude "*.Tests.*"
}
if (Test-Path -Path "$ModulePath\public\*.ps1") {
    $FunctionPaths += Get-ChildItem -Path "$ModulePath\public\*.ps1" -Exclude "*.Tests.*"
}

# Running the analysis for each function
foreach ($FunctionPath in $FunctionPaths) {

    $FunctionName = $FunctionPath.BaseName

    Describe "'$FunctionName' Function Analysis with PSScriptAnalyzer" {
        BeforeAll {
            # Define function path for common use
            $FunctionPath = $FunctionPath.FullName
            $ScriptAnalyzerRules = Get-ScriptAnalyzerRule | Where-Object { $_.RuleName -ne 'PSUseShouldProcessForStateChangingFunctions' }
        }

        Context 'Standard Rules' {
            It "should pass all script analyzer rules" {
                Invoke-ScriptAnalyzer -Path $FunctionPath -IncludeRule $ScriptAnalyzerRules | Should -BeNullOrEmpty
            }
        }
    }
}
