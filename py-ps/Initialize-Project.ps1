<#
.SYNOPSIS
    Project bootstrapping.
#>

#Requires -Version 5
Set-StrictMode -Version Latest

# project skeleton is installed besides module
$ProjectSkeletonLocation = $(Join-Path $(Split-Path -Parent $PSCommandPath) project-skeleton)

function Initialize-Project {
    <#
    .SYNOPSIS
        Create a git-based project at target location.
    .DESCRIPTION
        Sets up the git repository and imports basic config files.
    #>
    [CmdletBinding()]
    Param([Parameter(Mandatory=$false)][string]$Path = $(Get-Location))

    If (-not $(Test-Path $Path)) {
        New-Item -ItemType Directory $Path
    }

    Push-Location -StackName __Initialize-Project__ $Path
    try {
        git init
        Copy-Item -Recurse "$ProjectSkeletonLocation\*"
        git add .
    } finally {
        Pop-Location -StackName __Initialize-Project__
    }
}
