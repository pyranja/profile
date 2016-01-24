<#
.SYNOPSIS
    Install the 'py-profile'.
.DESCRIPTION
    'py-profile' includes a powershell module with command line helpers and a 
    set of default config files.
#>
[CmdletBinding(SupportsShouldProcess=$true)]
Param()

$base = (Split-Path $PSCommandPath)

$source = (Join-Path $base dotfiles)
$target = (Resolve-Path ~)
Write-Verbose "installing dotfiles"
Write-Verbose "   $source -> $target"
Get-ChildItem $source -Recurse | Copy-Item -Destination $target -Recurse -Force

$source = (Join-Path $base 'py-ps')
$target = (Resolve-Path ~\Documents\WindowsPowerShell\Modules)
Write-Verbose "installing py-ps module"
Write-Verbose "   $source -> $target"
Copy-Item -Path $source -Destination $target -Recurse -Force
