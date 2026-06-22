# Zwraca "true", jesli ktorys artykul wlasnie wszedl w termin publikacji
# (data publikacji w oknie ostatnich 3 godzin, czas polski). Inaczej "false".
$ErrorActionPreference = "Stop"
$base = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $base "artykuly"
$tzPL = $null
foreach ($tzId in @('Europe/Warsaw','Central European Standard Time')) { try { $tzPL = [System.TimeZoneInfo]::FindSystemTimeZoneById($tzId); break } catch {} }
if (-not $tzPL) { $tzPL = [System.TimeZoneInfo]::Utc }
$nowPL = [System.TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $tzPL)
$from = $nowPL.AddMinutes(-180)
$due = $false
foreach ($f in (Get-ChildItem $dir -Filter *.md -ErrorAction SilentlyContinue)) {
    $raw = Get-Content -Raw -Encoding UTF8 $f.FullName
    $date = ""
    if ($raw -match '(?m)^data:\s*"?([^"\r\n]+?)"?\s*$') { $date = $matches[1].Trim() }
    $dt = [datetime]::MinValue
    if ([datetime]::TryParse($date, [ref]$dt)) {
        if ($dt -le $nowPL -and $dt -gt $from) { $due = $true; break }
    }
}
if ($due) { "true" } else { "false" }
