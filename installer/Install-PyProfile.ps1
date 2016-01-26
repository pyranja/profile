<#
.SYNOPSIS
    Install the 'py-profile'.
.DESCRIPTION
    'py-profile' includes a powershell module with command line helpers and a
    set of default config files.
#>
[CmdletBinding(SupportsShouldProcess=$True)]
Param(
    [Parameter(Mandatory=$False)][string]$SourceBase = (Split-Path $PSCommandPath),
    [Parameter(Mandatory=$False)][string]$TargetBase = (Resolve-Path ~)
)

$Source = (Join-Path $SourceBase dotfiles\*)
$Target = $TargetBase
Write-Verbose "installing dotfiles"
Write-Verbose "   $Source -> $Target"
Copy-Item -Path $Source -Destination $Target -Recurse -Force

$Source = (Join-Path $SourceBase py-ps)
$Target = (Join-Path $TargetBase Documents\WindowsPowerShell\Modules)
Write-Verbose "installing py-ps module"
Write-Verbose "   $Source -> $Target"
If (Test-Path $Target) {
    Copy-Item -Path $Source -Destination $Target -Recurse -Force
} Else {  # if target is not existing, folder structure is messed up after copy
    Write-Warning "default module path not found ($Target) - skipping module installation"
}
