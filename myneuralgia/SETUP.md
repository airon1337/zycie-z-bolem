# Instrukcja Wdrożenia — MyNeuralgia

## Co potrzebujesz (zanim zaczniesz)

1. **Konto Cloudflare** (masz już — z zyciezbolem.pl)
2. **Konto GitHub** (masz — airon1337)
3. **Klucz OpenAI API** — wchodzisz na https://platform.openai.com/api-keys i tworzysz nowy
4. **Node.js** zainstalowany na komputerze (do jednorazowego deploy'u Workers)
5. **Wrangler CLI** — instalujesz komendą: `npm install -g wrangler`

---

## KROK 1: Stwórz nowe repozytorium na GitHubie

1. Idź na https://github.com/new
2. Nazwa repozytorium: `myneuralgia`
3. Ustaw jako **Public** lub **Private** (jak wolisz)
4. Kliknij **Create repository**
5. Wrzuć tam cały folder `myneuralgia/` z tego projektu (instrukcja poniżej)

### Jak wrzucić pliki na GitHub (z tego folderu)

Na swoim komputerze otwórz terminal w folderze `myneuralgia/`:

```bash
cd myneuralgia
git init
git add .
git commit -m "Initial commit — MyNeuralgia CMS"
git branch -M main
git remote add origin https://github.com/airon1337/myneuralgia.git
git push -u origin main
```

---

## KROK 2: Stwórz Cloudflare D1 bazę danych

W terminalu (z folderem workers/webhook lub dowolnym workerem):

```bash
wrangler login
wrangler d1 create myneuralgia-cms
```

Zanotuj **database_id** — pojawi się w output. Wstaw go do WSZYSTKICH plików `wrangler.toml`:
- `workers/webhook/wrangler.toml`
- `workers/queue-consumer/wrangler.toml`
- `workers/dashboard/wrangler.toml`

Zmień `REPLACE_WITH_YOUR_DB_ID` na prawdziwy ID.

Potem załaduj schemat:

```bash
wrangler d1 execute myneuralgia-cms --file=../../schema.sql
```

---

## KROK 3: Stwórz Cloudflare Queue

```bash
wrangler queues create translation-queue
```

---

## KROK 4: Ustaw sekrety (hasła i klucze API)

Dla Webhook Worker:
```bash
cd workers/webhook
wrangler secret put GITHUB_WEBHOOK_SECRET
```
(wpisz dowolne hasło, np. `mojetajnehaslo123` — potem użyjesz go w GitHubie)

Dla Queue Consumer:
```bash
cd workers/queue-consumer
wrangler secret put OPENAI_API_KEY
wrangler secret put GITHUB_TOKEN
```
- `OPENAI_API_KEY` — Twój klucz z platform.openai.com
- `GITHUB_TOKEN` — Personal Access Token z GitHub (Settings → Developer settings → Personal access tokens → Fine-grained tokens → Create → uprawnienia: Contents: Read and write, dla repo myneuralgia)

Dla Dashboard:
```bash
cd workers/dashboard
wrangler secret put DASHBOARD_PASSWORD
```
(wpisz hasło, którego będziesz używać do logowania na dashboard)

---

## KROK 5: Deploy Workers

```bash
cd workers/webhook
wrangler deploy

cd ../queue-consumer
wrangler deploy

cd ../dashboard
wrangler deploy
```

Każdy deployment poda Ci URL. Zanotuj URL **webhook workera** (np. `https://myneuralgia-webhook.airon1337.workers.dev`).

---

## KROK 6: Skonfiguruj GitHub Webhook

1. Idź do repo **zycie-z-bolem** na GitHubie
2. Settings → Webhooks → Add webhook
3. **Payload URL:** wklej URL Webhook Workera z kroku 5
4. **Content type:** `application/json`
5. **Secret:** to samo hasło co w KROK 4 (`GITHUB_WEBHOOK_SECRET`)
6. **Events:** wybierz "Just the push event"
7. Kliknij **Add webhook**

---

## KROK 7: Połącz Cloudflare Pages z repo myneuralgia

1. Zaloguj się na Cloudflare Dashboard → Pages
2. Create project → Connect to Git → Wybierz repo `myneuralgia`
3. Build settings:
   - **Framework preset:** Astro
   - **Build command:** `npm run build`
   - **Build output directory:** `dist`
4. **Custom domain:** myneuralgia.com (lub jakąkolwiek domenę kupisz)
5. Kliknij **Save and Deploy**

---

## KROK 8: Import istniejących artykułów do bazy

Po deploy'u Workers, wejdź na dashboard:
```
https://myneuralgia-dashboard.airon1337.workers.dev?key=TWOJE_HASLO
```

Kliknij **Translate All Missing** — system przetłumaczy wszystkie artykuły w tle.

Alternatywnie: możesz zaimportować artykuły ręcznie, uruchamiając import script (opiszę jak to zrobić).

---

## Po wdrożeniu — Twój workflow

1. **Piszesz artykuł** w Pages CMS (jak zwykle)
2. **System automatycznie** tłumaczy i tworzy Draft
3. **Wchodzisz na** Pages CMS dla myneuralgia → sprawdzasz Draft → zmieniasz status na published
4. **Strona się buduje** automatycznie

Dashboard: `https://myneuralgia-dashboard.airon1337.workers.dev?key=TWOJE_HASLO`

---

## Rozwiązywanie problemów

| Problem | Rozwiązanie |
|---------|-------------|
| Tłumaczenie nie startuje | Sprawdź webhook w GitHub (Settings → Webhooks → Recent deliveries) |
| Status "Failed" | Wejdź na Dashboard, sprawdź błąd, kliknij Retry |
| OpenAI timeout | System ponowi automatycznie (do 5 razy) |
| Strona się nie buduje | Sprawdź Cloudflare Pages → Deployments |

---

## Dodawanie nowego języka (przyszłość)

1. Dodaj folder `content/de/` (np. niemiecki)
2. Zmień `TARGET_LANGUAGES` w `workers/webhook/wrangler.toml` na `"en,de"`
3. Stwórz nowy Cloudflare Pages project dla niemieckiej domeny
4. Redeploy webhook worker: `cd workers/webhook && wrangler deploy`
5. Gotowe — nowe artykuły będą tłumaczone też na niemiecki
