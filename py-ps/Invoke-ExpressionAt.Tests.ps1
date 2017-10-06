#Requires -Version 5
Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

# prevent -Confirm prompts
$script:ConfirmPreference = [System.Management.Automation.ConfirmImpact]::None

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
            $cwd,"/notthere",$cwd  | Invoke-ExpressionAt -ErrorAction Continue -ErrorVariable pipe_error -Command SkipPathCommand
            Assert-MockCalled SkipPathCommand -Times 2 -Exactly
            $pipe_error[0] | Should Match "Cannot find Path"
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
            Invoke-ExpressionAt -Path $cwd,"/notthere",$cwd -ErrorAction Continue -ErrorVariable pipe_error -Command ListSkipPathCommand
            Assert-MockCalled ListSkipPathCommand -Times 2 -Exactly
            $pipe_error[0] | Should Match "Cannot find Path"
        }
    }

    
    Context "Invoke-SpreadExpression" {
        It "fails if no .spread found" {
            Set-Location TestDrive:\

            { Invoke-SpreadExpression Get-Location } | Should Throw "Cannot find path"
        }

        It "executes command in each path defined in .spread" {
            $config = $(Join-Path $cwd ".spread")
            $actual = $(Join-Path $cwd "result")
            $(Join-Path $cwd "one"),$(Join-Path $cwd "two") | Out-File $config
            Get-Content $config | ForEach-Object { New-Item -ItemType Directory -Path $_ -Force }
            $(Invoke-SpreadExpression -PathFile $config Get-Item .).Name | Out-File $actual
            $actual | Should FileContentMatch "one"
            $actual | Should FileContentMatch "two"
        }

        It "executes all commands from pipeline" {
            $config= $(Join-Path $cwd ".spread")
            $actual = $(Join-Path $cwd "result")
            $cwd | Out-File $config
            Get-Content $config | ForEach-Object { New-Item -ItemType Directory -Path $_ -Force }
            "Write-Output test","Write-Output more" | Invoke-SpreadExpression -PathFile $config | Out-File $actual
            $actual | Should FileContentMatch "test"
            $actual | Should FileContentMatch "more"
        }
    }
}

Describe "Set-SpreadFile" {
    BeforeEach {
        Remove-Item -Recurse TestDrive:\*
    }

    $origin = Get-Location

    AfterEach {
        Set-Location $origin
        Remove-Item -Recurse TestDrive:\*
    }

    It "creates a .spread file" {
        Set-SpreadFile -Path TestDrive:\

        "TestDrive:\.spread" | Should Exist
    }

    It "creates an empty spread file if no sub directories exist" {
        Set-SpreadFile -Path TestDrive:\

        Get-Content "TestDrive:\.spread" | Should BeNullOrEmpty
    }

    It "includes all sub directories in created file" {
        @('first', 'second') | ForEach-Object { New-Item -ItemType Directory -Path "TestDrive:\$_" }

        Set-SpreadFile -Path TestDrive:\

        @(Get-Content "TestDrive:\.spread").Count | Should Be 2
        "TestDrive:\.spread" | Should FileContentMatch "first"
        "TestDrive:\.spread" | Should FileContentMatch "second"
    }

    It "ignores child items which are files" {
        @('first', 'second') | ForEach-Object { New-Item -ItemType File -Path "TestDrive:\$_" }

        Set-SpreadFile -Path TestDrive:\

        Get-Content "TestDrive:\.spread" | Should BeNullOrEmpty
    }

    It "correctly handles mixed child content" {
        New-Item -ItemType Directory -Path TestDrive:\folder
        New-Item -ItemType File -Path TestDrive:\file

        Set-SpreadFile -Path TestDrive:\

        @(Get-Content "TestDrive:\.spread").Count | Should Be 1
        "TestDrive:\.spread" | Should FileContentMatch "folder"
        "TestDrive:\.spread" | Should Not FileContentMatch "file"
    }

    It "uses current location as default" {
        New-Item -ItemType Directory -Path TestDrive:\iamhere
        New-Item -ItemType Directory -Path TestDrive:\iamhere\folder
        New-Item -ItemType File -Path TestDrive:\iamhere\file

        Set-Location TestDrive:\iamhere
        Set-SpreadFile

        @(Get-Content "TestDrive:\iamhere\.spread").Count | Should Be 1
        "TestDrive:\iamhere\.spread" | Should FileContentMatch "folder"
        "TestDrive:\iamhere\.spread" | Should Not FileContentMatch "file"

        "TestDrive:\.spread" | Should Not Exist
    }

    It "does nothing when called with -WhatIf" {
        Set-SpreadFile -Path TestDrive:\ -WhatIf

        "TestDrive:\.spread" | Should Not Exist
    }

    It "overwrite existing .spread file" {
        @("old", "older") | Set-Content TestDrive:\.spread
        "TestDrive:\.spread" | Should Exist

        New-Item -ItemType Directory -Path TestDrive:\new
        Set-SpreadFile -Path TestDrive:\

        @(Get-Content "TestDrive:\.spread").Count | Should Be 1
        "TestDrive:\.spread" | Should FileContentMatch "new"
        "TestDrive:\.spread" | Should Not FileContentMatch "old"
        "TestDrive:\.spread" | Should Not FileContentMatch "older"
    }
}
