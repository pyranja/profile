<#
.SYNOPSIS
  Execute powershell unit tests using Pester.
#>
[CmdletBinding()]
Param()

#Requires -Version 5
Set-StrictMode -Version Latest

$cwd = (Join-Path '.' 'dist')
$results = (Join-Path $cwd 'test-results.xml')
New-Item -ItemType Directory $cwd -Force | Out-Null

Import-Module Pester
Invoke-Pester -OutputFile $results -OutputFormat NUnitXml -EnableExit -Strict 2>$null 3>$null
$success = $?

If ($Env:APPVEYOR_JOB_ID) {
    $reportEndpoint = "https://ci.appveyor.com/api/testresults/nunit/$($Env:APPVEYOR_JOB_ID)"
    Write-Host "uploading $results to $reportEndpoint"
    (New-Object 'System.Net.WebClient').UploadFile($reportEndpoint, (Resolve-Path $results))
} else {
    Write-Warning "APPVEYOR_JOB_ID not defined - skipping test result reporting"
}

If (-not $success) {
    Throw "test run failed"
}
