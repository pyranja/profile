$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "Get-LatestVersion" {

    It "fetches release meta data from github" {
        Mock Invoke-RestMethod {}
        Get-LatestVersion
        Assert-MockCalled Invoke-RestMethod -ParameterFilter { $Uri -eq 'https://api.github.com/repos/pyranja/profile/releases/latest' } -Scope It
    }

    It "parses the version from the release name" {
        Mock Invoke-RestMethod { return @{name='py-profile-0.1.42'} }
        Get-LatestVersion | Should Be 0.1.42
    }

    It "fails if release name in an unexpected format" {
        Mock Invoke-RestMethod { return @{name='unexpected'} }
        { Get-LatestVersion -ErrorAction Stop } | Should Throw
    }
}