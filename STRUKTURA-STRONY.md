# Struktura strony i plików — blog „Życie z bólem"

> Architektura oparta na `seo-geo-blueprint.md` (model hub & spoke) i `baza-wiedzy.md` (filary, encje). Wzorcowy artykuł: `blog/neuralgia-nerwu-trojdzielnego-objawy-przyczyny-leczenie.md`.

## 1. Mapa adresów (URL / nawigacja)

```
/                                  → strona główna (hero + misja + ostatnie wpisy + filary)
/o-mnie                            → historia Natalii (E-E-A-T: Experience) + Person schema
/polityka-redakcyjna               → jak dobieramy i weryfikujemy źródła (trust)
/kontakt                           → kontakt (bez porad medycznych online)
/slowniczek                        → definicje encji (odpowiednik /reference/glossary)
/blog                              → indeks: „Ostatnie" + bloki per temat (liczniki postów)
/blog/tematy/<hub>                 → strona huba (pillar): opis + FEATURED + lista
/blog/<slug-artykulu>              → pojedynczy artykuł (szablon z blueprintu)
/prywatnosc                        → polityka prywatności / RODO
/mapa-strony.xml, /robots.txt      → SEO techniczne
```

### Huby tematyczne (9 filarów)
```
/blog/tematy/podstawy
/blog/tematy/rodzaje-bolu
/blog/tematy/diagnoza
/blog/tematy/leczenie-leki
/blog/tematy/leczenie-zabiegowe
/blog/tematy/wspomagajace
/blog/tematy/zycie-z-bolem
/blog/tematy/inne-zespoly
/blog/tematy/swiadomosc
```

## 2. Struktura folderów w repozytorium

```
d:\kiro\
├─ baza-wiedzy.md              # SSOT: wiedza, encje, słowa kluczowe, voice, E-E-A-T
├─ seo-geo-blueprint.md        # zasady SEO/GEO + szablony JSON-LD
├─ STRUKTURA-STRONY.md         # ten plik
├─ artykuly\                   # 126 oczyszczonych tekstów źródłowych (surowiec)
│   └─ index.md
├─ blog\                       # artykuły w formacie docelowym (gotowe do publikacji)
│   └─ neuralgia-...-leczenie.md   # wzorzec
├─ huby\                       # opisy stron tematycznych (lead + lista) — do utworzenia
├─ strony\                     # o-mnie, polityka-redakcyjna, kontakt, slowniczek — do utworzenia
└─ _tools\                     # skrypty pomocnicze (ekstrakcja, generacja)
```

## 3. Szablon pojedynczego artykułu (kolejność sekcji)

1. Breadcrumb: Blog › [Hub] › Tytuł
2. Pasek meta: temat · data aktualizacji · autor (link) · czas czytania
3. H1 (fraza główna)
4. Lead (2–3 zdania = meta description / odpowiedź dla AI)
5. Disclaimer medyczny
6. Box „W skrócie — najważniejsze fakty" (3–5 pkt ze źródłami)
7. Treść: H2 jako pytania/tezy, krótkie akapity, pogrubienia kluczowych terminów
8. FAQ (4–8 pytań)
9. Źródła (2–4 linki do instytucji)
10. „Więcej w temacie [Hub]" (3 linki) + Słowniczek
11. JSON-LD: BlogPosting/MedicalWebPage + FAQPage + BreadcrumbList (+ MedicalCondition na filarach)

## 4. Konwencje

- **Slug:** krótki, z frazą główną, bez dat (np. `neuralgia-a-neuropatia`).
- **Frontmatter** jak we wzorcu (`title, slug, meta_description, hub, author, daty, target_keyword`).
- **Jeden artykuł = jeden hub** (główny); linkuje do huba i 2–3 sąsiadów (brak sierot).
- **Pliki źródłowe** w `artykuly\` traktujemy jako surowiec; wersje docelowe trafiają do `blog\`.
- **Status:** `szkic` → `gotowy-do-recenzji` → `opublikowany`.

## 5. Sugerowana kolejność wdrożenia (pierwsze kroki)

1. Strony zaufania: `/o-mnie` (historia Natalii), `/polityka-redakcyjna`, `/kontakt`, disclaimer w stopce.
2. **Cornerstone'y** (po jednym na 2–3 najważniejsze huby), zaczynając od gotowego artykułu o neuralgii.
3. Strony hubów z listami i wyróżnionym artykułem.
4. Słowniczek (encje z `baza-wiedzy.md` sek. 10 i 18) z linkami do artykułów.
5. Przeniesienie kolejnych tekstów z `artykuly\` do formatu `blog\` (priorytet: filary Podstawy, Diagnoza, Leczenie).
6. SEO techniczne: sitemap, robots, kanoniczne URL, JSON-LD globalny (Organization/WebSite).

## 6. Co jeszcze trzeba ustalić (decyzje)

- **Domena/nazwa** (przyjęto roboczo `zyciezbolem.pl` w przykładach JSON-LD — do zmiany).
- **Technologia:** statyczny generator (np. Astro/Hugo/Eleventy) dobrze pasuje do markdown + szybkich Core Web Vitals i łatwego JSON-LD.
- **Recenzja medyczna:** czy będzie recenzent (pole `reviewed_by`) — wpływa na E-E-A-T.
- **Newsletter/społeczność:** narzędzie do zapisów i ewentualne połączenie z grupą FB.
```
