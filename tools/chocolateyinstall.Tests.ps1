Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

function __RunInstaller {
    . "$here\$sut" -SourceBase TestDrive:\source -TargetBase TestDrive:\target @args -Confirm:$False
}

Describe "Install-PyProfile" {

    Mock -CommandName Install-Module -MockWith { return $true }
    Mock -CommandName Update-Module -MockWith { return $true }

    BeforeEach {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
        $PROFILE = "TestDrive:/profile/default_profile.ps1" # avoid overwriting real profile file
        New-Item -ItemType Directory -Path TestDrive:\source,TestDrive:\target
        # create empty distribution structure for simplicity
        "dotfiles","tools" | ForEach-Object { New-Item -ItemType Directory -Path "TestDrive:\source\$_" }
        New-Item -Type File -Path TestDrive:\source\tools\ProfileLoader.ps1
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

    it "installs py-ps module" {
        __RunInstaller
        
        Assert-MockCalled Install-Module -Times 1 -ParameterFilter { $Name -eq "py-ps" }
        Assert-MockCalled Update-Module -Times 1 -ParameterFilter { $Name -eq "py-ps" }
    }

    it "copies the module loader to default profile location" {
        Set-Content -Path TestDrive:\source\tools\ProfileLoader.ps1 "test"

        __RunInstaller

        $PROFILE | Should Exist
        Get-Content $PROFILE | Should Be "test"
    }

    it "overwrites existing profile" {
        Set-Content -Path TestDrive:\source\tools\ProfileLoader.ps1 "test"
        New-Item -Type File -Path $PROFILE -Value "former profile content" -Force

        __RunInstaller

        $PROFILE | Should Exist
        Get-Content $PROFILE | Should Be "test"
    }

    it "moves an existing profile file to the profile fragment path" {
        New-Item -Type File -Path $PROFILE -Value "test`nformer profile content" -Force

        __RunInstaller

        "TestDrive:\target\.config\powershell\default_profile.ps1" | Should Exist
        Get-Content TestDrive:\target\.config\powershell\default_profile.ps1 -Raw | Should Be "test`nformer profile content"
    }

    it "must not replace existing profile if it is a loader already" {
        # loader implementation embeds a magic comment to detect it with high probability
        New-Item -Type File -Path $PROFILE -Value "# RSUjN2ipQNJGgIkEZoJXkaaIRr0mTz86zW5fFXiA3ymGXLfbdu #" -Force

        __RunInstaller

        "TestDrive:\target\.config\powershell\default_profile.ps1" | Should Not Exist
        Get-Content $PROFILE | Should Be "# RSUjN2ipQNJGgIkEZoJXkaaIRr0mTz86zW5fFXiA3ymGXLfbdu #"
    }
}
