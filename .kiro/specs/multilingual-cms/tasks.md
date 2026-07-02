# Implementation Tasks

## Phase 1: Repository Restructure

- [ ] 1.1 Create folder structure in GitHub repo: `/content/pl/` (move existing artykuly/ here), `/content/en/` (empty, for translations)
- [ ] 1.2 Update Pages CMS configuration to point to new `/content/pl/` path for Polish articles
- [ ] 1.3 Verify Pages CMS still works correctly after folder restructure (create test article, confirm it appears)
- [ ] 1.4 Create `/workers/` folder in repo for Cloudflare Worker source code

## Phase 2: Astro Static Site Setup

- [ ] 2.1 Initialize Astro project in repo root with Cloudflare Pages adapter, TypeScript, and content collections configured for `/content/pl/` and `/content/en/`
- [ ] 2.2 Define Astro content collection schema matching existing markdown frontmatter (title, slug, date, status, meta_title, meta_description, tags, source_ref)
- [ ] 2.3 Create article page template (`[...slug].astro`) that renders markdown with proper HTML structure, meta tags, and Schema.org JSON-LD
- [ ] 2.4 Create article list/index page with pagination
- [ ] 2.5 Implement hreflang generation: for each article, query siblings via source_ref frontmatter field, output `<link rel="alternate">` tags
- [ ] 2.6 Implement canonical URL generation per article page
- [ ] 2.7 Add `@astrojs/sitemap` integration generating sitemap.xml with only published articles for the current language
- [ ] 2.8 Create dynamic robots.txt page serving domain-specific content
- [ ] 2.9 Implement language-based filtering: Astro config uses environment variable to determine which language folder to build (PL or EN)
- [ ] 2.10 Create base layout with: header (logo, nav), footer (disclaimer, copyright), head (analytics, favicon, OG tags)
- [ ] 2.11 Style the site with Tailwind CSS — clean, readable, mobile-first design appropriate for medical content

## Phase 3: Cloudflare Pages Deployment

- [ ] 3.1 Create Cloudflare Pages project "zyciezbolem-pl" connected to GitHub repo, build command: `astro build` with env LANGUAGE=pl, deploy to custom domain zyciezbolem.pl
- [ ] 3.2 Create Cloudflare Pages project "myneuralgia-en" connected to same GitHub repo, build command: `astro build` with env LANGUAGE=en, deploy to custom domain myneuralgia.com
- [ ] 3.3 Configure build watch paths so PL project rebuilds on changes to `/content/pl/` or `/src/`, EN project rebuilds on changes to `/content/en/` or `/src/`
- [ ] 3.4 Verify both sites build and deploy correctly with test content
- [ ] 3.5 Configure custom domains and DNS in Cloudflare for both sites

## Phase 4: Cloudflare D1 Database Setup

- [ ] 4.1 Create Cloudflare D1 database named "multilingual-cms"
- [ ] 4.2 Create SQL schema file with all tables: domains, article_groups, translations, translation_history, settings
- [ ] 4.3 Run schema migration on D1 database using Wrangler CLI
- [ ] 4.4 Insert initial data: domains (zyciezbolem.pl/pl, myneuralgia.com/en), settings (translation_prompt, active_ai_provider, active_ai_model, max_retries, target_languages)
- [ ] 4.5 Create and run import script that reads all 128 existing Polish markdown files, parses frontmatter, and inserts article_group records into D1 with status "not_started" for English translations

## Phase 5: Webhook Worker

- [ ] 5.1 Initialize Cloudflare Worker project in `/workers/webhook/` with wrangler.toml binding to D1 and Queue
- [ ] 5.2 Implement GitHub webhook signature validation (HMAC-SHA256) using the `GITHUB_WEBHOOK_SECRET` environment variable
- [ ] 5.3 Implement push event handler: parse commit payload, extract list of added/modified .md files in `/content/pl/`
- [ ] 5.4 For each new .md file: create article_group in D1 (if not exists), enqueue translation job to Cloudflare Queue for each target language
- [ ] 5.5 For each modified .md file: look up existing article_group in D1, enqueue re-translation job
- [ ] 5.6 Implement idempotency: check if a translation job with status "queued" or "in_progress" already exists before enqueuing duplicate
- [ ] 5.7 Deploy Webhook Worker to Cloudflare, note the URL
- [ ] 5.8 Configure GitHub repository webhook: URL = Worker URL, Content type = application/json, Secret = same as GITHUB_WEBHOOK_SECRET, Events = push

## Phase 6: Queue Consumer Worker (AI Translation)

- [ ] 6.1 Initialize Cloudflare Worker project in `/workers/queue-consumer/` with wrangler.toml binding to D1, Queue (as consumer), and environment secrets (OPENAI_API_KEY, GITHUB_TOKEN)
- [ ] 6.2 Define AIProvider TypeScript interface and TranslationRequest/TranslationResult types
- [ ] 6.3 Implement OpenAI provider: constructs messages with system prompt (from D1 settings) + user message (article content), calls chat completions API, parses response into TranslationResult
- [ ] 6.4 Implement provider registry that returns correct AIProvider instance based on D1 setting `active_ai_provider`
- [ ] 6.5 Implement queue message handler: fetch source .md from GitHub API, call AI provider, handle response
- [ ] 6.6 On successful translation: push translated .md file to `/content/en/` folder via GitHub API (using GITHUB_TOKEN), update D1 translations table (status="draft", file_path, slug, meta fields)
- [ ] 6.7 On successful translation: insert record into translation_history table (tokens, cost, model, duration, status="success")
- [ ] 6.8 On failure: update D1 translations table (increment retry_count, set error_message, set last_attempt_at), throw error so Queue retries
- [ ] 6.9 On max retries exceeded: update status to "failed" in D1, insert failure record into translation_history, consume message (stop retrying)
- [ ] 6.10 Implement cost estimation: calculate based on model pricing (input tokens × price + output tokens × price)
- [ ] 6.11 Configure Queue consumer settings in wrangler.toml: max_batch_size=1, max_retries=5, dead_letter_queue=none (handle in code)
- [ ] 6.12 Deploy Queue Consumer Worker to Cloudflare

## Phase 7: Admin Dashboard Worker

- [ ] 7.1 Initialize Cloudflare Worker project in `/workers/dashboard/` with wrangler.toml binding to D1 and Queue
- [ ] 7.2 Implement simple password authentication: compare request header/param against `DASHBOARD_PASSWORD` secret, return 401 if invalid
- [ ] 7.3 Implement GET / endpoint serving HTML dashboard page with: overview stats (articles per language, queue length, failures, total cost)
- [ ] 7.4 Implement GET /api/articles endpoint returning article list with translation statuses from D1
- [ ] 7.5 Implement GET /api/history endpoint returning translation_history records with pagination and filtering
- [ ] 7.6 Implement POST /api/retry endpoint: accepts article_group_id + language, enqueues new translation job to Queue, resets status to "queued"
- [ ] 7.7 Implement POST /api/translate-all endpoint: finds all article_groups with status "not_started" or "failed" for target language, enqueues translation jobs
- [ ] 7.8 Create clean HTML/CSS dashboard UI (inline styles or Tailwind CDN) showing stats cards, article table with status indicators, retry buttons
- [ ] 7.9 Deploy Dashboard Worker to Cloudflare, accessible at e.g., cms-dashboard.zyciezbolem.pl or a Workers subdomain

## Phase 8: Manual Translation Detection

- [ ] 8.1 In Webhook Worker: detect when pushed .md files are in a target language folder (e.g., `/content/en/`) and the commit author is NOT the bot/GitHub token
- [ ] 8.2 When manual translation detected: parse frontmatter for `source_ref` field, look up article_group in D1
- [ ] 8.3 If source_ref found and valid: update D1 translations table (status="draft", origin="manual", file_path), insert translation_history record (origin="manual")
- [ ] 8.4 If source_ref missing or invalid: insert record with status="unlinked" for admin review in dashboard
- [ ] 8.5 Update dashboard UI to show "Manual" badge for manually translated articles and "Unlinked" warning for articles without valid source_ref

## Phase 9: SEO Finalization

- [ ] 9.1 Implement Open Graph meta tags in Astro layout (og:title, og:description, og:image, og:locale, og:type)
- [ ] 9.2 Implement Schema.org Article JSON-LD with: headline, description, datePublished, dateModified, author, inLanguage, publisher
- [ ] 9.3 Implement Schema.org FAQ JSON-LD for articles containing FAQ sections (detect by heading pattern)
- [ ] 9.4 Verify hreflang implementation across both sites with a test article that has both PL and EN versions
- [ ] 9.5 Submit both sitemaps to respective Google Search Console properties
- [ ] 9.6 Configure separate Google Analytics 4 properties for each domain (tracking IDs in Astro build env vars)

## Phase 10: Testing and Validation

- [ ] 10.1 End-to-end test: create new Polish article in Pages CMS → verify webhook fires → verify job appears in queue → verify English .md appears in repo → verify EN site rebuilds with new article
- [ ] 10.2 Test error handling: temporarily use invalid API key → verify retries happen → verify "Failed" status appears in dashboard → fix key → verify manual retry works
- [ ] 10.3 Test manual translation: push English .md file directly to repo with source_ref → verify dashboard shows it as "Manual" with correct linking
- [ ] 10.4 Test idempotency: trigger same webhook twice → verify no duplicate translations created
- [ ] 10.5 Validate SEO: check hreflang tags, canonical URLs, sitemap content, robots.txt for both domains
- [ ] 10.6 Load existing 128 articles: run bulk translate (via dashboard "Translate All Missing") → verify articles appear as Drafts

## Phase 11: Documentation and Handoff

- [ ] 11.1 Write README.md with: architecture overview, how to add a new language, how to change AI model, how to access dashboard, troubleshooting common issues
- [ ] 11.2 Document the translation prompt in a separate file with explanation of each instruction
- [ ] 11.3 Document Cloudflare configuration: which Workers exist, which bindings they have, which secrets are set
- [ ] 11.4 Create "Adding a New Language" guide: what to change in D1, what folder to create, what Cloudflare Pages project to create
