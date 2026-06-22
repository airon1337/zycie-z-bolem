# SEO & GEO Blueprint dla bloga „Życie z bólem"
### Analiza wzorca dronehub.ai/blog + przełożenie na blog pacjencki o neuralgii i neuropatii

> **Cel:** wyciągnąć sprawdzone praktyki SEO/GEO z bloga DroneHub i przełożyć je 1:1 na nasz blog o życiu z bólem (neuralgia/neuropatia nerwu trójdzielnego). Dokument jest podręcznikiem wdrożeniowym — łączy się z `baza-wiedzy.md` (treść, encje, słowa kluczowe, E-E-A-T) i folderem `artykuly/` (126 gotowych tekstów).
>
> **Status:** wersja 1.0 · 2026-06-19
> **Co analizowano:** strona-indeks `dronehub.ai/blog` oraz wzorcowy artykuł `.../autonomous-ai-rail-inspection-architecture` (wersja renderowana). JSON-LD nie był widoczny bezpośrednio w renderze — schematy poniżej to rekomendacje oparte na widocznych wzorcach.

---

## 1. Co DroneHub robi dobrze (obserwacje)

Najważniejsze, powtarzalne wzorce zaobserwowane na blogu:

1. **Architektura tematyczna, nie chronologiczna.** Hasło wprost: „organized by topic, not by date". Blog dzieli się na **huby tematyczne** (np. `/blog/topics/ai-inspection`) z licznikiem postów (np. „12 POSTS") i wyróżnionym artykułem (FEATURED). To klasyczny model **pillar → cluster (hub & spoke)**.
2. **Sekcja „Recent"** na górze + dalej bloki per temat — szybka orientacja dla użytkownika i robota.
3. **Bogata metryka artykułu:** tag tematu, **„LAST UPDATED · MAY 2026"** (sygnał świeżości), **autor z linkiem** do `/about` (E-E-A-T), **czas czytania** („11 MIN READ").
4. **Dek / lead** pod tytułem — jeden akapit streszczający artykuł (świetny pod meta description, snippety i AI).
5. **Slugi opisowe, nasycone frazą** (`autonomous-ai-rail-inspection-architecture`).
6. **Nagłówki H2 jako tezy/pytania** — skanowalne, semantyczne („Why an autonomous drone-in-a-box… fits", „Where Dronehub fits").
7. **Blok „KEY FACTS"** — wypunktowane fakty, **każdy z przypisanym ŹRÓDŁEM**. Idealne pod GEO (fakty „do zacytowania") i E-E-A-T.
8. **Blok „FAQ"** — 7–8 pytań w języku naturalnym, pytanie jako nagłówek + zwięzła, samodzielna odpowiedź. Wzorzec pod **FAQPage schema**, featured snippets i odpowiedzi AI.
9. **Linkowanie wewnętrzne na 3 sposoby:**
   - kontekstowe linki w akapicie zamykającym do własnych stron (branża/rail, projekt/Deutsche Bahn, ip-licensing, kontakt),
   - moduł **„MORE ON [TEMAT]"** = 3 powiązane artykuły z tego samego huba + „BROWSE ALL",
   - **breadcrumb** („BACK TO BLOG" + link do tematu) i stopka z **Glossary** (`/reference/glossary` — strona definicji/encji).
10. **Sygnały autorytetu/zaufania:** „Trusted by ESA, EDA, and the European Commission", nazwani partnerzy (IBM, Deutsche Bahn), ranking FT 1000 opisany jako „independent third-party signal, not paid placement", osobny temat „Press & Recognition".
11. **Uczciwość i precyzja przekazu** („framed correctly", „an announced engagement and a modelled potential, not a validated deployment"). To buduje zaufanie i **zmniejsza ryzyko, że AI źle zinterpretuje treść** — model dostaje jednoznaczne, ostrożne sformułowania.
12. **Powtarzalny zapis na newsletter** („One email a month. No vendor noise.") — lead capture bez nachalności.

---

## 2. Architektura: topic clusters dla „Życia z bólem"

Przekładamy huby DroneHub na **filary z `baza-wiedzy.md` (sekcja 17)**. Każdy hub = strona `/blog/tematy/<slug>` z opisem, wyróżnionym artykułem i listą tekstów.

| Hub (pillar) | Slug | Artykuły źródłowe (z `artykuly/`) |
|---|---|---|
| Podstawy i mechanizmy bólu | `/tematy/podstawy` | 002, 003, 004, 007, 057, 069, 084, 086 |
| Neuralgia vs neuropatia / typy | `/tematy/rodzaje-bolu` | 017, 018, 033, 034, 048, 076, 079 |
| Diagnoza i różnicowanie | `/tematy/diagnoza` | 009, 021, 023, 035, 041, 051, 123 |
| Leczenie farmakologiczne | `/tematy/leczenie-leki` | 005, 011, 012, 068, 083, 109 |
| Leczenie zabiegowe | `/tematy/leczenie-zabiegowe` | 006, 016, 019, 020 |
| Terapie wspomagające i suplementacja | `/tematy/wspomagajace` | 015, 024, 025, 054, 066, 077, 110, 116 |
| Życie z bólem / psychika / wspólnota | `/tematy/zycie-z-bolem` | 001, 026, 027, 029, 052, 059, 089, 094, 120 |
| Pokrewne zespoły bólu twarzy/głowy | `/tematy/inne-zespoly` | 044, 045, 093, 097, 122, 119 |
| Świadomość, historia, kampanie | `/tematy/swiadomosc` | 031, 037, 038, 039, 080, 091 |

Zasada: **każdy artykuł należy do dokładnie jednego huba** (główny temat) i linkuje do swojego huba (breadcrumb) oraz 2–3 sąsiednich artykułów z tego samego huba (moduł „Więcej o…").

---

## 3. Szablon artykułu (struktura strony)

Kolejność elementów na stronie pojedynczego wpisu (wzorzec DroneHub zaadaptowany do YMYL/zdrowia):

1. **Breadcrumb:** Blog › [Temat] › Tytuł.
2. **Tag tematu** + **„Ostatnia aktualizacja: <miesiąc rok>"** + **autor (link do „O mnie")** + **czas czytania**.
3. **H1** — tytuł z frazą główną.
4. **Lead (dek)** — 2–3 zdania streszczenia (= meta description / odpowiedź dla AI).
5. **Box „W skrócie / Najważniejsze fakty"** (odpowiednik KEY FACTS) — 3–5 punktów, **każdy ze źródłem** (NIH, AAFP, ICHD-3…).
6. **Treść** w H2/H3 jako tezy/pytania; krótkie akapity; pogrubienia kluczowych terminów (jak w `artykuly/`).
7. **Disclaimer medyczny** (widoczny, np. po leadzie lub przed treścią).
8. **FAQ** — 4–8 pytań (FAQPage schema).
9. **Źródła** — lista linków do publikacji/instytucji.
10. **Moduł „Więcej w temacie [Hub]"** — 3 powiązane artykuły + „Zobacz wszystkie".
11. **CTA miękkie** — zapis na newsletter / grupa wsparcia (nie sprzedaż).

---

## 4. SEO on-page — reguły

- **Tytuł (H1 + <title>):** fraza główna na początku; <title> ≤ ~60 znaków. Przykład: „Neuralgia nerwu trójdzielnego — objawy i leczenie".
- **Meta description:** = lead, 140–160 znaków, z frazą i obietnicą wartości.
- **Slug:** krótki, opisowy, z frazą, bez dat (np. `neuralgia-nerwu-trojdzielnego-objawy`). *Uwaga: nasze obecne pliki mają slug z pierwszego zdania — przy publikacji nadać slug pod frazę (patrz `baza-wiedzy.md` sek. 22).*
- **Nagłówki:** jeden H1; H2 jako pytania/tezy zawierające frazy pokrewne i long-tail z `baza-wiedzy.md` (sek. 9 i 19).
- **Świeżość:** pole „Ostatnia aktualizacja" + `dateModified` w JSON-LD; realnie aktualizować filary.
- **Autor jako encja:** spójny podpis „Natalia" z linkiem do strony autora (Person schema). Przy treściach medycznych dodać „Recenzja merytoryczna" jeśli dostępna.
- **Obrazy:** opisowe `alt`, nazwy plików z frazą, lazy-load, WebP.
- **Wydajność/Core Web Vitals:** szybki hosting, obrazy zoptymalizowane (DroneHub serwuje WebP przez `/_next/image`).
- **Sitemap.xml + robots.txt + kanoniczne URL** dla każdej strony.

---

## 5. GEO — optymalizacja pod odpowiedzi AI (Generative Engine Optimization)

GEO = bycie **cytowanym/streszczanym przez asystentów AI** (ChatGPT, Gemini, Perplexity, AI Overviews). Co działa, wprost z wzorca DroneHub:

1. **Samodzielne, „cytowalne" jednostki treści.** Box „Najważniejsze fakty" + FAQ to gotowe fragmenty, które model może wyjąć i przytoczyć. Każdy fakt = jedno zdanie + źródło.
2. **Jawne źródła przy faktach.** DroneHub podpisuje fakty („SOURCE · …"). Dla nas: NIH/NINDS, AAFP 2025, ICHD-3, Merck. To zwiększa „cytowalność" i wiarygodność dla YMYL.
3. **Definicje podane wprost.** Wzorzec: „X to, w istocie, trzy elementy: …". My: „Neuralgia nerwu trójdzielnego to napadowy ból twarzy…". Model uwielbia jednozdaniowe definicje.
4. **Pytania w języku naturalnym** jako nagłówki/FAQ — pokrywają realne zapytania (też głosowe). Bazę pytań mamy w `baza-wiedzy.md` (sek. 13 i 21).
5. **Precyzja i ostrożność** zamiast przesady. Dla zdrowia kluczowe: „u części pacjentów", „według badań", brak obietnic. To dokładnie ton DroneHub („not a validated deployment").
6. **Pokrycie encji i powiązań** (entity coverage). Im pełniej opisujemy encje z `baza-wiedzy.md` (sek. 10 i 18) i relacje między nimi, tym lepiej AI „rozumie" temat. Pomaga **Słowniczek pojęć**.
7. **Dane strukturalne (JSON-LD)** — sekcja 7. Schematy FAQPage, MedicalWebPage, MedicalCondition dają AI i wyszukiwarkom jednoznaczny kontekst.
8. **Konsekwentne, stabilne URL i aktualizacje** — modele i indeksy preferują treści utrzymywane i datowane.

> **Różnica YMYL:** dla zdrowia GEO bez E-E-A-T nie zadziała. Autor + recenzja + źródła + disclaimer to warunek bycia traktowanym jako wiarygodne źródło (patrz sek. 8).

---

## 6. Wzorzec FAQ i „Najważniejszych faktów" (przykłady dla bloga)

**Box „Najważniejsze fakty" — przykład (artykuł o neuralgii):**
- Neuralgia nerwu trójdzielnego to napadowy, jednostronny ból twarzy trwający od kilku sekund do ~2 minut. *Źródło: NINDS/NIH.*
- Lekiem pierwszego wyboru jest karbamazepina; początkową kontrolę bólu uzyskuje ok. 75% pacjentów. *Źródło: AAFP, 2025.*
- Najczęstsza przyczyna to konflikt naczyniowo-nerwowy (ucisk naczynia na nerw). *Źródło: NCBI/StatPearls.*
- Choruje częściej kobiety; szczyt zachorowań 50–69 lat. *Źródło: przegląd epidemiologiczny, PubMed.*

**FAQ — przykład (pytanie jako nagłówek + samodzielna odpowiedź):** korzystamy z gotowych Q&A z `baza-wiedzy.md` (sek. 13 i 21), np. „Czym różni się neuralgia od neuropatii?", „Czy zwykłe leki przeciwbólowe pomagają?", „Do jakiego lekarza się zgłosić?".

---

## 7. JSON-LD — gotowe szablony (do wklejenia w `<head>` lub na końcu `<body>`)

> Dla bloga zdrowotnego łączymy `BlogPosting`/`MedicalWebPage` + `FAQPage` + `BreadcrumbList`. Dla stron o chorobie dodajemy `MedicalCondition`. Wartości w nawiasach `<…>` podmieniamy per artykuł.

**7.1 Artykuł (MedicalWebPage + BlogPosting):**
```json
{
  "@context": "https://schema.org",
  "@type": ["BlogPosting", "MedicalWebPage"],
  "headline": "<Tytuł artykułu>",
  "description": "<Lead / meta description>",
  "image": "https://zyciezbolem.pl/img/<obrazek>.webp",
  "datePublished": "2025-09-24",
  "dateModified": "2026-06-19",
  "inLanguage": "pl-PL",
  "author": {
    "@type": "Person",
    "name": "Natalia",
    "description": "Autorka bloga, osoba żyjąca z neuropatią nerwu trójdzielnego od 2014 r.",
    "url": "https://zyciezbolem.pl/o-mnie"
  },
  "reviewedBy": {
    "@type": "Person",
    "name": "<Imię i nazwisko lekarza>",
    "jobTitle": "neurolog"
  },
  "publisher": {
    "@type": "Organization",
    "name": "Życie z bólem",
    "logo": { "@type": "ImageObject", "url": "https://zyciezbolem.pl/logo.png" }
  },
  "mainEntityOfPage": "https://zyciezbolem.pl/blog/<slug>",
  "citation": [
    "https://www.ninds.nih.gov/...trigeminal-neuralgia-fact-sheet",
    "https://www.aafp.org/pubs/afp/issues/2025/0500/trigeminal-neuralgia.html"
  ]
}
```

**7.2 FAQ (FAQPage):**
```json
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "Czym różni się neuralgia od neuropatii?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Neuralgia to przede wszystkim napadowy ból wzdłuż nerwu, zwykle bez ubytków czucia. Neuropatia to uszkodzenie nerwu, które częściej daje ból stały oraz drętwienie i utratę czucia."
      }
    }
  ]
}
```

**7.3 Okruszki (BreadcrumbList):**
```json
{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": [
    { "@type": "ListItem", "position": 1, "name": "Blog", "item": "https://zyciezbolem.pl/blog" },
    { "@type": "ListItem", "position": 2, "name": "Diagnoza", "item": "https://zyciezbolem.pl/blog/tematy/diagnoza" },
    { "@type": "ListItem", "position": 3, "name": "<Tytuł artykułu>" }
  ]
}
```

**7.4 Strona o chorobie (MedicalCondition) — dla stron filarowych/encyklopedycznych:**
```json
{
  "@context": "https://schema.org",
  "@type": "MedicalCondition",
  "name": "Neuralgia nerwu trójdzielnego",
  "alternateName": ["Nerwoból nerwu trójdzielnego", "Tic douloureux"],
  "signOrSymptom": [
    { "@type": "MedicalSymptom", "name": "napadowy ból twarzy" },
    { "@type": "MedicalSymptom", "name": "ból jak porażenie prądem" }
  ],
  "cause": { "@type": "MedicalCause", "name": "konflikt naczyniowo-nerwowy" },
  "possibleTreatment": [
    { "@type": "Drug", "name": "karbamazepina" },
    { "@type": "MedicalProcedure", "name": "mikrodekompresja naczyniowa (MVD)" }
  ]
}
```

**7.5 Autor + Organizacja (na stronie „O mnie" / globalnie):** `Person` (Natalia) i `Organization`/`WebSite` z `sameAs` do profili (fanpage FB), `potentialAction` SearchAction dla witryny.

---

## 8. E-E-A-T dla YMYL — czego DroneHub nie potrzebuje, a my musimy mieć

Blog zdrowotny to **YMYL** („Your Money or Your Life") — Google i modele AI stosują wyższą poprzeczkę wiarygodności. Oprócz wzorca DroneHub dokładamy:

- **Disclaimer medyczny** na każdej stronie i w stopce (mamy w `baza-wiedzy.md`).
- **Autor + recenzja merytoryczna** (Person + reviewedBy). „Experience" = autentyczna historia Natalii (silny atut E-E-A-T).
- **Źródła wyłącznie renomowane** (NIH, AAFP, ICHD-3, Merck, Cochrane) — lista w `baza-wiedzy.md` sek. 11.
- **Brak obietnic i sprzedaży leków/cudów**; ostrożny język.
- **Aktualność** — data aktualizacji widoczna i prawdziwa.
- **Treści z forów oznaczone jako opinie**, nie porada.
- **Strona „O mnie", „Polityka redakcyjna", „Kontakt", „Prywatność/RODO"** (trust signals z `baza-wiedzy.md` sek. 12 i 20).

---

## 9. Linkowanie wewnętrzne — reguły operacyjne

- **Każdy artykuł:** breadcrumb do huba + 2–3 linki kontekstowe do powiązanych artykułów + moduł „Więcej w temacie" (3 wpisy) + link do **Słowniczka**.
- **Każdy hub:** wyróżniony artykuł (FEATURED) + pełna lista; linki do sąsiednich hubów.
- **Słowniczek pojęć** (`/slowniczek`) — definicje encji z `baza-wiedzy.md` (sek. 10, 18); każda definicja linkuje do artykułów pogłębiających (wzorzec `/reference/glossary` DroneHub).
- **Strony filarowe encyklopedyczne** (np. „Neuralgia nerwu trójdzielnego — kompendium") linkują w dół do artykułów-spoke i w górę z artykułów.
- **Anchor text** opisowy, z frazą (nie „kliknij tutaj").
- **Zasada:** żaden ważny artykuł nie jest „sierotą" — min. 2–3 linki wewnętrzne prowadzące do niego.

---

## 10. Checklista wdrożeniowa (per artykuł)

- [ ] Przypisany hub tematyczny + breadcrumb
- [ ] H1 z frazą; slug pod frazę; <title> ≤ 60 znaków; meta description = lead
- [ ] Lead (2–3 zdania) z definicją/odpowiedzią
- [ ] Box „Najważniejsze fakty" (3–5 pkt) ze źródłami
- [ ] H2 jako pytania/tezy; krótkie akapity; pogrubienia kluczowych terminów
- [ ] Disclaimer medyczny
- [ ] FAQ (4–8 pytań) + JSON-LD FAQPage
- [ ] JSON-LD: BlogPosting/MedicalWebPage + BreadcrumbList (+ MedicalCondition na filarach)
- [ ] Autor (Natalia) + ew. recenzja; data publikacji i aktualizacji
- [ ] Sekcja „Źródła" (2–4 linki do instytucji)
- [ ] Moduł „Więcej w temacie" (3 powiązane) + link do Słowniczka
- [ ] 2–3 linki kontekstowe do własnych artykułów; brak sierot
- [ ] Obrazy: alt z frazą, WebP, lazy-load
- [ ] CTA miękkie (newsletter / wsparcie)

---

*Blueprint oparty na analizie dronehub.ai/blog. Stosować łącznie z `baza-wiedzy.md` (treść, encje, słowa kluczowe, E-E-A-T) oraz korpusem w `artykuly/`. Treści analizy sparafrazowano na potrzeby zgodności licencyjnej.*
