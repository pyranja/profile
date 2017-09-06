Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

function __RunInstaller {
    . "$here\$sut" -SourceBase TestDrive:\source -TargetBase TestDrive:\target @args -Confirm:$False
}

Describe "Install-PyProfile" {
    # global mocks for dangerous powershellget commands
    Mock -CommandName Install-Module -MockWith { return $true }
    Mock -CommandName Update-Module -MockWith { return $true }
    Mock -CommandName Uninstall-Module -MockWith { return $true }
    Mock -CommandName Get-InstalledModule -MockWith { return [PSCustomObject]@{Version = 99; Name = "fake"} }

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

    it "creates .gitconfig in target dir if it is not present" {
        __RunInstaller

        "TestDrive:\target\.gitconfig" | Should Exist
    }

    it "installs py-ps module" {
        __RunInstaller
        
        # calls install, then update to avoid explicit checking whether py-ps is installed
        Assert-MockCalled Install-Module -Times 1 -ParameterFilter { $Name -eq "py-ps" }
        Assert-MockCalled Update-Module -Times 1 -ParameterFilter { $Name -eq "py-ps" }
    }

    it "removes older py-ps versions" {
        # must create mock objects in closure to avoid ref errors in following tests
        Mock -CommandName Get-InstalledModule `
            -ParameterFilter { $Name -eq "py-ps" -and -not $AllVersions } `
            -MockWith { return [PSCustomObject]@{Version=2; Name="py-ps"} }
        Mock -CommandName Get-InstalledModule `
            -ParameterFilter { $Name -eq "py-ps" -and $AllVersions } `
            -MockWith { return @([PSCustomObject]@{Version=1; Name="py-ps"}, [PSCustomObject]@{Version=2; Name="py-ps"}) }

        __RunInstaller

        Assert-MockCalled Uninstall-Module -Times 1 `
            -ParameterFilter { $InputObject.Name -eq "py-ps" -and $InputObject.Version -eq "1" }
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
