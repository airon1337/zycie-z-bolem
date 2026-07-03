# Build English site from markdown articles in content/en/
$ErrorActionPreference = "Stop"
$base    = $PSScriptRoot
$srcDir  = Join-Path $base "content\en"
$siteDir = Join-Path $base "site-en"
$DOMENA  = "https://myneuralgia.com"
$siteName = "My Neuralgia"

Write-Host "Building English site..."
Write-Host "Source: $srcDir"
Write-Host "Output: $siteDir"

# Clean old article HTML files (NNN-*.html pattern)
Get-ChildItem -Path $siteDir -Filter '*.html' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{3}-' } | Remove-Item -Force

function Esc([string]$s) {
    if ($null -eq $s) { return "" }
    return ($s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;')
}

function Convert-Md([string]$md) {
    # Remove frontmatter
    $md = [regex]::Replace($md, '(?s)^\uFEFF?---.*?---\s*', '')
    $md = $md -replace "`r`n","`n" -replace "`r","`n"
    $lines = $md -split "`n"
    
    $sb = New-Object System.Text.StringBuilder
    $para = New-Object System.Collections.Generic.List[string]
    $ul = $false

    foreach ($lineRaw in $lines) {
        $t = $lineRaw.Trim()
        
        $isBullet = ($t -ne "") -and ($t -match '^[\*\-]\s+(.+)$')
        $isOrdered = ($t -ne "") -and ($t -match '^\d+[\.\)]\s+(.+)$')
        
        # Flush paragraph
        if ($t -eq "" -or $t -match '^#' -or $t -match '^>' -or $isBullet -or $isOrdered) {
            if ($para.Count -gt 0) {
                if ($ul) { [void]$sb.Append("</ul>`n"); $ul=$false }
                [void]$sb.Append("<p>").Append((Inline ($para -join ' '))).Append("</p>`n")
                $para.Clear()
            }
        }
        
        if ($t -eq "") { continue }
        
        # Skip H1 and date line
        if ($t -match '^#\s' -or $t -match '^\*Publication date') { continue }
        
        # Blockquote
        if ($t -match '^>\s?(.*)$') {
            if ($ul) { [void]$sb.Append("</ul>`n"); $ul=$false }
            [void]$sb.Append('<div class="disclaimer"><p>').Append((Inline $matches[1])).Append('</p></div>' + "`n")
            continue
        }
        
        # H2
        if ($t -match '^##\s+(.+)$') {
            if ($ul) { [void]$sb.Append("</ul>`n"); $ul=$false }
            [void]$sb.Append("<h2>").Append((Inline $matches[1])).Append("</h2>`n")
            continue
        }
        # H3
        if ($t -match '^###\s+(.+)$') {
            if ($ul) { [void]$sb.Append("</ul>`n"); $ul=$false }
            [void]$sb.Append("<h3>").Append((Inline $matches[1])).Append("</h3>`n")
            continue
        }
        
        # Bullet
        if ($isBullet) {
            $null = $t -match '^[\*\-]\s+(.+)$'
            if (-not $ul) { [void]$sb.Append("<ul>`n"); $ul=$true }
            [void]$sb.Append("<li>").Append((Inline $matches[1])).Append("</li>`n")
            continue
        }
        
        # Ordered
        if ($isOrdered) {
            $null = $t -match '^\d+[\.\)]\s+(.+)$'
            [void]$sb.Append("<p>").Append((Inline $matches[1])).Append("</p>`n")
            continue
        }
        
        # Normal text
        $para.Add($t)
    }
    
    # Flush remaining
    if ($para.Count -gt 0) {
        if ($ul) { [void]$sb.Append("</ul>`n"); $ul=$false }
        [void]$sb.Append("<p>").Append((Inline ($para -join ' '))).Append("</p>`n")
    }
    if ($ul) { [void]$sb.Append("</ul>`n") }
    
    return $sb.ToString()
}

function Inline([string]$s) {
    $s = Esc $s
    $s = [regex]::Replace($s, '\*\*(.+?)\*\*', '<strong>$1</strong>')
    $s = [regex]::Replace($s, '\[([^\]]+)\]\((https?://[^\)]+)\)', '<a href="$2" target="_blank" rel="noopener">$1</a>')
    return $s
}

function Get-Excerpt([string]$md) {
    $md = [regex]::Replace($md, '(?s)^\uFEFF?---.*?---\s*', '')
    $md = $md -replace "`r`n","`n" -replace "`r","`n"
    foreach ($lineRaw in ($md -split "`n")) {
        $t = $lineRaw.Trim()
        if ($t -eq "" -or $t -match '^#' -or $t -match '^\*Publication' -or $t -match '^>' -or $t -match '^https?://') { continue }
        $t = $t -replace '\*\*','' -replace '\[([^\]]+)\]\([^\)]+\)','$1'
        if ($t.Length -gt 155) { $t = $t.Substring(0,155).TrimEnd() + [char]0x2026 }
        return $t
    }
    return ""
}

# Article HTML template
$tplArticle = @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{TITLE}} — My Neuralgia</title>
<meta name="description" content="{{EXCERPT}}">
<link rel="canonical" href="{{CANONICAL}}">
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="stylesheet" href="/styl.css">
</head>
<body>
<header class="naglowek-strony">
  <nav class="nav">
    <a class="logo" href="/index.html">My Neuralgia<span class="kropka">.</span></a>
    <div class="menu">
      <a href="/start-here.html">Start Here</a>
      <a href="/pain-diary.html">Pain Diary</a>
      <a href="/about.html">About</a>
    </div>
  </nav>
</header>
<div class="artykul-naglowek">
  <div class="kontener waska">
    <div class="okruszki"><a href="/index.html">Home</a> &rsaquo; Article</div>
    <h1 style="color:var(--akcent-ciemny); margin:0;">{{TITLE}}</h1>
    <p class="artykul-meta">{{DATE}}</p>
  </div>
</div>
<article class="artykul-tresc">
  <div class="kontener waska">
{{CONTENT}}
  </div>
</article>
<footer class="stopka">
  <div class="kontener">
    <div class="kolumny">
      <div><h4>My Neuralgia</h4><p style="color:#a9c4bd; font-size:.92rem;">A blog about living with trigeminal neuralgia and neuropathy. You are not alone.</p></div>
      <div><h4>Navigation</h4><ul><li><a href="/start-here.html">Start Here</a></li><li><a href="/about.html">About</a></li><li><a href="/privacy-policy.html">Privacy Policy</a></li></ul></div>
      <div><h4>Important</h4><p style="color:#a9c4bd; font-size:.92rem;">Educational content only, not medical advice.</p></div>
    </div>
    <div class="dol">&copy; 2026 My Neuralgia &middot; <a href="/privacy-policy.html" style="color:#a9c4bd;">Privacy Policy</a></div>
  </div>
</footer>
{{JSONLD}}
</body>
</html>
'@

$items = @()

foreach ($f in (Get-ChildItem -Path $srcDir -Filter *.md | Where-Object { $_.Name -ne ".gitkeep" } | Sort-Object Name)) {
    $raw = Get-Content -Raw -Encoding UTF8 $f.FullName
    
    # Parse frontmatter
    $title = ""
    if ($raw -match '(?m)^title:\s*"(.*)"\s*$') { $title = $matches[1] -replace '\\"','"' }
    if ($title -eq "") { $title = ($f.BaseName -replace '^\d+-','') -replace '-',' ' }
    
    $date = ""
    if ($raw -match '(?m)^date:\s*"?([^"\r\n]+?)"?\s*$') { $date = $matches[1].Trim() }
    # Show only date part (remove time)
    if ($date -match '^(\d{4}-\d{2}-\d{2})') { $date = $matches[1] }
    
    $status = "draft"
    if ($raw -match '(?m)^status:\s*(\S+)') { $status = $matches[1].Trim() }
    
    # Skip drafts
    if ($status -eq "draft") { 
        Write-Host "  SKIP (draft): $($f.Name)"
        continue 
    }
    
    $slug = $f.BaseName
    $excerpt = Get-Excerpt $raw
    $bodyHtml = Convert-Md $raw
    
    $canonical = "$DOMENA/$slug.html"
    
    # Schema.org
    $schemaObj = [ordered]@{
        "@context" = "https://schema.org"
        "@type" = "BlogPosting"
        "headline" = $title
        "description" = $excerpt
        "datePublished" = $date
        "author" = [ordered]@{ "@type" = "Person"; "name" = "Natalia" }
        "publisher" = [ordered]@{ "@type" = "Organization"; "name" = $siteName }
        "inLanguage" = "en"
        "mainEntityOfPage" = $canonical
    }
    $jsonLd = '<script type="application/ld+json">' + ($schemaObj | ConvertTo-Json -Depth 4) + '</script>'
    
    # Build page
    $page = $tplArticle
    $page = $page.Replace("{{TITLE}}", (Esc $title))
    $page = $page.Replace("{{DATE}}", (Esc $date))
    $page = $page.Replace("{{EXCERPT}}", (Esc $excerpt))
    $page = $page.Replace("{{CANONICAL}}", $canonical)
    $page = $page.Replace("{{CONTENT}}", $bodyHtml)
    $page = $page.Replace("{{JSONLD}}", $jsonLd)
    
    $outFile = Join-Path $siteDir ($slug + ".html")
    $page | Out-File -Encoding UTF8 $outFile
    Write-Host "  OK: $slug.html"
    
    $items += [PSCustomObject]@{ slug = $slug; title = $title; date = $date; excerpt = $excerpt }
}

# Update index.html with article cards
$cardsHtml = ""
$itemsSorted = $items | Sort-Object { [datetime]::Parse($_.date) } -Descending -ErrorAction SilentlyContinue
if ($null -eq $itemsSorted) { $itemsSorted = $items }

foreach ($it in $itemsSorted) {
    $cardsHtml += '<a class="karta-blog" href="/' + $it.slug + '.html"><div class="karta-body"><h3 class="karta-tytul">' + (Esc $it.title) + '</h3><p class="karta-zaj">' + (Esc $it.excerpt) + '</p></div></a>' + "`n"
}

if ($cardsHtml -eq "") {
    $cardsHtml = '<p style="text-align:center; color: var(--tekst-jasny); grid-column: 1/-1;">Articles coming soon.</p>'
}

# Read index.html and replace articles section
$indexPath = Join-Path $siteDir "index.html"
$indexHtml = Get-Content -Raw -Encoding UTF8 $indexPath
$indexHtml = [regex]::Replace($indexHtml, '(?s)<div class="kafelki">.*?</div>(\s*</div>\s*</section>)', '<div class="kafelki">' + "`n" + $cardsHtml + '    </div>$1')
$indexHtml | Out-File -Encoding UTF8 $indexPath

Write-Host ""
Write-Host "Done! Built $($items.Count) articles."
Write-Host "Deploy with: wrangler pages deploy site-en --project-name=myneuralgia-en"
