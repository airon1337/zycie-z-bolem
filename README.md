# Życie z bólem — Kompletny przewodnik po projekcie

> Dokumentacja techniczna dla AI i nowych współpracowników. Opisuje strukturę repo, procesy, deploy i konwencje.

---

## Czym jest ten projekt

Blog pacjencki **zyciezbolem.pl** o neuralgii i neuropatii nerwu trójdzielnego — prowadzony przez Natalię, osobę żyjącą z bólem od 2014 roku. Strona łączy osobiste doświadczenie z rzetelnym researchem medycznym.

Wersja angielska: **myneuralgia.com** (automatyczne tłumaczenia z polskiego).

## Hosting i deploy

| Składnik | Technologia | Domena |
|----------|-------------|--------|
| Blog PL | Statyczny HTML na **Cloudflare Pages** | zyciezbolem.pl |
| Blog EN | Statyczny HTML na **Cloudflare Pages** | myneuralgia.com |
| CMS | **Pages CMS** (konfiguracja w `.pages.yml`) | — |
| Komentarze / workers | **Cloudflare Workers + D1** | w `myneuralgia/workers/` |

### Deploy PL (główna strona)

- Folder deployowany: **`publish/`** (kopia `site/` gotowa do uploadu)
- Cloudflare Pages buduje z tego folderu
- Plik `_redirects` — 301 i 302 redirecty obsługiwane przez Cloudflare
- Plik `_headers` — nagłówki bezpieczeństwa i cache

### Deploy EN

- Generator: `myneuralgia/build-en.ps1`
- Źródła: `myneuralgia/content/en/` (pliki .md z frontmatter)
- Szczegóły w `myneuralgia/README.md` i `myneuralgia/SETUP.md`

---

## Struktura repozytorium

```
d:\kiroold\
│
├── artykuly/               # 130 artykułów PL w markdown (ŹRÓDŁO TREŚCI)
│   └── NNN-slug.md         # numerowane, z YAML frontmatter
│
├── artykuly-en/            # 126 artykułów EN w markdown (tłumaczenia)
│
├── site/                   # GOTOWY HTML strony PL (edytowalny)
│   ├── _redirects          # redirecty Cloudflare Pages
│   ├── _headers            # nagłówki HTTP
│   ├── _szablony/          # szablony HTML (base)
│   ├── zdjecia/            # obrazki artykułów (NNN.jpg)
│   ├── index.html          # strona główna
│   ├── dla-ciebie.html     # landing page dla nowych pacjentów
│   ├── o-mnie.html         # o autorce (Natalia)
│   ├── polityka-prywatnosci.html
│   ├── dziennik-bolu.html  # strona + PDF dziennika bólu
│   ├── artykuly-N.html     # paginowane listy artykułów
│   ├── kategoria-*.html    # strony kategorii
│   ├── tag-*.html          # strony tagów
│   ├── NNN-slug.html       # poszczególne artykuły (wygenerowany HTML)
│   ├── feed.xml            # RSS
│   ├── sitemap.xml
│   ├── robots.txt
│   ├── llms.txt            # plik dla crawlerów AI
│   ├── search-index.json   # indeks wyszukiwania klienta (szukaj.js)
│   ├── styl.css            # cały CSS strony
│   └── szukaj.js           # wyszukiwarka po stronie klienta
│
├── publish/                # KOPIA site/ GOTOWA DO DEPLOY (Cloudflare Pages)
│                           # Aktualizowana ręcznie przed deployem
│
├── myneuralgia/            # Wersja EN — osobne repo / sub-project
│   ├── content/en/         # przetłumaczone artykuły .md
│   ├── workers/            # Cloudflare Workers (webhook, tłumaczenie)
│   ├── build-en.ps1        # generator statycznej strony EN
│   ├── schema.sql          # schemat D1
│   └── README.md           # dokumentacja EN
│
├── blog/                   # Artykuły w DOCELOWYM formacie SEO (wzorce)
│
├── zdjecia/                # Oryginalne obrazy (input dla CMS)
│
├── _tools/                 # Skrypty pomocnicze
│
├── .pages.yml              # Konfiguracja Pages CMS (kolekcje, pola)
├── .github/workflows/      # GitHub Actions (deploy, scrape)
│
├── baza-wiedzy.md          # SSOT — wiedza medyczna, voice, SEO, encje
├── seo-geo-blueprint.md    # Strategia SEO/GEO
├── STRUKTURA-STRONY.md     # Dokumentacja architektury treści (plan)
└── README.md               # TEN PLIK
```

---

## Workflow tworzenia treści

### Nowy artykuł PL

1. Pisany w markdown w `artykuly/NNN-slug.md` z frontmatter (tytuł, data, status, obraz)
2. Możliwość edycji przez Pages CMS (GitHub-based)
3. HTML generowany i wkładany do `site/`
4. Po weryfikacji → kopiowany do `publish/` → deploy na Cloudflare Pages

### Nowy artykuł EN

1. Tłumaczony z PL (prompt w `.pages.yml`) przez GPT-4o-mini
2. Zapisywany w `myneuralgia/content/en/` i `artykuly-en/`
3. Build: `build-en.ps1` → Cloudflare Pages

---

## Konwencje nazewnictwa

- **Slugi artykułów PL:** `NNN-krotki-czytelny-slug` (bez `.html` w linkach wewnętrznych, ale pliki mają `.html`)
- **Slugi historyczne (stare, obcięte):** Niektóre artykuły miały kiedyś slugi obcięte do ~55 znaków. Zostały poprawione — nowe nazwy są krótsze i czytelne. Stare slugi obsługiwane przez 301 redirect w `_redirects`.
- **Obrazki:** `zdjecia/NNN.jpg` (numer odpowiada numerowi artykułu)
- **Frontmatter:** YAML — pola: `tytul`, `data`, `status`, `obraz`, `fb`

---

## Ważne pliki konfiguracyjne

| Plik | Rola |
|------|------|
| `site/_redirects` | Redirecty 301/302 (format Cloudflare Pages) |
| `site/_headers` | Nagłówki HTTP (security, cache) |
| `.pages.yml` | Konfiguracja Pages CMS (kolekcje PL i EN) |
| `baza-wiedzy.md` | Single Source of Truth — wiedza, ton, SEO, encje |
| `seo-geo-blueprint.md` | Strategia SEO (hub & spoke, JSON-LD) |
| `STRUKTURA-STRONY.md` | Plan docelowej architektury (huby, szablony) |

---

## Znane problemy i historia napraw

### Broken links (naprawione 2026-07)

Stare obcięte slugi powodowały 404. Naprawione przez:
1. Zamianę linków w WSZYSTKICH plikach HTML w `site/` i `publish/`
2. Utworzenie plików z nowymi slugami (kopie ze starych)
3. Dodanie redirectów z `.html` wariantami w `_redirects`

Mapowanie starych → nowych:
- `017-wiele-osob-slyszac-te-dwa-pojecia-neuralgia-i-neur` → `017-neuralgia-a-neuropatia-roznice`
- `026-zycie-z-bolem-nerwu-trojdzielnego-to-cos-czego-tru` → `026-niewidzialny-bol-twarzy`
- `035-rozmowa-z-lekarzem-o-bolu-neuropatycznym-szczegoln` → `035-jak-rozmawiac-z-lekarzem-o-bolu`
- `086-dla-osob-ktore-dopiero-wsiadaja-na-ten-bolowy-roll` → `086-poradnik-dla-nowo-zdiagnozowanych`

### Email protection 404

Cloudflare automatycznie obfuskuje adresy email w HTML → tworzony URL `/cdn-cgi/l/email-protection` zwraca 404. Obsłużone redirectem 302 → `/o-mnie`.

---

## SEO i struktura strony

- **Model:** Hub & Spoke (filary tematyczne + artykuły szczegółowe)
- **9 filarów tematycznych** opisanych w `baza-wiedzy.md` sekcja 17
- **JSON-LD:** BlogPosting, FAQPage, BreadcrumbList, MedicalWebPage
- **Voice & Tone:** empatyczny, prosty język, rzetelny, z disclaimerem medycznym
- **Persona docelowa:** pacjenci 30-70 lat z bólem twarzy + bliscy

---

## Technologie

- **Statyczny HTML** (bez generatora — ręczne / skryptowe budowanie)
- **Cloudflare Pages** (hosting, CDN, redirecty, headers)
- **Cloudflare Workers + D1** (backend EN: webhook, tłumaczenie, komentarze)
- **Pages CMS** (edycja treści przez GitHub)
- **MailerLite** (newsletter)
- **GitHub Actions** (CI/CD)

---

## Jak kontynuować pracę (dla AI)

1. **Przed edycją treści** — przeczytaj `baza-wiedzy.md` (Voice & Tone, encje, checklist)
2. **Przed zmianami w HTML** — edytuj w `site/`, potem skopiuj do `publish/`
3. **Nowy artykuł** — dodaj .md do `artykuly/`, wygeneruj HTML do `site/`
4. **Naprawianie linków** — sprawdź `_redirects`, szukaj wzorców w `site/*.html`
5. **Wersja EN** — patrz `myneuralgia/README.md`
6. **SEO** — patrz `seo-geo-blueprint.md` i `STRUKTURA-STRONY.md`
