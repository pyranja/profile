<#
.SYNOPSIS
    modular powershell profile loader
.DESCRIPTION
    Execute all scripts from '~\.config\powershell' with the filename matching '*_profile.ps1'.
    The order of execution is not specified (it may be random and/or platform dependent).

##### do not modify this identifier comment! #####
RSUjN2ipQNJGgIkEZoJXkaaIRr0mTz86zW5fFXiA3ymGXLfbdu
#>
Get-Item ~\.config\powershell\*_profile.ps1 -ErrorAction SilentlyContinue | ForEach-Object { . $_ }
