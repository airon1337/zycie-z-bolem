# Cloudflare Pages serves HTML at extensionless URLs. Keep all SEO signals consistent.
param([Parameter(Mandatory=$true)][string]$SiteDir)
$ErrorActionPreference = 'Stop'
$encoding = [System.Text.UTF8Encoding]::new($false)
$origin = 'https://zyciezbolem.pl'
$redirects = @{}
foreach ($line in (Get-Content (Join-Path $SiteDir '_redirects'))) {
    if ($line -match '^(/\S+)\s+(/\S+)\s+301\s*$') { $redirects[$matches[1]] = $matches[2] }
}
# Remove obsolete HTML aliases only when their declared redirect has a real target.
foreach ($source in $redirects.Keys) {
    $target = $redirects[$source]
    $targetFile = if ($target -eq '/') { 'index.html' } else { $target.TrimStart('/') + '.html' }
    if (-not (Test-Path (Join-Path $SiteDir $targetFile))) { continue }
    $alias = $source.TrimStart('/')
    if (-not $alias.EndsWith('.html')) { $alias += '.html' }
    $aliasPath = Join-Path $SiteDir $alias
    if ($alias -ne $targetFile -and (Test-Path $aliasPath)) { Remove-Item $aliasPath }
}
foreach ($file in (Get-ChildItem $SiteDir -Filter '*.html' -File)) {
    $html = [System.IO.File]::ReadAllText($file.FullName)
    # Limit changes to local HTML links and this site's absolute URLs.
    $html = [regex]::Replace($html, '(?<prefix>(?:href|content)=["''])(?<url>(?:https://zyciezbolem\.pl)?/(?!/)[^"''<>\s?#]*)\.html(?<suffix>[?#][^"'']*)?(?<quote>["''])', {
        param($m)
        $url = $m.Groups['url'].Value
        if ($url -eq '/index') { $url = '/' }
        if ($url -eq ($origin + '/index')) { $url = $origin + '/' }
        $m.Groups['prefix'].Value + $url + $m.Groups['suffix'].Value + $m.Groups['quote'].Value
    })
    [System.IO.File]::WriteAllText($file.FullName, $html, $encoding)
}
# A sitemap must advertise final canonical destinations, never redirect sources.
[xml]$sitemap = Get-Content -Raw (Join-Path $SiteDir 'sitemap.xml')
$seen = @{}
foreach ($entry in @($sitemap.urlset.url)) {
    $url = [string]$entry.loc
    if (-not $url.StartsWith($origin + '/')) { continue }
    $path = $url.Substring($origin.Length) -replace '\.html$', ''
    if ($path -eq '/index') { $path = '/' }
    if ($redirects.ContainsKey($path)) { $path = $redirects[$path] }
    $url = $origin + $path
    if ($seen.ContainsKey($url)) { [void]$entry.ParentNode.RemoveChild($entry); continue }
    $seen[$url] = $true
    $entry.loc = $url
}
$writer = [System.Xml.XmlWriter]::Create((Join-Path $SiteDir 'sitemap.xml'), [System.Xml.XmlWriterSettings]@{ Encoding=$encoding; Indent=$true })
try { $sitemap.Save($writer) } finally { $writer.Dispose() }
