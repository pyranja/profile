<#
    .SYNOPSIS profile build script
#>

#Requires -Version 5 -RunAsAdministrator
Set-StrictMode -Version "Latest"

Properties {
    $package_name = 'py-profile'
    $version = [Version]"0.0.0"
    $workspace = $(Join-Path $PSScriptRoot "dist")
}

FormatTaskName "profile::{0}"

Task Default -Depends Package, Test

Task Clean -description "clear build output" {
    Remove-Item -Path $workspace -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
}

Task Init -description "create build workspace" {
    New-Item -Path $workspace -ItemType Directory -Force | Out-Null
}

Task Assemble -depends Init -description "prepare profile contents for packaging" {
    $assembly = (Join-Path $workspace $package_name)
    Remove-Item -Path $assembly -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
    New-Item -Path $assembly -ItemType Directory | Out-Null

    # Assemble powershell module
    $module_name = 'py-ps'
    $ModuleSources = (Join-Path $PSScriptRoot $module_name)

    New-Item -Path "$assembly\$module_name" -ItemType Directory -Force | Out-Null
    Get-ChildItem -Path $ModuleSources -Exclude *.Tests.* | Copy-Item -Recurse -Destination "$assembly\$module_name"

    New-ModuleManifest `
        -Path (Join-Path $assembly "$module_name\$module_name.psd1") `
        -ModuleVersion $version `
        -Guid 6d07c16c-3181-4844-9f4b-4d8a6a644634 `
        -Author 'Chris Borckholder' `
        -Copyright 'This is free and unencumbered software released into the public domain.' `
        -Description 'Personal dotfiles and utilities.' `
        -PowerShellVersion '3.0' `
        -DefaultCommandPrefix 'Py' `
        -NestedModules $(Get-ChildItem "$assembly\$module_name" -Recurse -Include *.ps1 | ForEach-Object { $_.Name }) `
        -CmdletsToExport *-* `
        -FunctionsToExport *-* `
        -AliasesToExport '__none' `
        -VariablesToExport '__none'

    # Copy non-shell resources
    $assets = 'dotfiles', 'installer/*' | ForEach-Object { Join-Path -Path $PSScriptRoot -ChildPath $_ }
    Copy-Item -Path $assets -Destination $assembly -Recurse -Exclude *.Tests.*
}

Task Package -depends Assemble -description "package profile as zip file" {
    $zip_file = (Join-Path $workspace "$package_name-$version.zip")
    Remove-Item -Path $zip_file -Force -Recurse -ErrorAction SilentlyContinue | Out-Null

    Compress-Archive -Path $(Join-Path $workspace $package_name) -DestinationPath $zip_file -CompressionLevel Optimal
}

Task Test -depends Init -description "run unit tests" {
    Invoke-Pester -Strict 2>$null 3>$null
}

Task CiTest -depends Init -description "run unit tests with ci configuration" {
    $results = Join-Path $workspace 'test-results.xml'

    Invoke-Pester -OutputFile $results -OutputFormat NUnitXml -EnableExit -Strict 2>$null 3>$null
    $success = $?

    ReportTestResults $results

    If (-not $success) {
        Throw "test run failed"
    }
}

function ReportTestResults {
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateScript( {Test-Path $_ -PathType Leaf})]
        [string] $results
    )

    If ($Env:APPVEYOR_JOB_ID) {
        $reportEndpoint = "https://ci.appveyor.com/api/testresults/nunit/$($Env:APPVEYOR_JOB_ID)"
        Write-Host "uploading $results to $reportEndpoint"
        (New-Object 'System.Net.WebClient').UploadFile($reportEndpoint, (Resolve-Path $results))
    }
    else {
        Write-Warning "APPVEYOR_JOB_ID not defined - skipping test result reporting"
    }
}
