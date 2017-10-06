<#
.SYNOPSIS
    Execute shell expressions in different locations.
#>

#Requires -Version 5
Set-StrictMode -Version Latest

function Set-SpreadFile {
    <#
    .SYNOPSIS
        Create or update a .spread file containing all child directories.

    .DESCRIPTION
        Bootstrap or update a .spread file to be used with
        Invoke-SpreadExpression in the target folder. By default all sub
        directories are included in the .spread file.

    .PARAMETER Path
        Path where the .spread file should be created, defaults to the current
        location.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact=[System.Management.Automation.ConfirmImpact]::Medium)]
    Param([Parameter(Mandatory=$false)][string]$Path = $(Get-Location))

    $Target = $(Join-Path $Path '.spread')

    If ($PSCmdlet.ShouldProcess($Target)) {
        Get-ChildItem -Path $Path -Name -Directory > $Target
    }
}

function Invoke-SpreadExpression {
    <#
    .SYNOPSIS
        Invoke given expression in multiple paths.
    .DESCRIPTION
        By default the target paths are read from a local ./.spread file.
        Each line should contain a target path. The expression is created by
        concatenating all positional arguments. Alternatively expressions
        may be passed through the pipeline.
    .PARAMETER Command
        The expression to run.
    .PARAMETER PathFile
        Override the source file for target paths.
    #>
    [CmdletBinding(DefaultParameterSetName='IMPLICIT_SPREAD_PATH')]
    Param([Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true, ValueFromRemainingArguments=$true)][string]$Command,
          [Parameter(ParameterSetName='EXPLICIT_SPREAD_PATH',Mandatory=$true)][string]$PathFile)

    Begin {
        switch ($PSCmdlet.ParameterSetName) {
            "EXPLICIT_SPREAD_PATH" { $Paths = (Get-Content -ErrorAction Stop $PathFile) }
            "IMPLICIT_SPREAD_PATH" {
                If (Test-Path '.\.spread') {
                    $Paths = (Get-Content -ErrorAction Stop '.\.spread')
                } Else {
                    $Paths = (Get-ChildItem -Name -Directory)
                }
            }
            default { Throw "Illegal parameter set $PSCmdlet.ParameterSetName" }
        }
    }

    Process {
        $Paths | Invoke-ExpressionAt -Command $Command
    }
}

function Invoke-ExpressionAt {
    <#
    .SYNOPSIS
        Run an expression in a given path.
    .DESCRIPTION
        The expression is only run if the target path actually exists.
        If multiple paths are specified, the expression is run sequentially
        in each of them.
        The expressions's execution status and return code is inspected to
        determine whether it succeeded. If a failure is detected,
        a non-terminating error is raised.
    .PARAMETER Path
        The path where the expression is run.
    .PARAMETER Command
        The expression to run.
    #>
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)][alias("PSPath")][string[]]$Path,
          [Parameter(Mandatory=$true, Position=0, ValueFromRemainingArguments=$true)][string]$Command)

    Process {
        $Path | ForEach-Object { __HandleSingleExpression $_ $Command }
    }
}

function __HandleSingleExpression {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    Param([string]$Path, [string]$Command)

    # text output is purely informational for user - do NOT use Write-Output
    Write-Host "`n$Path> $Command`n" -ForegroundColor Cyan
    Push-Location $Path -StackName invoke
    if ($?) {
        try {
            __ExecuteExpression $Command
        } finally {
            Pop-Location -StackName invoke
        }
    } else {
        Write-Warning "cannot access location - skipping $Path\$Command"
    }
}

function __ExecuteExpression {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingInvokeExpression", "")]
    Param([string]$It)

    $Global:LASTEXITCODE = $null
    Invoke-Expression $It
    if ($Global:LASTEXITCODE) {
        Write-Error -Category OperationStopped -CategoryActivity "Invocation" -TargetObject $It "$(Get-Location).Path/$It failed (exit code $LASTEXITCODE)"
    }
}
