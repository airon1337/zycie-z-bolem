$ErrorActionPreference = "Stop"
$src = "file:///d:/kiro/site/dziennik-bolu-druk.html"
$out = "d:\kiro\site\dziennik-bolu.pdf"
if (Test-Path $out) { Remove-Item $out -Force }

$cands = @(
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
  "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
  "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe"
)
$edge = $null
foreach ($c in $cands) { if (Test-Path $c) { $edge = $c; break } }
if (-not $edge) { Write-Output "NIE ZNALEZIONO przegladarki"; exit 1 }
Write-Output ("Przegladarka: " + $edge)

& $edge --headless=new --disable-gpu --no-pdf-header-footer --print-to-pdf="$out" $src 2>$null
Start-Sleep -Seconds 3
if (Test-Path $out) {
  Write-Output ("OK: " + $out + "  rozmiar(KB): " + [math]::Round((Get-Item $out).Length/1KB,1))
} else {
  # druga proba bez --headless=new
  & $edge --headless --disable-gpu --print-to-pdf="$out" $src 2>$null
  Start-Sleep -Seconds 3
  if (Test-Path $out) { Write-Output ("OK(2): " + $out) } else { Write-Output "NIE UDALO SIE wygenerowac PDF" }
}
