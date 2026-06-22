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
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $pub "*") -DestinationPath $zip

Write-Output ("Folder do wgrania: " + $pub)
Write-Output ("Plik ZIP: " + $zip)
Write-Output ("Plikow w paczce: " + (Get-ChildItem $pub -Recurse -File).Count)
