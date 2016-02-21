<#
.SYNOPSIS
    Tooling for installing and updating of py-profile
#>

Set-StrictMode -Version Latest

function Get-LatestVersion {
    <#
    .SYNOPSIS
        Retrieve the latest available version of py-profile.
    #>
    [CmdletBinding()]
    Param()

    $Response = Invoke-RestMethod -Method GET -Uri https://api.github.com/repos/pyranja/profile/releases/latest -TimeoutSec 10
    $Match = [regex]::matches($Response.Name, 'py-profile-(.+)')

    If ($Match.Success) {
        Write-Output ([Version]$Match.Groups[1].Value)
    } Else {
        Write-Error "failed to parse version from release name" -Category InvalidResult -TargetObject $Response.Name
    }
}

function Update-Profile {
    <#
    .SYNOPSIS
        Upgrade to the latest version of py-profile if a more recent one is available.
    .DESCRIPTION
        Compare the currently installed version to the most recent one. If an upgrade is available, the release is
        downloaded, unpacked and its installer executed. To let all changes take effect, it may be necessary to
        start a new powershell session.
    .PARAMETER Cwd
        Override the upgrade working directory (defaults to a temporary folder)
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]$Cwd = $( Join-Path (Resolve-Path $Env:TEMP) ([system.guid]::NewGuid().ToString()) )
    )

    $LatestVersion = $(Get-LatestVersion)
    $CurrentVersion = __version

    If ($CurrentVersion -ge $LatestVersion) {
        Write-Host "Already up to date (v$CurrentVersion)"
        return $false
    }

    Write-Host "Updating v$CurrentVersion -> v$LatestVersion"
    # TODO confirm upgrade
    __fetchRelease $Cwd
    Invoke-Expression "$Cwd\py-profile\Install-PyProfile.ps1"
}

function __version {
    $MyInvocation.MyCommand.Module.Version
}

function __fetchRelease {
    [CmdletBinding()]
    Param([string]$Path)

    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    # must convert from PS path to literal path for call to ExtractToDirectory
    # see http://stackoverflow.com/a/13073808/1267168
    $Cwd = Resolve-Path $Path -ErrorAction Stop | Select-Object -ExpandProperty ProviderPath
    Write-Verbose "Using $Cwd as working directory"

    $Asset = $(Invoke-RestMethod -Method GET -Uri https://api.github.com/repos/pyranja/profile/releases/latest -TimeoutSec 10).assets[0]
    $Url = $Asset.url
    $ZipFile = Join-Path $Cwd $Asset.name

    Write-Verbose "Downloading $Url"
    Invoke-WebRequest -Uri $Url -OutFile $ZipFile -Headers @{'Accept'="$($Asset.content_type)"} -TimeoutSec 10

    Write-Verbose "Unpacking $ZipFile"
    Add-Type -AssemblyName "System.IO.Compression.FileSystem"
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $Cwd)
}
