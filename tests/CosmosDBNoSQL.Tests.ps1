Describe 'CosmosDBNoSQL module' {
    BeforeAll {
        $script:module = Import-Module ./src/CosmosDBNoSQL.psd1 -Force -PassThru
    }

    It 'imports the module manifest' {
        Should-Be -Actual $script:module.Name -Expected 'CosmosDBNoSQL'
    }

    It 'exports the functions declared in the manifest' {
        $manifestFunctions = (Test-ModuleManifest ./src/CosmosDBNoSQL.psd1).ExportedFunctions.Keys | Sort-Object
        $moduleFunctions = $script:module.ExportedFunctions.Keys | Sort-Object

        Should-BeCollection -Actual $moduleFunctions -Expected $manifestFunctions
    }
}