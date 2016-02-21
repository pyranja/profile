<#
.SYNOPSIS
    Package the pyps module
#>
[CmdletBinding()]
Param([Parameter(Mandatory=$false)][version]$Version = "0.0.0")

Set-StrictMode -Version Latest

$PackageName = 'py-profile'

Write-Host "packaging $PackageName-$Version"

$base = (Split-Path $PSCommandPath)
$cwd = (Join-Path $base "dist")
$assembly = (Join-Path $cwd "$PackageName")
If (Test-Path $assembly) {
    Remove-Item $assembly -Force -Recurse
}
New-Item $assembly -ItemType Directory | Out-Null

# Assemble powershell module
$ModuleName = 'py-ps'
$ModuleSources = (Join-Path $base "py-ps")

New-Item -ItemType Directory -Path "$assembly\py-ps" -Force | Out-Null
Get-ChildItem -Path $ModuleSources -Exclude *.Tests.* | Copy-Item -Recurse -Destination "$assembly\py-ps"

New-ModuleManifest `
    -Path (Join-Path $assembly "$ModuleName\$ModuleName.psd1") `
    -ModuleVersion $Version `
    -Guid 6d07c16c-3181-4844-9f4b-4d8a6a644634 `
    -Author 'Chris Borckholder' `
    -Copyright 'This is free and unencumbered software released into the public domain.' `
    -Description 'Personal dotfiles and utilities.' `
    -PowerShellVersion '3.0' `
    -DefaultCommandPrefix 'Py' `
    -NestedModules $(Get-ChildItem "$assembly\py-ps" -Recurse -Include *.ps1 | % { $_.Name }) `
    -CmdletsToExport *-* `
    -FunctionsToExport *-* `
    -AliasesToExport '__none' `
    -VariablesToExport '__none'

# Copy non-shell resources
$Assets = 'dotfiles','project-skeleton','installer/*' | foreach { Join-Path -Path $base -ChildPath $_ }
Copy-Item -Path $Assets -Destination $assembly -Recurse -Exclude *.Tests.*

# Create distributable archive (requires .NET 4.5)
Add-Type -AssemblyName "System.IO.Compression.FileSystem"
$zipFileName = (Join-Path $cwd "$PackageName-$Version.zip")
If (test-path $zipFileName) {
    Remove-Item $zipFileName -Force
}
$compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
$includeBaseDirectory = $true
[System.IO.Compression.ZipFile]::CreateFromDirectory($assembly, $zipFileName, $compressionLevel, $includeBaseDirectory)

Write-Host "packaged as $zipFileName"
