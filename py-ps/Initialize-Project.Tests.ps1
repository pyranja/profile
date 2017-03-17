#Requires -Version 5
Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "Initialize-Project" {

    AfterEach {
        Remove-Item -Force -Recurse TestDrive:\project
    }

    It "creates target location if necessary" {
        Initialize-Project -Path TestDrive:\project

        Test-Path TestDrive:\project -PathType Container | Should Be $true
    }

    It "works in existing folder" {
        New-Item -ItemType Container TestDrive:\project

        { Initialize-Project -Path TestDrive:\project } | Should Not Throw
    }

    It "creates a git repository" {
        Initialize-Project -Path TestDrive:\project
        
        "TestDrive:\project\.git" | Should Exist
    }

    It "works if git repository is already existing" {
        New-Item -ItemType Container TestDrive:\project
        Push-Location TestDrive:\project
        git init
        Pop-Location

        { Initialize-Project -Path TestDrive:\project } | Should Not Throw
    }

    It "creates generic config files" {
        Initialize-Project -Path TestDrive:\project

        @(".gitattributes", ".gitignore", ".editorconfig") | ForEach-Object { "TestDrive:\project\$_" } | Should Exist
    }
}
