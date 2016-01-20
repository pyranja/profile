<#
.SYNOPSIS
    Package the pyps module
#>
[CmdletBinding()]
Param([Parameter(Mandatory = $true)][version]$ModuleVersion)

$ModuleName = 'py-profile'

Write-Host "packaging $ModuleName-$moduleVersion"

$base = (Split-Path $PSCommandPath)
$cwd = (Join-Path $base "dist")
$src = (Join-Path $base "pyps")
$cfg = (Join-Path $base "dotfiles")

$dist = (Join-Path $cwd "$ModuleName")
If (Test-Path $dist) {
    Remove-Item $dist -Force -Recurse
}
New-Item $dist -ItemType Directory | Out-Null

$manifestFileName = Join-Path $dist "$ModuleName.psd1"

New-ModuleManifest `
    -Path $manifestFileName `
    -ModuleVersion $ModuleVersion `
    -Guid 6d07c16c-3181-4844-9f4b-4d8a6a644634 `
    -Author 'Chris Borckholder' `
    -Copyright 'This is free and unencumbered software released into the public domain.' `
    -Description 'Personal dotfiles and utilities.' `
    -PowerShellVersion '3.0' `
    -NestedModules (Get-ChildItem $src -Exclude *.psd1,*.Tests.* | % { $_.Name }) `
    -CmdletsToExport *-* `
    -FunctionsToExport *-*

# Copy the distributable files to the dist folder.
Get-ChildItem $src -Recurse -Exclude *.Tests.* | Copy-Item -Destination $dist -Recurse
Copy-Item -Path $cfg -Destination $dist -Recurse

# Requires .NET 4.5
Add-Type -AssemblyName "System.IO.Compression.FileSystem"
$zipFileName = (Join-Path $cwd "$ModuleName-$ModuleVersion.zip")
If (test-path $zipFileName) {
    Remove-Item $zipFileName -Force
}
$compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
$includeBaseDirectory = $true
[System.IO.Compression.ZipFile]::CreateFromDirectory($dist, $zipFileName, $compressionLevel, $includeBaseDirectory)

Write-Host "packaged as $zipFileName"
