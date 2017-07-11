<#
.Synopsis
	profile build script.

.Description
	TODO: Declare build script parameters as usual by param().
	The parameters are specified for Invoke-Build on invoking.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][Version]$version = "0.0.0"
)

#Requires -Version 5
Set-StrictMode -Version "Latest"

$package_name = 'py-profile'
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

# Synopsis: prepare profile contents for packaging
task Assemble Init, {
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
    $tools = 'dotfiles', 'tools' | ForEach-Object { Join-Path -Path $PSScriptRoot -ChildPath $_ }
    Copy-Item -Path $tools -Destination $assembly -Recurse -Exclude *.Tests.*
    Copy-Item -Path 'py-profile.nuspec' -Destination $assembly

    # package
    choco pack $(Join-Path -Path $assembly -ChildPath 'py-profile.nuspec' -Resolve) --version=$version --out $workspace
}

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
