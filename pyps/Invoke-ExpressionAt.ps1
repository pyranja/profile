<#
.SYNOPSIS
    Execute shell expressions in different locations.
#>

New-Alias spread Spread-Expression

function Spread-Expression {
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
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true, ValueFromRemainingArguments=$true)][string]$Command,
          [Parameter(Mandatory=$false)][string]$PathFile = './.spread')

    Begin {
        $Paths = $(Get-Content -ErrorAction Stop $PathFile)
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
    Param([string]$Path, [string]$Command)

    Write-Host "`n$Path\$Command`n"
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
    Param([string]$It)

    $Global:LASTEXITCODE = $null
    Invoke-Expression $It
    if ($Global:LASTEXITCODE) {
        Write-Error -Category OperationStopped -CategoryActivity "Invocation" -TargetObject $It "$(Get-Location).Path/$It failed (exit code $LASTEXITCODE)"
    }
}
