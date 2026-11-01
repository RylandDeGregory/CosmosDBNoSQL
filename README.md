# CosmosDBNoSQL

A PowerShell module to interact with the Cosmos DB NoSQL REST API.

[![Build and release](https://github.com/RylandDeGregory/CosmosDBNoSQL/actions/workflows/release.yml/badge.svg)](https://github.com/RylandDeGregory/CosmosDBNoSQL/actions/workflows/release.yml) [![Latest release](https://img.shields.io/github/v/release/RylandDeGregory/CosmosDBNoSQL)](https://github.com/RylandDeGregory/CosmosDBNoSQL/releases/latest)

## Install from GitHub Packages

```PowerShell
Register-PSResourceRepository -Name 'CosmosDBNoSQL' -Uri 'https://nuget.pkg.github.com/RylandDeGregory/index.json'
$credential = Get-Credential -UserName 'YOUR_GITHUB_USERNAME' -Message 'Enter a classic GitHub PAT with read:packages access'
Install-PSResource -Name 'CosmosDBNoSQL' -Repository 'CosmosDBNoSQL' -Credential $credential
Import-Module -Name 'CosmosDBNoSQL' -Force
```
