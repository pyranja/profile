<#
.Synopsis
	profile build script.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][Version]$version = "0.0.0"
)

#Requires -Version 5
Set-StrictMode -Version "Latest"

$workspace = $(Join-Path $PSScriptRoot "dist")

task . Assemble, Test

# Synopsis: clear build output
task Clean {
    Remove-Item -Path $workspace -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
}

# Synopsis: create build workspace
task Init {
    New-Item -Path $workspace -ItemType Directory -Force | Out-Null
}

# Synopsis: assemble py-ps powershell module
task Assemble-PyPs Init, {
    $module_name = 'py-ps'
    $target = Join-Path -Path $workspace -ChildPath $module_name
    EnsureExistsAndEmpty $target

    Get-ChildItem -Path $(Join-Path $PSScriptRoot $module_name) -Exclude *.Tests.* | Copy-Item -Recurse -Destination "$target"

    New-ModuleManifest `
        -Path $(Join-Path $target "$module_name.psd1") `
        -ModuleVersion $version `
        -Guid 6d07c16c-3181-4844-9f4b-4d8a6a644634 `
        -Author 'Chris Borckholder' `
        -CompanyName 'Personal' `
        -Copyright 'This is free and unencumbered software released into the public domain.' `
        -Description 'Personal dotfiles and utilities.' `
        -PowerShellVersion '5.0' `
        -DefaultCommandPrefix 'Py' `
        -NestedModules $(Get-ChildItem "$target" -Recurse -Include *.ps1 | ForEach-Object { $_.Name }) `
        -CmdletsToExport *-* `
        -FunctionsToExport *-* `
        -AliasesToExport '__none' `
        -VariablesToExport '__none'
}

# Synopsis: assemble profile nuget package
task Assemble-Profile Init, {
    $package_name = 'py-profile'
    $target = Join-Path -Path $workspace -ChildPath $package_name
    EnsureExistsAndEmpty $target

    # gather contents in temp folder
    $contents = 'dotfiles', 'tools' | ForEach-Object { Join-Path -Path $PSScriptRoot -ChildPath $_ -Resolve }
    Copy-Item -Path $contents -Destination $target -Recurse -Exclude *.Tests.*
    Copy-Item -Path 'py-profile.nuspec' -Destination $target

    # package it
    choco pack $(Join-Path -Path $target -ChildPath 'py-profile.nuspec' -Resolve) --version=$version --out $workspace
}

# Synopsis: meta task to exec each individual assemble
task Assemble Assemble-Profile,Assemble-PyPs, {}

# Synopsis: run unit tests
task Test Init, {
    Invoke-Pester -Strict 2>$null 3>$null
}

# Synopsis: run unit tests with ci configuration
task CiTest Init, {
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

function EnsureExistsAndEmpty {
    <#
    .SYNOPSIS
    ensure the given $target folder exists and is empty
    #>
    Param([string] $target)

    Remove-Item -Path $target -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
    New-Item -Path $target -ItemType Directory -Force | Out-Null
}
