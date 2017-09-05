<#
.SYNOPSIS
    Project bootstrapping.
#>

#Requires -Version 5
Set-StrictMode -Version Latest

# config files embedded, to simplify packaging as a ps module
$Template_editorconfig = @"
# http://editorconfig.org

root = true

[*]
# force unix endings and utf-8 everywhere
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

indent_style = space
indent_size = 2

[Makefile]
# tabs are syntax elements in make
indent_style = tab

[*.py]
# PEP 8 mandates multiples of four as indentation
indent_size = 4

[*.md]
trim_trailing_whitespace = false
max_line_length = off

[*.{bat,ps1,psm1,psd1,ps1xml}]
end_of_line = crlf

"@

$Template_gitattributes = @"
# enable git auto handling
* text=auto

# force endings for some platform specific files
*.md      eol=lf
*.sh      eol=lf
*.xml     eol=lf
*.json    eol=lf
*.sql     eol=lf
*.yaml    eol=lf
*.yml     eol=lf

*.ps1     eol=crlf
*.psm1    eol=crlf
*.psd1    eol=crlf
*.ps1xml  eol=crlf
*.bat     eol=crlf

*.pdf     -text

"@

$Template_gitignore = @"
# intellij #
.idea/
*.iml
*.ipr
*.iws

# eclipse #
.settings/
.project
.classpath

# vagrant #
.vagrant

# osx #
.DS_Store

"@

function Initialize-Project {
    <#
    .SYNOPSIS
        Create a git-based project at target location.
    .DESCRIPTION
        Sets up the git repository and imports basic config files.
    #>
    [CmdletBinding()]
    Param([Parameter(Mandatory=$false)][string]$Path = $(Get-Location))

    If (-not $(Test-Path $Path)) {
        New-Item -ItemType Directory $Path
    }

    Push-Location -StackName __Initialize-Project__ $Path
    try {
        git init
        __DumpToUnixFile $Template_editorconfig $(Join-Path $Path '.editorconfig')
        __DumpToUnixFile $Template_gitattributes $(Join-Path $Path '.gitattributes')
        __DumpToUnixFile $Template_gitignore $(Join-Path $Path '.gitignore')
        git add .
    } finally {
        Pop-Location -StackName __Initialize-Project__
    }
}

function __DumpToUnixFile($content, [string] $target) {
    <#
    .SYNOPSIS
    write given string to target file using utf8 encoding without BOM and LF line endings.
     
    .PARAMETER content
    to be written to file
    
    .PARAMETER target
    name of target file
    #>
    $encoding = New-Object System.Text.UTF8Encoding($False)
    $content | ForEach-Object { $_.Replace("`r`n","`n") } | ForEach-Object {
        [System.IO.File]::WriteAllText($target, $_, $encoding)
    }
}
