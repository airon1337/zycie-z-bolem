# Przygotowanie paczki do wgrania na Cloudflare Pages
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$base = Split-Path -Parent $PSScriptRoot
$src = Join-Path $base "site"
$pub = Join-Path $base "publish"
$zip = Join-Path $base "zycie-z-bolem.zip"

if (Test-Path $pub) { Remove-Item $pub -Recurse -Force }
Copy-Item $src $pub -Recurse
$tpl = Join-Path $pub "_szablony"
if (Test-Path $tpl) { Remove-Item $tpl -Recurse -Force }

# Cache-busting: dolacz wersje (hash zawartosci styl.css) do KAZDEGO linku /styl.css we wszystkich stronach.
# Dzieki temu po zmianie CSS adres sie zmienia i przegladarka pobiera swiezy plik (koniec z Ctrl+F5).
$cssFile = Join-Path $pub "styl.css"
if (Test-Path $cssFile) {
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $hashBytes = $md5.ComputeHash([System.IO.File]::ReadAllBytes($cssFile))
    $cssVer = (([System.BitConverter]::ToString($hashBytes)) -replace '-','').Substring(0,8).ToLower()
    $enc = New-Object System.Text.UTF8Encoding($false)
    $rx = [regex]::new('/styl\.css(?!\?v=)')
    Get-ChildItem -Path $pub -Filter '*.html' -Recurse | ForEach-Object {
        $html = [System.IO.File]::ReadAllText($_.FullName)
        $new = $rx.Replace($html, "/styl.css?v=$cssVer")
        if ($new -ne $html) { [System.IO.File]::WriteAllText($_.FullName, $new, $enc) }
    }
    Write-Output ("Wersja CSS (cache-busting): " + $cssVer)
}

if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $pub "*") -DestinationPath $zip

Write-Output ("Folder do wgrania: " + $pub)
Write-Output ("Plik ZIP: " + $zip)
Write-Output ("Plikow w paczce: " + (Get-ChildItem $pub -Recurse -File).Count)
