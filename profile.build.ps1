<#
.Synopsis
	profile build script.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][Version]$Version = "0.0.0",
    [Parameter(Mandatory = $false)][string]$PsGalleryApiKey = $Env:PSGALLERY_API_KEY,
    [Parameter(Mandatory = $false)][string]$BintrayApiKey = $Env:BINTRAY_API_KEY,
    [switch]$ForcePublish = $false
)

#Requires -Version 5
Set-StrictMode -Version "Latest"

$workspace = $(Join-Path $BuildRoot "dist")
$module_name = 'py-ps'
$package_name = 'py-profile'

### meta tasks

task . Test, Analyze, Assemble

# Synopsis: install build dependencies if necessary
task Bootstrap {
    $PSVersionTable # diagnostics
    Install-Module Pester -Verbose -MinimumVersion 4.0.8 -SkipPublisherCheck -Force -Scope CurrentUser
    Install-Module PSScriptAnalyzer -Verbose -MinimumVersion 1.15.0 -Force -Scope CurrentUser
}

# Synopsis: meta task to run unit tests and analysis during ci
task Verify CiTest, CiAnalyze

# Synopsis: meta task to exec each individual assemble
task Assemble Assemble-Profile,Assemble-PyPs

# Synopsis: meta task to exec each individual publish
task Publish -If { ShouldPublish } Publish-PyPs,Publish-Profile

### individual tasks

# Synopsis: clear build output
task Clean {
    Remove-Item -Path $workspace -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
}

# Synopsis: create build workspace
task Init {
    New-Item -Path $workspace -ItemType Directory -Force | Out-Null
}

$module_artifact = "$workspace/py-ps.$Version.zip"

# Synopsis: assemble py-ps powershell module and create a release zip ball
task Assemble-PyPs -Inputs { Get-ChildItem -Path $module_name -Recurse -File } -Outputs { $module_artifact } Init, {
    $target = Join-Path -Path $workspace -ChildPath $module_name
    EnsureExistsAndEmpty $target

    Get-ChildItem -Path $module_name -Exclude *.Tests.* | Copy-Item -Recurse -Destination "$target"

    New-ModuleManifest `
        -Path $(Join-Path $target "$module_name.psd1") `
        -ModuleVersion $Version `
        -Guid 6d07c16c-3181-4844-9f4b-4d8a6a644634 `
        -Author 'Chris Borckholder' `
        -CompanyName 'Personal' `
        -Copyright 'This is free and unencumbered software released into the public domain.' `
        -Description 'Personal dotfiles and utilities.' `
        -Tags 'pyranja','dotfiles','personal' `
        -ProjectUri 'https://github.com/pyranja/profile' `
        -LicenseUri 'https://github.com/pyranja/profile/blob/master/LICENSE' `
        -PowerShellVersion '5.0' `
        -DefaultCommandPrefix 'Py' `
        -NestedModules $(Get-ChildItem "$target" -Recurse -Include *.ps1 | ForEach-Object { $_.Name }) `
        -CmdletsToExport *-* `
        -FunctionsToExport *-* `
        -AliasesToExport '__none' `
        -VariablesToExport '__none'

    Compress-Archive -Path $target -DestinationPath $module_artifact -CompressionLevel Optimal -Force
}

# Synopsis: push powershell module to PSGallery
task Publish-PyPs Assemble-PyPs, {
    assert($PsGalleryApiKey) "PSGALLERY_API_KEY not set"

    $artifact = $(Join-Path -Path $workspace -ChildPath $module_name -Resolve)
    assert(Test-Path $artifact) "artifact missing - run Invoke-Build Assemble"

    Publish-Module `
        -Path $artifact `
        -NuGetApiKey $PsGalleryApiKey `
        -Repository PSGallery `

    Add-AppveyorMessage -Message "$module_name $Version published" -Category Information
}

$profile_contents = 'dotfiles', 'tools'

# Synopsis: assemble profile as nuget package
task Assemble-Profile -Inputs { Get-ChildItem $profile_contents -Recurse -File } -Outputs { "$workspace/$package_name.$Version.nupkg" } Init, {
    $target = Join-Path -Path $workspace -ChildPath $package_name
    EnsureExistsAndEmpty $target

    # gather contents in dist folder
    Copy-Item -Path $profile_contents -Destination $target -Recurse -Exclude *.Tests.*
    Copy-Item -Path 'py-profile.nuspec' -Destination $target

    # package it
    exec { choco pack $(Join-Path -Path $target -ChildPath 'py-profile.nuspec' -Resolve) --version=$Version --outputdirectory $workspace }
}

# Synopsis: push nuget pkg to bintray feed
task Publish-Profile Assemble-Profile, {
    assert($BintrayApiKey) "BINTRAY_API_KEY not set"

    # ignore error on add as it may already be configured
    nuget sources Add -Name bintray -Source https://api.bintray.com/nuget/pyranja/py-get -UserName pyranja -Password $BintrayApiKey -Verbosity detailed -NonInteractive
    $nuget_filename = "$package_name.$Version.nupkg"
    $artifact = Join-Path $workspace $nuget_filename -Resolve
    exec { nuget push $artifact -Source bintray -ApiKey "pyranja:$BintrayApiKey" -NoSymbols -NonInteractive }
    Add-AppveyorMessage -Message "$nuget_filename published" -Category Information
}

# Synopsis: run PSScriptAnalyzer
task Analyze {
    $module_name,'tools' | ForEach-Object { Invoke-ScriptAnalyzer -Path $(Join-Path $BuildRoot $_) -Recurse }
}

# Synopsis: run unit tests
task Test Init, {
    Invoke-Pester -Strict 2>$null 3>$null
}

# Synopsis: run script analyzer with ci configuration
task CiAnalyze {
    Write-Host 'run PSScriptAnalyzer'
    Add-AppveyorTest -Name 'PsScriptAnalyzer' -Outcome running
    $analyzer_results = Get-Item -Path $module_name,'tools' | ForEach-Object { Invoke-ScriptAnalyzer -Path $_ -Recurse }

    if ($analyzer_results) {
        Update-AppveyorTest -Name 'PsScriptAnalyzer' -Outcome Failed -ErrorMessage $($analyzer_results | Out-String)
        Add-AppveyorMessage -Message 'task CiAnalyze failed' -Category Error
        Throw 'PSScriptAnalyzer failed'
    } else {
        Write-Host 'PSScriptAnalyzer passed'
        Update-AppveyorTest -Name 'PsScriptAnalyzer' -Outcome Passed
    }
}

# Synopsis: run unit tests with ci configuration
task CiTest Init, {
    $results = Join-Path $workspace 'test-results.xml'

    Invoke-Pester -OutputFile $results -OutputFormat NUnitXml -EnableExit -Strict 2>$null 3>$null
    $success = $?

    ReportTestResults $results

    If (-not $success) {
        Add-AppveyorMessage -Message 'task CiTest failed' -Category Error
        Throw 'Pester unit test run failed'
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
    Ensure the given $target folder exists and is empty
    #>
    Param([string] $target)

    Remove-Item -Path $target -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
    New-Item -Path $target -ItemType Directory -Force | Out-Null
}

function ShouldPublish {
    <#
    .SYNOPSIS
    Check if a release build is running
    #>
    $isReleaseBuild = ($Env:APPVEYOR) -and ($Env:APPVEYOR_REPO_BRANCH -eq 'master') -and (-not $Env:APPVEYOR_PULL_REQUEST_NUMBER)

    if (-not $isReleaseBuild) {
        $message = @"
Skipping publish based on environment 
    APPVEYOR == <$Env:APPVEYOR>
    APPVEYOR_REPO_BRANCH == <$Env:APPVEYOR_REPO_BRANCH>
    APPVEYOR_PULL_REQUEST_NUMBER == <$Env:APPVEYOR_PULL_REQUEST_NUMBER>

"@
        Write-Warning $message
    }

    $ForcePublish -or $isReleaseBuild
}
