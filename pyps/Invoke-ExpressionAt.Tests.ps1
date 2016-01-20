$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

# save invocation location to restore it after test runs
$origin = Get-Location
# transient folder to be used in tests
$cwd = Join-Path (Resolve-Path $env:TEMP) ([system.guid]::NewGuid().ToString())

Describe "Invoke-ExpressionAt" {
    # suppress script output
    Mock Write-Host {}
    Mock Write-Warning {}

    BeforeEach {
        $Error.Clear()
        Set-Location $origin
        Remove-Item -Path $cwd -Recurse -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $cwd -Force
    }
    
    AfterEach {
        Set-Location $origin
        Remove-Item -Path $cwd -Recurse
    }

    It "accepts named parameters" {
        Invoke-ExpressionAt -Path $cwd -Command "Get-Host"
    }

    It "executes the given command" {
        Invoke-ExpressionAt -Path $cwd Write-Output argument | Should Be "argument"
    }

    It "sets execution status on successful command" {
        Invoke-ExpressionAt -Path $cwd Get-Location
        $? | Should Be True
    }
    
    It "propagates failure of commands" {
        { Invoke-ExpressionAt -ErrorAction Stop -Path $cwd Get-Item /notthere } | Should Throw "Cannot find path"
    }

    Context "Legacy Commands" {
        It "can execute legacy commands" {
            Invoke-ExpressionAt -Path $cwd cmd.exe /c "echo test" | Should Be "test"
        }

        It "propagates success exit code of legacy commands" {
            Invoke-ExpressionAt -Path $cwd cmd.exe /c EXIT /B 0
            $? | Should Be True
        }

        It "propagates failure of legacy commands" {
            { Invoke-ExpressionAt -ErrorAction Stop -Path $cwd cmd.exe /c EXIT /B 1 } | Should Throw "exit code 1"
        }
    }

    Context "Locations" {
        It "changes directory" {
            (Invoke-ExpressionAt -Path $cwd Get-Location).Path | Should Be (Get-Item $cwd).FullName
        }

        It "returns to initial directory" {
            $initial = Get-Location
            Invoke-ExpressionAt -Path $cwd Get-Host
            $(Get-Location).Path | Should Be $initial.Path
        }

        It "returns to initial directory even if command throws" {
            $initial = Get-Location
            { Invoke-ExpressionAt -Path $cwd "throw 'test error'" } | Should Throw "test error"
            $(Get-Location).Path | Should Be $initial.Path
        }

        It "fails if target location is not accessible" {
            { Invoke-ExpressionAt -ErrorAction Stop -Path /not-existing Get-Location } | Should Throw "Cannot find path"
        }
    }

    Context "piped paths" {
        It "executes command once for each piped path" {
            function PipePathsCommand {}
            Mock PipePathsCommand {}
            $cwd,$cwd,$cwd  | Invoke-ExpressionAt -Command PipePathsCommand
            Assert-MockCalled PipePathsCommand -Times 3 -Exactly
        }

        It "skips missing paths" {
            function SkipPathCommand {}
            Mock SkipPathCommand {}
            $cwd,"/notthere",$cwd  | Invoke-ExpressionAt -Command SkipPathCommand
            Assert-MockCalled SkipPathCommand -Times 2 -Exactly
            $Error[0] | Should Match "Cannot find Path"
        }

        It "accepts PSPath from piped gci" {
            "one","two" | ForEach-Object { New-Item -ItemType Directory -Path "$cwd/$_" -Force }
            Get-ChildItem $cwd | Invoke-ExpressionAt -Command Get-Location | Should Exist
        }
    }

    Context "paths as list" {
        It "executes command once for each given path" {
            function ListPathsCommand {}
            Mock ListPathsCommand {}
            Invoke-ExpressionAt -Path $cwd,$cwd,$cwd -Command ListPathsCommand
            Assert-MockCalled ListPathsCommand -Times 3 -Exactly
        }

        It "skips missing paths" {
            function ListSkipPathCommand {}
            Mock ListSkipPathCommand {}
            Invoke-ExpressionAt -Path $cwd,"/notthere",$cwd -Command ListSkipPathCommand
            Assert-MockCalled ListSkipPathCommand -Times 2 -Exactly
            $Error[0] | Should Match "Cannot find Path"
        }
    }

    
    Context "Invoke-SpreadExpression" {
        It "fails if no .spread found" {
            { Invoke-SpreadExpression Get-Location } | Should Throw "Cannot find path"
        }

        It "executes command in each path defined in .spread" {
            $config = $(Join-Path $cwd ".spread")
            $actual = $(Join-Path $cwd "result")
            $(Join-Path $cwd "one"),$(Join-Path $cwd "two") | Out-File $config
            Get-Content $config | ForEach-Object { New-Item -ItemType Directory -Path $_ -Force }
            $(Invoke-SpreadExpression -PathFile $config Get-Item .).Name | Out-File $actual
            $actual | Should Contain "one"
            $actual | Should Contain "two"
        }

        It "executes all commands from pipeline" {
            $config= $(Join-Path $cwd ".spread")
            $actual = $(Join-Path $cwd "result")
            $cwd | Out-File $config
            Get-Content $config | ForEach-Object { New-Item -ItemType Directory -Path $_ -Force }
            "Write-Output test","Write-Output more" | Invoke-SpreadExpression -PathFile $config | Out-File $actual
            $actual | Should Contain "test"
            $actual | Should Contain "more"
        }
    }
}
