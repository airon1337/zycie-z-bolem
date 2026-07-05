# Budowanie statycznej strony "Zycie z bolem" z artykulow markdown
$ErrorActionPreference = "Stop"
$base    = Split-Path -Parent $PSScriptRoot
$srcDir  = Join-Path $base "artykuly"

# --- Auto-numerowanie: pliki bez numeru NNN- na poczatku dostaną kolejny numer ---
$existingNumbers = @(Get-ChildItem -Path $srcDir -Filter "*.md" | Where-Object { $_.Name -match '^\d{3}-' } | ForEach-Object { [int]($_.Name.Substring(0,3)) })
$nextNum = if ($existingNumbers.Count -gt 0) { ($existingNumbers | Measure-Object -Maximum).Maximum + 1 } else { 1 }
$unnumbered = @(Get-ChildItem -Path $srcDir -Filter "*.md" | Where-Object { $_.Name -notmatch '^\d{3}-' -and $_.Name -ne 'index.md' -and $_.Name -ne 'nie walczylam z bolem.md' -and $_.Name -ne 'start strony.md' } | Sort-Object Name)
foreach ($uf in $unnumbered) {
    $newName = "{0:D3}-{1}" -f $nextNum, $uf.Name
    Rename-Item $uf.FullName $newName
    Write-Host "  AUTO-NUM: $($uf.Name) -> $newName"
    $nextNum++
}

$siteDir = Join-Path $base "site"
$outArt  = $siteDir
$tpls    = Join-Path $siteDir "_szablony"
# czyszczenie starej struktury z podfolderem oraz starych plikow artykulow (NNN-...) w katalogu glownym
$oldDir = Join-Path $siteDir "artykuly"
if (Test-Path $oldDir) { Remove-Item $oldDir -Recurse -Force }
Get-ChildItem -Path $siteDir -Filter '*.html' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{3}-' } | Remove-Item -Force
Get-ChildItem -Path $siteDir -Filter 'tag-*.html' -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -Path $siteDir -Filter 'kategoria-*.html' -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -Path $siteDir -Filter 'artykuly-*.html' -ErrorAction SilentlyContinue | Remove-Item -Force
# czyszczenie starych zdjec (podfolder img oraz pliki NNN-...jpg w katalogu glownym)
$oldImg = Join-Path $siteDir "img"
if (Test-Path $oldImg) { Remove-Item $oldImg -Recurse -Force }
Get-ChildItem -Path $siteDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{3}-.*\.(jpg|jpeg|png|webp|svg)$' } | Remove-Item -Force
# kopiuj folder zdjec do site\zdjecia (serwowane pod /zdjecia/)
$srcZdj = Join-Path $base "zdjecia"
$dstZdj = Join-Path $siteDir "zdjecia"
if (Test-Path $dstZdj) { Remove-Item $dstZdj -Recurse -Force }
if (Test-Path $srcZdj) { Copy-Item $srcZdj $dstZdj -Recurse -Force }
$DOMENA = "https://zyciezbolem.pl"
$siteName = "Z" + [char]0x017C + "ycie z b" + [char]0x00F3 + "lem"

$tplArticle = Get-Content -Raw -Encoding UTF8 (Join-Path $tpls "artykul-szablon.html")
$tplIndex   = Get-Content -Raw -Encoding UTF8 (Join-Path $tpls "index-szablon.html")
$tplCard    = Get-Content -Raw -Encoding UTF8 (Join-Path $tpls "karta-szablon.html")
$tplTag     = Get-Content -Raw -Encoding UTF8 (Join-Path $tpls "tag-szablon.html")
$tplLista   = Get-Content -Raw -Encoding UTF8 (Join-Path $tpls "lista-szablon.html")
$tplKat     = Get-Content -Raw -Encoding UTF8 (Join-Path $tpls "kategoria-szablon.html")
$faq        = (Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot "faq.json")) | ConvertFrom-Json
$titles     = (Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot "titles.json")) | ConvertFrom-Json

$bullet = [char]0x2022
$zrHead = [char]0x179 + "r" + [char]0x00F3 + "d" + [char]0x142 + "a"  # "Zrodla" z polskimi znakami
# markery naglowka sekcji zrodel (linia bedaca samym wyrazem) - porownanie -contains jest case-insensitive
$srcMarkers = @(
    'Bibliografia',
    'Bibliography',
    'Zrodla',
    'Zrodlo',
    ([char]0x179 + 'r' + [char]0x00F3 + 'd' + [char]0x142 + 'a'),  # Zrodla z pl znakami
    ([char]0x179 + 'r' + [char]0x00F3 + 'd' + [char]0x142 + 'o')   # Zrodlo z pl znakami
)

# czas "teraz" w strefie polskiej (do publikacji zaplanowanej)
$tzPL = $null
foreach ($tzId in @('Europe/Warsaw','Central European Standard Time')) { try { $tzPL = [System.TimeZoneInfo]::FindSystemTimeZoneById($tzId); break } catch {} }
if (-not $tzPL) { $tzPL = [System.TimeZoneInfo]::Utc }
$nowPL = [System.TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $tzPL)

# --- mapa zdjec artykulow (artykul NNN -> plik w folderze zdjecia\) ---
$imgMap = @{}
$imgDir = Join-Path $base "zdjecia"
if (Test-Path $imgDir) {
    foreach ($im in (Get-ChildItem -Path $imgDir -File)) {
        if ($im.Name -match '^(\d{3})\.(jpg|jpeg|png|webp)$') { $imgMap[$matches[1]] = $im.FullName }
    }
}

function Esc([string]$s) {
    if ($null -eq $s) { return "" }
    return ($s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;')
}

function NFKC([string]$s) {
    if ([string]::IsNullOrEmpty($s)) { return $s }
    return $s.Normalize([System.Text.NormalizationForm]::FormKC)
}

function Contains-Q($list, $qtext) {
    foreach ($x in $list) { if ($x.q -eq $qtext) { return $true } }
    return $false
}

function Is-InsideTagOrAnchor([string]$html, [int]$idx) {
    $pre = $html.Substring(0, $idx)
    if ($pre.LastIndexOf('<') -gt $pre.LastIndexOf('>')) { return $true }   # w srodku znacznika
    $opens = ([regex]::Matches($pre, '<a\b')).Count
    $closes = ([regex]::Matches($pre, '</a>')).Count
    if ($opens -gt $closes) { return $true }                                # w srodku linku
    return $false
}

function Auto-Link([string]$html, [string]$curSlug) {
    if ($null -eq $script:faq.links) { return $html }
    foreach ($lnk in $script:faq.links) {
        if ($lnk.slug -eq $curSlug) { continue }   # nie linkuj artykulu do samego siebie
        $rx = [regex]::new("(?i)(?<![\p{L}])(" + $lnk.pattern + ")(?![\p{L}])")
        $m = $rx.Match($html)
        $linked = 0
        while ($m.Success -and $linked -lt 2) {
            if (-not (Is-InsideTagOrAnchor $html $m.Index)) {
                $rep = '<a class="link-wew" href="/' + $lnk.slug + '.html">' + $m.Value + '</a>'
                $html = $html.Substring(0, $m.Index) + $rep + $html.Substring($m.Index + $m.Length)
                $linked++
                $m = $rx.Match($html, $m.Index + $rep.Length)
            } else {
                $m = $m.NextMatch()
            }
        }
    }
    return $html
}

function Tag-Slug([string]$s) {
    $s = $s.ToLower()
    $s = $s -replace '\u0105','a' -replace '\u0107','c' -replace '\u0119','e' -replace '\u0142','l' -replace '\u0144','n' -replace '\u00f3','o' -replace '\u015b','s' -replace '\u017a','z' -replace '\u017c','z'
    $s = $s -replace '[^a-z0-9]+','-' -replace '(^-+|-+$)',''
    return $s
}

function Get-Tags([string]$textRaw) {
    $textLower = $textRaw.ToLower()
    $tags = New-Object System.Collections.Generic.List[string]
    foreach ($k in $script:faq.keywords) {
        if ([regex]::IsMatch($textLower, $k.pattern)) { [void]$tags.Add($k.label) }
    }
    if ($tags.Count -gt 8) { $tags = $tags[0..7] }
    return $tags
}

function Get-Category([string]$textRaw) {
    $textLower = $textRaw.ToLower()
    $best = $null; $bestScore = 0
    foreach ($c in $script:faq.kategorie) {
        $cnt = ([regex]::Matches($textLower, $c.pattern)).Count
        if ($cnt -gt $bestScore) { $bestScore = $cnt; $best = $c }
    }
    if ($null -eq $best) {
        $best = $script:faq.kategorie | Where-Object { $_.slug -eq 'zycie-z-bolem' } | Select-Object -First 1
        if ($null -eq $best -and $script:faq.kategorie.Count -gt 0) { $best = $script:faq.kategorie[-1] }
    }
    return $best
}

function Build-Kafelek($it) {
    $tt = Esc $it.title
    $ex = Esc $it.excerpt
    if ($it.img -ne "") {
        $foto = '<div class="karta-foto-wrap"><img class="karta-foto" src="' + $it.img + '" alt="' + $tt + '" loading="lazy"></div>'
    } else {
        $foto = '<div class="karta-foto-wrap"><img class="karta-foto" src="/placeholder.svg" alt="' + $tt + '" loading="lazy"></div>'
    }
    return '<a class="karta-blog" href="/' + $it.slug + '.html">' + $foto + '<div class="karta-body"><h3 class="karta-tytul">' + $tt + '</h3><p class="karta-zaj">' + $ex + '</p></div></a>'
}

function Make-Cover([string]$title, [string]$raw, [string]$outPath) {
    $tl = $raw.ToLower()
    $accent = "#3a7a6f"; $fillIcon = $true; $icon = ""
    if ($tl -match 'wielkanoc|nowy rok|rocznic|walentyn|zakochan|narodzenie') {
        $accent = "#c9805a"; $fillIcon = $true
        $icon = '<path d="M12 2 l2.9 6.6 7.1 .6 -5.4 4.7 1.7 7 -6.3 -3.8 -6.3 3.8 1.7 -7 -5.4 -4.7 7.1 -.6 z"/>'
    } elseif ($tl -match 'gabapent|pregabal|karbamazep|tabletk|dawk|suplement|witamin|magnez|liponow|naltrekson|\bldn\b') {
        $accent = "#c9805a"; $fillIcon = $false
        $icon = '<g transform="rotate(45 12 12)"><path d="M4 12 a4 4 0 0 1 4 -4 h8 a4 4 0 0 1 0 8 h-8 a4 4 0 0 1 -4 -4 z"/><path d="M12 8 v8"/></g>'
    } elseif ($tl -match 'diagnos|rezonans|badani|lekarz|neurolog|wizyt') {
        $accent = "#3a7a6f"; $fillIcon = $false
        $icon = '<circle cx="10" cy="10" r="6"/><path d="M14.5 14.5 L20 20"/>'
    } elseif ($tl -match 'oddech|relaks|medytac|uwa|spok|m.zg|neuroplast|pami') {
        $accent = "#2c5d55"; $fillIcon = $false
        $icon = '<path d="M2 8 q4 -4 8 0 t8 0"/><path d="M2 13 q4 -4 8 0 t8 0"/><path d="M2 18 q4 -4 8 0 t8 0"/>'
    } elseif ($tl -match 'akcept|samotn|emocj|nadziej|mi.o|relacj|wspar|blisc|serce') {
        $accent = "#c9805a"; $fillIcon = $true
        $icon = '<path d="M12 21 C12 21 4 14 4 8.5 C4 5.5 6.2 4 8.5 4 C10.3 4 11.5 5.2 12 6.2 C12.5 5.2 13.7 4 15.5 4 C17.8 4 20 5.5 20 8.5 C20 14 12 21 12 21 Z"/>'
    } else {
        $accent = "#3a7a6f"; $fillIcon = $true
        $icon = '<path d="M13 2 L5 13 h5 l-1 9 9 -12 h-5 z"/>'
    }
    if ($fillIcon) { $g = '<g transform="translate(552,152) scale(4)" fill="#fff">' + $icon + '</g>' }
    else { $g = '<g transform="translate(552,152) scale(4)" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">' + $icon + '</g>' }

    $words = ($title -split '\s+') | Where-Object { $_ -ne '' }
    $lines = New-Object System.Collections.Generic.List[string]
    $cur = ""
    foreach ($w in $words) {
        $try = if ($cur -eq "") { $w } else { $cur + " " + $w }
        if ($try.Length -le 22) { $cur = $try } else { if ($cur -ne "") { [void]$lines.Add($cur) }; $cur = $w }
    }
    if ($cur -ne "") { [void]$lines.Add($cur) }
    while ($lines.Count -gt 3) { $lines.RemoveAt($lines.Count - 1) }
    $n = $lines.Count
    $firstY = 452 - ($n - 1) * 33
    $texts = ""
    for ($i = 0; $i -lt $n; $i++) {
        $y = $firstY + $i * 66
        $texts += '<text x="600" y="' + $y + '" text-anchor="middle" font-family="Segoe UI, Arial, sans-serif" font-size="54" font-weight="700" fill="#2c5d55">' + (Esc $lines[$i]) + '</text>'
    }

    $svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 750" role="img" aria-label="' + (Esc $title) + '">'
    $svg += '<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#e7f1ee"/><stop offset="1" stop-color="#ffffff"/></linearGradient></defs>'
    $svg += '<rect width="1200" height="750" fill="url(#g)"/>'
    $svg += '<circle cx="1010" cy="140" r="220" fill="#3a7a6f" opacity="0.06"/><circle cx="180" cy="640" r="180" fill="#3a7a6f" opacity="0.06"/>'
    $svg += '<circle cx="600" cy="200" r="70" fill="' + $accent + '"/>'
    $svg += $g + $texts + '</svg>'
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($outPath, $svg, $enc)
}

function Build-Pag([int]$cur, [int]$pages) {
    if ($pages -le 1) { return "" }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('<nav class="paginacja">')
    if ($cur -gt 1) {
        $h = if (($cur - 1) -eq 1) { "/index.html#artykuly" } else { "/artykuly-" + ($cur - 1) + ".html" }
        [void]$sb.Append('<a href="' + $h + '">' + $script:faq.uiPrev + '</a>')
    }
    for ($i = 1; $i -le $pages; $i++) {
        $h = if ($i -eq 1) { "/index.html#artykuly" } else { "/artykuly-" + $i + ".html" }
        if ($i -eq $cur) { [void]$sb.Append('<span class="akt">' + $i + '</span>') }
        else { [void]$sb.Append('<a href="' + $h + '">' + $i + '</a>') }
    }
    if ($cur -lt $pages) {
        [void]$sb.Append('<a href="/artykuly-' + ($cur + 1) + '.html">' + $script:faq.uiNext + '</a>')
    }
    [void]$sb.Append('</nav>')
    return $sb.ToString()
}

function Build-Extras([string]$textRaw) {
    $textLower = $textRaw.ToLower()
    # dobor FAQ
    $sel = New-Object System.Collections.Generic.List[object]
    foreach ($q in $script:faq.faqs) {
        $hit = $false
        foreach ($t in $q.triggers) { if ($textLower.Contains([string]$t)) { $hit = $true; break } }
        if ($hit) { [void]$sel.Add($q); if ($sel.Count -ge 5) { break } }
    }
    if ($sel.Count -lt 2) { $u = $script:faq.faqs[0];  if (-not (Contains-Q $sel $u.q)) { [void]$sel.Add($u) } }
    if ($sel.Count -lt 2) { $u = $script:faq.faqs[11]; if (-not (Contains-Q $sel $u.q)) { [void]$sel.Add($u) } }

    $faqHtml = ""
    $faqLd = ""
    if ($sel.Count -gt 0) {
        $sb3 = New-Object System.Text.StringBuilder
        [void]$sb3.Append('<section class="faq"><h2>').Append((Esc $script:faq.faqHeading)).Append('</h2>')
        foreach ($q in $sel) { [void]$sb3.Append('<div class="faq-item"><h3>').Append((Esc $q.q)).Append('</h3><p>').Append((Esc $q.a)).Append('</p></div>') }
        [void]$sb3.Append('</section>')
        $faqHtml = $sb3.ToString()

        $main = @()
        foreach ($q in $sel) { $main += [ordered]@{ "@type"="Question"; "name"=$q.q; "acceptedAnswer"=[ordered]@{ "@type"="Answer"; "text"=$q.a } } }
        $obj = [ordered]@{ "@context"="https://schema.org"; "@type"="FAQPage"; "mainEntity"=$main }
        $faqLd = '<script type="application/ld+json">' + ($obj | ConvertTo-Json -Depth 6) + '</script>'
    }
    return @{ faq = $faqHtml; ld = $faqLd }
}

function Inline([string]$s) {
    $s = Esc $s
    $s = [regex]::Replace($s, '\*\*(.+?)\*\*', '<strong>$1</strong>')
    $s = [regex]::Replace($s, '\[([^\]]+)\]\((https?://[^\)]+)\)', '<a href="$2" target="_blank" rel="noopener">$1</a>')
    $s = [regex]::Replace($s, '(?<![">])\b(https?://[^\s<)]+)', '<a href="$1" target="_blank" rel="noopener">$1</a>')
    return $s
}

function Convert-Md([string]$md) {
    # usun frontmatter
    $md = [regex]::Replace($md, '(?s)^\uFEFF?---.*?---\s*', '')
    $md = $md -replace "`r`n","`n" -replace "`r","`n"
    $lines = $md -split "`n"

    $sb = New-Object System.Text.StringBuilder
    $para = New-Object System.Collections.Generic.List[string]
    $ol = $false; $olLi = $false; $ul = $false
    $srcShown = $false
    $inSources = $false

    $bulletPat = '^(\*|\-|' + [regex]::Escape([string]$bullet) + ')\s+(.+)$'

    foreach ($lineRaw in $lines) {
        $t = $lineRaw.Trim()

        # czy biezacy wiersz konczy listy/akapit?
        $isBullet  = ($t -ne "") -and ($t -match $bulletPat)
        $isOrdered = ($t -ne "") -and ($t -match '^(\d+)[\.\)]\s+(.+)$')

        # flush akapitu gdy pusty wiersz lub element niebedacy tekstem
        if ($t -eq "" -or $t -match '^#' -or $t -match '^>' -or $isBullet -or $isOrdered -or $t -match '^https?://\S+$') {
            if ($para.Count -gt 0) {
                if ($ul) { [void]$sb.Append("</ul>`n"); $ul=$false }
                if ($olLi) { [void]$sb.Append("</li>`n"); $olLi=$false }
                if ($ol) { [void]$sb.Append("</ol>`n"); $ol=$false }
                [void]$sb.Append("<p>").Append((Inline ($para -join ' '))).Append("</p>`n")
                $para.Clear()
            }
        }

        if ($t -eq "") {
            continue
        }
        # wykrycie naglowka sekcji zrodel: linia bedaca samym wyrazem Bibliografia/Zrodla/Zrodlo (+ opcjonalny :)
        $tClean = ($t -replace '\s*:\s*$', '').Trim()
        if (-not $inSources -and ($srcMarkers -contains $tClean)) {
            if ($ul) { [void]$sb.Append("</ul>`n"); $ul=$false }
            if ($olLi) { [void]$sb.Append("</li>`n"); $olLi=$false }
            if ($ol) { [void]$sb.Append("</ol>`n"); $ol=$false }
            [void]$sb.Append('<p class="zrodla-naglowek">').Append((Esc $tClean)).Append(":</p>`n")
            $inSources = $true; $srcShown = $true
            continue
        }
        # w trybie zrodel kazda niepusta linia to pozycja bibliografii
        if ($inSources) {
            [void]$sb.Append('<p class="zrodlo-link">').Append((Inline $t)).Append("</p>`n")
            continue
        }
        if ($t -match '^#\s' -or $t -match '^\*Data publikacji') { continue }
        if ($t -match '^>\s?') {
            if ($ul) { [void]$sb.Append("</ul>`n"); $ul=$false }
            if ($olLi) { [void]$sb.Append("</li>`n"); $olLi=$false }
            if ($ol) { [void]$sb.Append("</ol>`n"); $ol=$false }
            continue
        }
        if ($t -match '^(#{3})\s+(.+)$') {
            if ($ul) { [void]$sb.Append("</ul>`n"); $ul=$false }
            if ($olLi) { [void]$sb.Append("</li>`n"); $olLi=$false }
            if ($ol) { [void]$sb.Append("</ol>`n"); $ol=$false }
            [void]$sb.Append("<h3>").Append((Inline $matches[2])).Append("</h3>`n"); continue
        }
        if ($t -match '^(#{2})\s+(.+)$') {
            if ($ul) { [void]$sb.Append("</ul>`n"); $ul=$false }
            if ($olLi) { [void]$sb.Append("</li>`n"); $olLi=$false }
            if ($ol) { [void]$sb.Append("</ol>`n"); $ol=$false }
            [void]$sb.Append("<h2>").Append((Inline $matches[2])).Append("</h2>`n"); continue
        }
        if ($isBullet) {
            $null = $t -match $bulletPat
            $txt = $matches[2]
            if ($ol) {
                if (-not $ul) { [void]$sb.Append("<ul>`n"); $ul=$true }
                [void]$sb.Append("<li>").Append((Inline $txt)).Append("</li>`n")
            } else {
                if (-not $ul) { [void]$sb.Append("<ul>`n"); $ul=$true }
                [void]$sb.Append("<li>").Append((Inline $txt)).Append("</li>`n")
            }
            continue
        }
        if ($isOrdered) {
            $null = $t -match '^(\d+)[\.\)]\s+(.+)$'
            $txt = $matches[2]
            if ($ul) { [void]$sb.Append("</ul>`n"); $ul=$false }   # zamknij podliste
            if ($olLi) { [void]$sb.Append("</li>`n"); $olLi=$false }
            if (-not $ol) { [void]$sb.Append("<ol>`n"); $ol=$true }
            [void]$sb.Append("<li>").Append((Inline $txt)); $olLi=$true
            continue
        }
        if ($t -match '^https?://\S+$') {
            if (-not $srcShown) { [void]$sb.Append('<p class="zrodla-naglowek">' + $script:zrHead + ':</p>' + "`n"); $srcShown = $true }
            [void]$sb.Append('<p class="zrodlo-link">').Append((Inline $t)).Append("</p>`n"); continue
        }
        if ($t -match '^\s*\u00A9' -or $t -match '(?i)^tekst autorski') {
            [void]$sb.Append('<p class="zrodlo-info">').Append((Inline $t)).Append("</p>`n"); continue
        }
        # zwykly tekst akapitu
        $para.Add($t)
    }
    # domkniecie na koncu
    if ($para.Count -gt 0) {
        if ($ul) { [void]$sb.Append("</ul>`n"); $ul=$false }
        if ($olLi) { [void]$sb.Append("</li>`n"); $olLi=$false }
        if ($ol) { [void]$sb.Append("</ol>`n"); $ol=$false }
        [void]$sb.Append("<p>").Append((Inline ($para -join ' '))).Append("</p>`n")
    }
    if ($ul) { [void]$sb.Append("</ul>`n"); $ul=$false }
    if ($olLi) { [void]$sb.Append("</li>`n"); $olLi=$false }
    if ($ol) { [void]$sb.Append("</ol>`n"); $ol=$false }
    return $sb.ToString()
}

function Get-Minutes([string]$md) {
    $md = [regex]::Replace($md, '(?s)^\uFEFF?---.*?---\s*', '')
    $md = $md -replace '[#>*_`\[\]()\-]', ' '
    $words = ($md -split '\s+' | Where-Object { $_ -ne '' }).Count
    $m = [math]::Ceiling($words / 200.0)
    if ($m -lt 1) { $m = 1 }
    return [int]$m
}

function Get-CleanTitle([string]$md) {
    $md = [regex]::Replace($md, '(?s)^\uFEFF?---.*?---\s*', '')
    $md = $md -replace "`r`n","`n" -replace "`r","`n"
    foreach ($lineRaw in ($md -split "`n")) {
        $t = $lineRaw.Trim()
        if ($t -eq "") { continue }
        if ($t -match '^#') { continue }
        if ($t -match '^\*Data') { continue }
        if ($t -match '^>') { continue }
        if ($t -match '^https?://') { continue }
        $t = $t -replace '\*\*','' -replace '\[([^\]]+)\]\([^\)]+\)','$1'
        $m = [regex]::Match($t, '^(.*?[\.\!\?])(\s|$)')
        $title = if ($m.Success) { $m.Groups[1].Value } else { $t }
        $title = $title.Trim()
        if ($title.Length -gt 160) {
            $cut = $title.Substring(0, 160)
            $sp = $cut.LastIndexOf(' ')
            if ($sp -gt 40) { $cut = $cut.Substring(0, $sp) }
            $title = $cut.TrimEnd('.', ',', ';', ':', ' ')
        }
        return $title
    }
    return "Artykuł"
}

function Get-Excerpt([string]$md) {
    $md = [regex]::Replace($md, '(?s)^\uFEFF?---.*?---\s*', '')
    $md = $md -replace "`r`n","`n" -replace "`r","`n"
    foreach ($lineRaw in ($md -split "`n")) {
        $t = $lineRaw.Trim()
        if ($t -eq "") { continue }
        if ($t -match '^#') { continue }
        if ($t -match '^\*Data') { continue }
        if ($t -match '^>') { continue }
        if ($t -match '^https?://') { continue }
        $t = $t -replace '\*\*','' -replace '\[([^\]]+)\]\([^\)]+\)','$1'
        if ($t.Length -gt 155) { $t = $t.Substring(0,155).TrimEnd() + [char]0x2026 }
        return $t
    }
    return ""
}

$items = @()
$tagMap = @{}
$catMap = @{}
foreach ($f in (Get-ChildItem -Path $srcDir -Filter *.md | Where-Object { $_.Name -ne "index.md" } | Sort-Object Name)) {
    $raw = Get-Content -Raw -Encoding UTF8 $f.FullName
    $title = ""
    if ($raw -match '(?m)^tytul:\s*"(.*)"\s*$') { $title = $matches[1] -replace '\\"','"' }
    elseif ($raw -match "(?m)^tytul:\s*'(.*)'\s*$") { $title = $matches[1] }
    elseif ($raw -match '(?m)^tytul:\s*(\S.*?)\s*$') { $title = $matches[1] }
    if ($title -eq "") { $title = ($f.BaseName -replace '^\d+-','') -replace '-',' ' }
    if ($title.EndsWith("...")) { $title = Get-CleanTitle $raw }
    $numKey = if ($f.BaseName -match '^(\d{3})-') { $matches[1] } else { "" }
    if ($numKey -ne "" -and ($titles.PSObject.Properties.Name -contains $numKey)) { $title = $titles.$numKey }
    $date = ""
    if ($raw -match '(?m)^data:\s*"?([^"\r\n]+?)"?\s*$') { $date = $matches[1].Trim() }
    $dt = [datetime]::MinValue
    [void][datetime]::TryParse($date, [ref]$dt)
    if ($dt -ne [datetime]::MinValue -and $dt -gt $nowPL) { continue }   # zaplanowany na przyszlosc — pomijamy do czasu publikacji
    $dateDisplay = if ($dt -ne [datetime]::MinValue) { $dt.ToString('yyyy-MM-dd') } else { $date }

    $slug = $f.BaseName
    $bodyHtml = Convert-Md $raw
    $bodyHtml = Auto-Link $bodyHtml $slug
    # spis tresci: nadaj id naglowkom h2 i zbierz liste
    $toc = New-Object System.Collections.Generic.List[string]
    $hMatches = [regex]::Matches($bodyHtml, '<h2>(.*?)</h2>')
    $hi = 0
    foreach ($hm in $hMatches) {
        $plain = [regex]::Replace($hm.Groups[1].Value, '<[^>]+>', '')
        $hid = Tag-Slug $plain
        if ([string]::IsNullOrEmpty($hid)) { $hid = "sekcja" }
        $hid = $hid + "-" + $hi
        $orig = $hm.Value
        $newH = '<h2 id="' + $hid + '">' + $hm.Groups[1].Value + '</h2>'
        $pos = $bodyHtml.IndexOf($orig)
        if ($pos -ge 0) { $bodyHtml = $bodyHtml.Substring(0, $pos) + $newH + $bodyHtml.Substring($pos + $orig.Length) }
        $toc.Add($hid + "`t" + $plain)
        $hi++
    }
    $spisHtml = ""
    if ($false -and $toc.Count -ge 3) {  # spis tresci na razie wylaczony
        $sbS = New-Object System.Text.StringBuilder
        [void]$sbS.Append('<nav class="spis" aria-label="Spis tresci"><div class="spis-tytul">W tym artykule</div><ul>')
        foreach ($e in $toc) { $pp = $e -split "`t", 2; [void]$sbS.Append('<li><a href="#').Append($pp[0]).Append('">').Append((Esc $pp[1])).Append('</a></li>') }
        [void]$sbS.Append('</ul></nav>')
        $spisHtml = $sbS.ToString()
    }
    $excerpt  = Get-Excerpt $raw
    $minutes  = Get-Minutes $raw
    $extras   = Build-Extras $raw

    # okladka artykulu: 1) z panelu (frontmatter obraz), 2) zdjecie po numerze, 3) generowana SVG
    $num = if ($slug -match '^(\d{3})-') { $matches[1] } else { "" }
    $imgWeb = ""; $imgTag = ""; $ogTag = ""
    $fmImg = ""
    if ($raw -match '(?m)^obraz:\s*"?([^"\r\n]+?)"?\s*$') { $fmImg = $matches[1].Trim() }
    if ($fmImg -ne "") {
        if ($fmImg -notmatch '^/') { $fmImg = "/" + $fmImg }
        $imgWeb = $fmImg
    }
    elseif ($num -ne "" -and $imgMap.ContainsKey($num)) {
        $disk = $imgMap[$num]
        if (Test-Path $disk) {
            $ext = [System.IO.Path]::GetExtension($disk)
            $imgWeb = "/zdjecia/" + $num + $ext
        }
    }
    if ($imgWeb -ne "") {
        $imgTag = '<img class="artykul-foto" src="' + $imgWeb + '" alt="' + (Esc $title) + '" fetchpriority="high" loading="eager">'
        $ogTag = '<meta property="og:image" content="' + $DOMENA + $imgWeb + '">'
    } else {
        $coverName = $slug + ".svg"
        Make-Cover $title $raw (Join-Path $siteDir $coverName)
        $imgWeb = "/" + $coverName
        $imgTag = '<img class="artykul-foto" src="' + $imgWeb + '" alt="' + (Esc $title) + '" fetchpriority="high" loading="eager">'
        $ogTag = '<meta property="og:image" content="' + $DOMENA + $imgWeb + '">'
    }

    $tags = Get-Tags $raw
    $cat = Get-Category $raw
    $katLabel = if ($cat) { $cat.label } else { "" }
    $katSlug  = if ($cat) { $cat.slug } else { "" }
    $thisItem = [PSCustomObject]@{ slug = $slug; title = $title; date = $date; dt = $dt; excerpt = $excerpt; minutes = $minutes; img = $imgWeb; tags = $tags; kategoria = $katLabel; katSlug = $katSlug }
    if ($katSlug -ne "") {
        if (-not $catMap.ContainsKey($katSlug)) { $catMap[$katSlug] = [PSCustomObject]@{ label = $katLabel; items = (New-Object System.Collections.Generic.List[object]) } }
        $catMap[$katSlug].items.Add($thisItem)
    }
    $katHtml = ""
    if ($katSlug -ne "") { $katHtml = '<div class="artykul-kat">Kategoria: <a class="kat-label" href="/kategoria-' + $katSlug + '.html">' + (Esc $katLabel) + '</a></div>' }

    # tagi (klikalne chipy + mapa tag -> artykuly)
    $slowaHtml = ""
    if ($tags.Count -gt 0) {
        $sbT = New-Object System.Text.StringBuilder
        [void]$sbT.Append('<div class="slowa-sekcja"><div class="slowa-label">Tematy w tym artykule</div><div class="slowa">')
        foreach ($tg in $tags) {
            $tgSlug = Tag-Slug $tg
            [void]$sbT.Append('<a class="chip-tag" href="/tag-' + $tgSlug + '.html">').Append((Esc $tg)).Append('</a>')
            if (-not $tagMap.ContainsKey($tg)) { $tagMap[$tg] = New-Object System.Collections.Generic.List[object] }
            [void]$tagMap[$tg].Add($thisItem)
        }
        [void]$sbT.Append('</div></div>')
        $slowaHtml = $sbT.ToString()
    }

    $page = $tplArticle
    $page = $page.Replace("{{TYTUL}}", (Esc $title))
    $page = $page.Replace("{{DATA}}", (Esc $dateDisplay))
    $page = $page.Replace("{{ZAJAWKA}}", (Esc $excerpt))
    $page = $page.Replace("{{CZYTANIE}}", [string]$minutes)
    $page = $page.Replace("{{KATEGORIA}}", $katHtml)
    $page = $page.Replace("{{OGIMAGE}}", $ogTag)
    $page = $page.Replace("{{TWIMAGE}}", '<meta name="twitter:image" content="' + $DOMENA + $imgWeb + '">')
    $page = $page.Replace("{{OBRAZEK}}", $imgTag)
    $page = $page.Replace("{{SPIS}}", $spisHtml)
    $page = $page.Replace("{{SLOWA}}", $slowaHtml)
    # opcjonalny przycisk do posta na Facebooku (frontmatter: fb). Brak pola = brak przycisku.
    $fmFb = ""
    if ($raw -match '(?m)^fb:\s*"?([^"\r\n]+?)"?\s*$') { $fmFb = $matches[1].Trim() }
    $fbHtml = ""
    if ($fmFb -match '^https?://') {
        $fbHtml = '<a class="udostepnij-btn fb" href="' + (Esc $fmFb) + '" target="_blank" rel="noopener">Skomentuj na FB</a>'
    }
    $page = $page.Replace("{{FBPOST}}", $fbHtml)
    $canonical = $DOMENA + "/" + $slug + ".html"
    # hreflang: link do odpowiednika EN (slug EN z folderu content/en)
    $enSlug = ""
    $enDir = Join-Path $base "myneuralgia\content\en"
    $numer = ""
    if ($slug -match '^(\d{3})-') { $numer = $matches[1] }
    if ($numer -ne "" -and (Test-Path $enDir)) {
        $enFile = Get-ChildItem -Path $enDir -Filter "$numer-*.md" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($enFile) { $enSlug = $enFile.BaseName }
    }
    $hreflangEn = if ($enSlug -ne "") { "https://myneuralgia.com/" + $enSlug + ".html" } else { "" }
    $page = $page.Replace("{{HREFLANG_PL}}", $canonical)
    $page = $page.Replace("{{HREFLANG_EN}}", $hreflangEn)
    $aobj = [ordered]@{ "@context"="https://schema.org"; "@type"="BlogPosting"; "headline"=$title; "description"=$excerpt; "author"=[ordered]@{ "@type"="Person"; "name"="Natalia" }; "publisher"=[ordered]@{ "@type"="Organization"; "name"=$siteName }; "mainEntityOfPage"=$canonical }
    if ($date -ne "") { $aobj["datePublished"] = $date }
    if ($imgWeb -ne "") { $aobj["image"] = $DOMENA + $imgWeb } else { $aobj["image"] = $DOMENA + "/placeholder.svg" }
    $articleLd = '<script type="application/ld+json">' + ($aobj | ConvertTo-Json -Depth 6) + '</script>'
    $bcArt = "Artyku" + [char]0x142 + "y"
    $bcObj = [ordered]@{ "@context"="https://schema.org"; "@type"="BreadcrumbList"; "itemListElement"=@(
        [ordered]@{ "@type"="ListItem"; "position"=1; "name"="Start"; "item"=$DOMENA + "/" },
        [ordered]@{ "@type"="ListItem"; "position"=2; "name"=$bcArt; "item"=$DOMENA + "/index.html" },
        [ordered]@{ "@type"="ListItem"; "position"=3; "name"=$title }
    ) }
    $bcLd = '<script type="application/ld+json">' + ($bcObj | ConvertTo-Json -Depth 6) + '</script>'
    $page = $page.Replace("{{CANONICAL}}", $canonical)
    $page = $page.Replace("{{ARTICLE_JSONLD}}", $articleLd)
    $page = $page.Replace("{{BREADCRUMB_JSONLD}}", $bcLd)
    $page = $page.Replace("{{FAQ}}", $extras.faq)
    $page = $page.Replace("{{FAQ_JSONLD}}", $extras.ld)
    $page = $page.Replace("{{TRESC}}", $bodyHtml)
    $page | Out-File -Encoding UTF8 (Join-Path $outArt ($slug + ".html"))

    $items += $thisItem
}

# karty na stronie glownej, najnowsze na gorze
$itemsSorted = $items | Sort-Object dt -Descending

# pasek kategorii na strone glowna (tylko te, ktore maja artykuly)
$katPills = ""
$sbK = New-Object System.Text.StringBuilder
foreach ($kc in $faq.kategorie) {
    if ($catMap.ContainsKey($kc.slug)) {
        [void]$sbK.Append('<a class="kat-pill" href="/kategoria-' + $kc.slug + '.html">').Append((Esc $kc.label)).Append('</a>')
    }
}
if ($sbK.Length -gt 0) { $katPills = '<div class="kontener"><div class="kat-pasek">' + $sbK.ToString() + '</div></div>' }

# indeks wyszukiwarki (tytul, slug, zajawka)
$searchData = @()
foreach ($it in $itemsSorted) { $searchData += [ordered]@{ t = $it.title; s = $it.slug; e = $it.excerpt } }
($searchData | ConvertTo-Json -Depth 3) | Out-File -Encoding UTF8 (Join-Path $siteDir "search-index.json")

# --- powiazane artykuly (wazone wspolne tagi: rzadkie/specyficzne tagi liczą się wiecej) ---
$relHead = "Powi" + [char]0x105 + "zane artyku" + [char]0x142 + "y"
$encR = New-Object System.Text.UTF8Encoding($false)
# czestotliwosc tagow w calym zbiorze (do wagi IDF) - tag rzadki = waga wysoka
$tagFreq = @{}
foreach ($it in $items) { foreach ($t in $it.tags) { if ($tagFreq.ContainsKey($t)) { $tagFreq[$t]++ } else { $tagFreq[$t] = 1 } } }
$Ntot = [Math]::Max(1, $items.Count)
# mapa tag(label) -> wzorzec oraz zbior tagow wystepujacych w TYTULE kazdego artykulu (mocny sygnal tematu)
$kwMap = @{}
foreach ($k in $faq.keywords) { $kwMap[$k.label] = $k.pattern }
$titleTags = @{}
foreach ($it in $items) {
    $set = New-Object System.Collections.Generic.HashSet[string]
    $tl = $it.title.ToLower()
    foreach ($t in $it.tags) {
        $pat = $kwMap[$t]
        if ($pat -and [regex]::IsMatch($tl, $pat)) { [void]$set.Add($t) }
    }
    $titleTags[$it.slug] = $set
}
$titleBoost = 8.0   # duzo wieksza waga gdy wspolny tag jest w tytule
foreach ($it in $items) {
    $scored = @()
    foreach ($other in $items) {
        if ($other.slug -eq $it.slug) { continue }
        $score = 0.0
        foreach ($t in $it.tags) {
            if ($other.tags -contains $t) {
                $f = $tagFreq[$t]; if ($f -lt 1) { $f = 1 }
                $w = [Math]::Log((($Ntot + 1.0) / $f))
                if ($titleTags[$other.slug].Contains($t) -or $titleTags[$it.slug].Contains($t)) { $w *= $titleBoost }
                $score += $w
            }
        }
        if ($score -gt 0) { $scored += [PSCustomObject]@{ it = $other; shared = $score } }
    }
    $top = @($scored | Sort-Object @{Expression={$_.shared};Descending=$true}, @{Expression={$_.it.dt};Descending=$true} | Select-Object -First 3)
    $relHtml = ""
    if ($top.Count -gt 0) {
        $sbR = New-Object System.Text.StringBuilder
        [void]$sbR.Append('<section class="powiazane"><h2>').Append($relHead).Append('</h2><div class="kafelki">')
        foreach ($r in $top) { [void]$sbR.Append((Build-Kafelek $r.it)) }
        [void]$sbR.Append('</div></section>')
        $relHtml = $sbR.ToString()
    }
    $fp = Join-Path $siteDir ($it.slug + ".html")
    if (Test-Path $fp) {
        $c = [System.IO.File]::ReadAllText($fp)
        $c = $c.Replace("{{POWIAZANE}}", $relHtml)
        [System.IO.File]::WriteAllText($fp, $c, $encR)
    }
}

$PER = 24
$total = $itemsSorted.Count
$pages = [int][math]::Ceiling($total / [double]$PER)
if ($pages -lt 1) { $pages = 1 }
for ($p = 1; $p -le $pages; $p++) {
    $start = ($p - 1) * $PER
    $end = [math]::Min($p * $PER, $total) - 1
    $cards = New-Object System.Text.StringBuilder
    foreach ($it in $itemsSorted[$start..$end]) { [void]$cards.Append((Build-Kafelek $it) + "`n") }
    $pag = Build-Pag $p $pages
    if ($p -eq 1) {
        $index = $tplIndex
        $index = $index.Replace("{{LICZBA}}", [string]$total)
        $index = $index.Replace("{{KATEGORIE}}", $katPills)
        $index = $index.Replace("{{KARTY}}", $cards.ToString())
        $index = $index.Replace("{{PAGINACJA}}", $pag)
        $index | Out-File -Encoding UTF8 (Join-Path $siteDir "index.html")
    } else {
        $lp = $tplLista
        $lp = $lp.Replace("{{NRSTRONY}}", [string]$p)
        $lp = $lp.Replace("{{CANONICAL}}", $DOMENA + "/artykuly-" + $p + ".html")
        $lp = $lp.Replace("{{KARTY}}", $cards.ToString())
        $lp = $lp.Replace("{{PAGINACJA}}", $pag)
        $lp | Out-File -Encoding UTF8 (Join-Path $siteDir ("artykuly-" + $p + ".html"))
    }
}

# strony tagow
$tagCount = 0
foreach ($tag in $tagMap.Keys) {
    $list = $tagMap[$tag] | Sort-Object dt -Descending
    $kf = New-Object System.Text.StringBuilder
    foreach ($it in $list) { [void]$kf.Append((Build-Kafelek $it) + "`n") }
    $tp = $tplTag
    $tp = $tp.Replace("{{TAG}}", (Esc $tag))
    $tp = $tp.Replace("{{CANONICAL}}", $DOMENA + "/tag-" + (Tag-Slug $tag) + ".html")
    $tp = $tp.Replace("{{LICZBA}}", [string]$list.Count)
    $tp = $tp.Replace("{{KAFELKI}}", $kf.ToString())
    $tp | Out-File -Encoding UTF8 (Join-Path $siteDir ("tag-" + (Tag-Slug $tag) + ".html"))
    $tagCount++
}

# strony kategorii
$katCount = 0
foreach ($cslug in $catMap.Keys) {
    $centry = $catMap[$cslug]
    $clist = $centry.items | Sort-Object dt -Descending
    $ckf = New-Object System.Text.StringBuilder
    foreach ($it in $clist) { [void]$ckf.Append((Build-Kafelek $it) + "`n") }
    $cp = $tplKat
    $cp = $cp.Replace("{{KATEGORIA}}", (Esc $centry.label))
    $cp = $cp.Replace("{{CANONICAL}}", $DOMENA + "/kategoria-" + $cslug + ".html")
    $cp = $cp.Replace("{{LICZBA}}", [string]$clist.Count)
    $cp = $cp.Replace("{{KAFELKI}}", $ckf.ToString())
    $cp | Out-File -Encoding UTF8 (Join-Path $siteDir ("kategoria-" + $cslug + ".html"))
    $katCount++
}

# --- sitemap.xml ---
$sm = New-Object System.Text.StringBuilder
[void]$sm.Append('<?xml version="1.0" encoding="UTF-8"?>' + "`n")
[void]$sm.Append('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' + "`n")
foreach ($u in @("/", "/dla-ciebie.html", "/o-mnie.html", "/dziennik-bolu.html", "/polityka-prywatnosci.html")) {
    [void]$sm.Append('<url><loc>' + $DOMENA + $u + '</loc></url>' + "`n")
}
for ($p = 2; $p -le $pages; $p++) { [void]$sm.Append('<url><loc>' + $DOMENA + "/artykuly-" + $p + ".html" + '</loc></url>' + "`n") }
foreach ($it in $itemsSorted) { [void]$sm.Append('<url><loc>' + $DOMENA + "/" + $it.slug + ".html" + '</loc></url>' + "`n") }
foreach ($tag in $tagMap.Keys) { [void]$sm.Append('<url><loc>' + $DOMENA + "/tag-" + (Tag-Slug $tag) + ".html" + '</loc></url>' + "`n") }
foreach ($cslug in $catMap.Keys) { [void]$sm.Append('<url><loc>' + $DOMENA + "/kategoria-" + $cslug + ".html" + '</loc></url>' + "`n") }
[void]$sm.Append('</urlset>' + "`n")
$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $siteDir "sitemap.xml"), $sm.ToString(), $enc)

# --- RSS feed.xml ---
$rss = New-Object System.Text.StringBuilder
[void]$rss.Append('<?xml version="1.0" encoding="UTF-8"?>' + "`n")
[void]$rss.Append('<rss version="2.0"><channel>')
[void]$rss.Append('<title>').Append((Esc $siteName)).Append('</title>')
[void]$rss.Append('<link>').Append($DOMENA).Append('/</link>')
[void]$rss.Append('<description>Blog o zyciu z neuralgia i neuropatia nerwu trojdzielnego.</description>')
[void]$rss.Append('<language>pl-pl</language>')
$rcnt = 0
foreach ($it in $itemsSorted) {
    if ($rcnt -ge 30) { break }
    $u = $DOMENA + "/" + $it.slug + ".html"
    [void]$rss.Append('<item>')
    [void]$rss.Append('<title>').Append((Esc $it.title)).Append('</title>')
    [void]$rss.Append('<link>').Append($u).Append('</link>')
    [void]$rss.Append('<guid isPermaLink="true">').Append($u).Append('</guid>')
    $dd = [datetime]::MinValue
    if ([datetime]::TryParse($it.date, [ref]$dd)) {
        [void]$rss.Append('<pubDate>').Append($dd.ToUniversalTime().ToString("r", [System.Globalization.CultureInfo]::InvariantCulture)).Append('</pubDate>')
    }
    [void]$rss.Append('<description>').Append((Esc $it.excerpt)).Append('</description>')
    [void]$rss.Append('</item>')
    $rcnt++
}
[void]$rss.Append('</channel></rss>')
[System.IO.File]::WriteAllText((Join-Path $siteDir "feed.xml"), $rss.ToString(), (New-Object System.Text.UTF8Encoding($false)))

Write-Output ("Wygenerowano stron artykulow: " + $items.Count)
Write-Output ("Wygenerowano stron tagow: " + $tagCount)
Write-Output ("Strona glowna: " + (Join-Path $siteDir "index.html"))
