#Requires -Version 5
Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "Get-LatestVersion" {

    It "fetches release meta data from github" {
        Mock Invoke-RestMethod { @{name='py-profile-0.1.42'} }
        Get-LatestVersion
        Assert-MockCalled Invoke-RestMethod -ParameterFilter { $Uri -eq 'https://api.github.com/repos/pyranja/profile/releases/latest' } -Scope It
    }

    It "parses the version from the release name" {
        Mock Invoke-RestMethod { @{name='py-profile-0.1.42'} }
        Get-LatestVersion | Should Be 0.1.42
    }

    It "fails if release name in an unexpected format" {
        Mock Invoke-RestMethod { @{name='unexpected'} }
        { Get-LatestVersion -ErrorAction Stop } | Should Throw
    }
}

Describe "Update-Profile" {

    BeforeEach {
        Mock Get-LatestVersion { [Version]'9.9.9' }
    }

    Context "up to date" {
        It "does nothing" {
            Mock __version { [Version]'9.9.9' }
            Mock __fetchRelease { }
            Update-Profile -Confirm:$false
            Assert-MockCalled __fetchRelease -Exactly 0
        }
    }

    Context "outdated" {
        BeforeEach {
            Mock __version { [Version]'1.0.0' }
            Mock __fetchRelease { }
            New-Item -ItemType Directory -Path TestDrive:\release\py-profile
            # fake installer script
            "New-Item -Type File -Path TestDrive:\release\installer_called" | Out-File -FilePath TestDrive:\release\py-profile\Install-PyProfile.ps1
        }

        AfterEach {
            Remove-Item TestDrive:\release -Force -Recurse -ErrorAction SilentlyContinue
        }

        It "downloads the release" {
            Update-Profile -Confirm:$false -Cwd TestDrive:\release
            Assert-MockCalled __fetchRelease -Scope It
        }

        It "invokes the installer" {
            Update-Profile -Confirm:$false -Cwd TestDrive:\release
            "TestDrive:\release\installer_called" | Should Exist
        }
    }
}

Describe "__fetchRelease" {
    It "downloads and extracts release zip to target folder" {
        __fetchRelease -Path TestDrive:\release\
        "TestDrive:\release\py-profile-*.zip" | Should Exist
        "TestDrive:\release\py-profile\Install-PyProfile.ps1" | Should Exist
    }
}