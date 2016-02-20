<#
.SYNOPSIS
    Tooling for installing and updating of py-profile
#>

function Get-LatestVersion {
    [CmdletBinding()]
    Param()

    $response = Invoke-RestMethod -Method GET -Uri https://api.github.com/repos/pyranja/profile/releases/latest -TimeoutSec 10
    $match = [regex]::matches($response.Name, 'py-profile-(.+)')

    If ($match.Success) {
        Write-Output ([Version]$match.Groups[1].Value)
    } Else {
        Write-Error "failed to parse version from release name" -Category InvalidResult -TargetObject $response.Name
    }
}