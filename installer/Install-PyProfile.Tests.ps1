$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

function __RunInstaller {
    . "$here\$sut" -SourceBase TestDrive:\source -TargetBase TestDrive:\target @args
}

Describe "Install-PyProfile" {

    BeforeEach {
        New-Item -ItemType Directory -Path TestDrive:\source,TestDrive:\target
        # create empty distribution structure for simplicity
        "dotfiles","py-ps" | ForEach-Object { New-Item -ItemType Directory -Path "TestDrive:\source\$_" }
    }

    AfterEach {
        Remove-Item -Path "TestDrive:\*" -Recurse -ErrorAction Continue
    }

    it "copies dotfiles to user target" {
        Set-Content -Path TestDrive:\source\dotfiles\file.txt -Value "test"

        __RunInstaller

        "TestDrive:\target\file.txt" | Should Exist
        Get-Content TestDrive:\target\file.txt | Should Be "test"
    }

    it "copies py-ps to existing default powershell module path" {
        Set-Content -Path TestDrive:\source\py-ps\py-ps.ps1 -Value "test"
        New-Item -ItemType Directory TestDrive:\target\Documents\WindowsPowerShell\Modules

        __RunInstaller
        
        "TestDrive:\target\Documents\WindowsPowerShell\Modules\py-ps\py-ps.ps1" | Should Exist
        Get-Content TestDrive:\target\Documents\WindowsPowerShell\Modules\py-ps\py-ps.ps1 | Should Be "test"
    }

    it "skips module installation if default powershell module path does not exist" {
        { __RunInstaller -WarningAction Stop } | Should Throw "default module path not found"
    }
}
