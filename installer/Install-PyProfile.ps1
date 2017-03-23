<#
.SYNOPSIS
    Install the 'py-profile'.
.DESCRIPTION
    'py-profile' includes a powershell module with command line helpers and a
    set of default config files.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
Param(
    [Parameter(Mandatory=$False)][string]$SourceBase = (Split-Path $PSCommandPath),
    [Parameter(Mandatory=$False)][string]$TargetBase = (Resolve-Path ~)
)

#Requires -Version 5 -RunAsAdministrator
Set-StrictMode -Version Latest

function main {
    [CmdletBinding()]
    Param()

    __InstallDotfiles
    __InstallPyPs
    __InstallProfileLoader
}

function __InstallDotfiles {
    [CmdletBinding()]
    Param()

    $Source = (Join-Path $SourceBase dotfiles\*)
    $Target = $TargetBase

    __Report "dotfiles" $Source $Target

    Copy-Item -Path $Source -Destination $Target -Recurse -Force
}

function __InstallProfileLoader {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param()

    $Source = (Join-Path $SourceBase ProfileLoader.ps1)
    $Target = $PROFILE

    __Report "profile loader" $Source $Target

    If (Test-Path $Target) {
        # check for installed profile loader
        If (Get-Content $Target | Select-String "RSUjN2ipQNJGgIkEZoJXkaaIRr0mTz86zW5fFXiA3ymGXLfbdu" -Quiet) {
            Write-Verbose "skipping profile loader installation - loader already installed"
            return
        }
        # backup non-loader profile
        $BackupProfileTarget = "$TargetBase\.config\powershell\$(Split-Path -Leaf $Target)"
        If ($PSCmdlet.ShouldProcess($Target, "backup profile to $BackupProfileTarget")) {
            New-Item -Type File -Path $BackupProfileTarget -Value $(Get-Content $Target -Raw) -Force -Confirm:$False | Out-Null
        } else {
            Write-Warning "skipping profile loader installation"
            return
        }
    }
    # install loader
    New-Item -Type Directory -Path $(Split-Path $Target) -Force | Out-Null
    Copy-Item -Path $Source -Destination $Target
}

function __InstallPyPs {
    [CmdletBinding()]
    Param()

    $Source = (Join-Path $SourceBase py-ps)
    $Target = (Join-Path $TargetBase Documents\WindowsPowerShell\Modules)

    __Report "py-ps module" $Source $Target

    If (Test-Path $Target) {
        Remove-Item -Path $(Join-Path $Target py-ps) -Recurse
        Copy-Item -Path $Source -Destination $Target -Recurse -Force
    } Else {
        # avoid copying if module folder is not existing
        # it may mess up the directory structure
        Write-Warning "default module path not found ($Target) - skipping module installation"
    }
}

function __Report {
    [CmdletBinding()]
    Param($Name, $Source, $Target)

    Write-Verbose "installing $Name"
    Write-Verbose "   $Source -> $Target"
}

main
