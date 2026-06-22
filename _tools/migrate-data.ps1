# Migracja pola "data" w artykulach: data-only -> data + godzina T00:00
# Dotyka tylko pierwszej linii "data:" (frontmatter). Pliki bez BOM, UTF-8.
$ErrorActionPreference = "Stop"
$base = Split-Path -Parent $PSScriptRoot
$dir  = Join-Path $base "artykuly"
$enc  = New-Object System.Text.UTF8Encoding($false)
$rx   = [regex]::new('(?m)^(data:[ \t]*)"?(\d{4}-\d{2}-\d{2})"?(?=[ \t]*\r?\n)')
$count = 0
Get-ChildItem -Path $dir -Filter '*.md' | ForEach-Object {
    $p = $_.FullName
    $text = [System.IO.File]::ReadAllText($p)
    $new = $rx.Replace($text, '${1}"${2}T00:00"', 1)
    if ($new -ne $text) {
        [System.IO.File]::WriteAllText($p, $new, $enc)
        $count++
    }
}
Write-Host "Zmieniono plikow: $count"
