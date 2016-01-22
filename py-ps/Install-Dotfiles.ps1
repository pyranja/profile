<#
.SYNOPSIS
  Installs default configurations to user home.
#>
[CmdletBinding()]
Param()

$cfg = (Join-Path (Split-Path $PSCommandPath) "dotfiles")
$target = (Resolve-Path ~)

Write-Host "installing dotfiles from $cfg into $target"
Get-ChildItem $cfg -Recurse | Copy-Item -Destination $target -Recurse -Force
