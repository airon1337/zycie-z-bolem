# Implementation Plan: Multilingual CMS

## Overview

Build a zero-maintenance multilingual blog system on Cloudflare's free tier. The implementation follows the design architecture: shared utilities and D1 schema first, then each Worker independently, followed by Astro sites, import script, and final wiring/deployment.

## Tasks

- [ ] 1. Set up repository structure, D1 schema, and shared utilities
  - [ ] 1.1 Create repository folder structure and initialize packages
    - Create `content/pl/`, `content/en/`, `sites/pl/`, `sites/en/`, `workers/webhook-worker/`, `workers/queue-consumer/`, `workers/admin-dashboard/`, `workers/shared/`, `scripts/` directories
    - Initialize root `package.json` with workspace configuration (monorepo), Vitest, and fast-check as dev dependencies
    - Initialize each worker's `package.json` and `wrangler.toml` with D1, Queue, and environment variable bindings
    - _Requirements: 1.6, 13.4_

  - [ ] 1.2 Create D1 database schema migration file
    - Write SQL schema file containing all tables: `article_groups`, `articles`, `translation_history`, `settings`, `webhook_log`
    - Include all indexes: `idx_articles_group_id`, `idx_articles_language`, `idx_articles_status`, `idx_history_article`, `idx_webhook_log_sha`
    - Include `UNIQUE` constraints as defined in the design (group_id + language_code, commit_sha + file_path)
    - _Requirements: 2.1, 2.3, 2.4, 2.6_

  - [ ] 1.3 Implement shared TypeScript types and interfaces
    - Create `workers/shared/src/types.ts` with: `TranslationJob`, `TranslationJobMessage`, `TranslationRequest`, `TranslationResult`, `AIProvider` interface, `ArticleStatus` enum, `Env` interfaces for each worker
    - Create `workers/shared/src/constants.ts` with valid statuses, language codes, and error categories
    - _Requirements: 2.6, 5.1, 5.4_

  - [ ] 1.4 Implement slug generation utility
    - Create `workers/shared/src/slug.ts` with a function that generates valid URL slugs from arbitrary input strings
    - Must produce: non-empty, lowercase, alphanumeric + hyphens only, no leading/trailing hyphens, no consecutive hyphens
    - Handle Unicode characters (Polish diacritics, special chars) via transliteration
    - _Requirements: 4.6, 11.4_

  - [ ]* 1.5 Write property tests for slug generation (Property 8)
    - **Property 8: Slug Generation Validity**
    - Generate random Unicode strings, verify output matches: non-empty, lowercase, `[a-z0-9-]+`, no leading/trailing hyphens, no consecutive hyphens
    - **Validates: Requirements 4.6, 11.4**

  - [ ] 1.6 Implement frontmatter parser/serializer utility
    - Create `workers/shared/src/frontmatter.ts` with functions to parse YAML frontmatter from markdown and serialize it back
    - Must preserve all field values and preserve markdown body byte-for-byte through parse/serialize cycle
    - _Requirements: 4.7, 11.2_

  - [ ]* 1.7 Write property tests for frontmatter round-trip (Property 19)
    - **Property 19: Frontmatter Parsing Round-Trip**
    - Generate random YAML frontmatter objects + markdown bodies, verify parse/serialize preserves all values
    - **Validates: Requirements 11.2, 11.3**

  - [ ] 1.8 Implement file path construction utility
    - Create `workers/shared/src/paths.ts` with a function that builds output file paths: `content/{targetLanguage}/{slug}.md`
    - _Requirements: 4.4_

  - [ ]* 1.9 Write property tests for file path construction (Property 9)
    - **Property 9: File Path Construction**
    - Generate random language codes + slugs, verify output matches `content/{lang}/{slug}.md` pattern
    - **Validates: Requirements 4.4**

  - [ ] 1.10 Implement status machine utility
    - Create `workers/shared/src/status.ts` with a function that validates and performs status transitions
    - Valid transitions: Not_Started→Queued→In_Progress→Draft→Published, In_Progress→Failed, and Unlinked for manual translations without source_ref
    - _Requirements: 2.6, 4.5_

  - [ ]* 1.11 Write property tests for status machine (Property 10)
    - **Property 10: Translation Status Machine**
    - Generate random sequences of state transitions, verify only valid transitions succeed and invalid transitions are rejected
    - **Validates: Requirements 2.6, 4.5**

  - [ ] 1.12 Implement error classification utility
    - Create `workers/shared/src/errors.ts` with a function that classifies errors as transient (retry) or permanent (fail)
    - Transient: timeout, HTTP 5xx, HTTP 429. Permanent: HTTP 4xx (excluding 429), malformed content, missing source
    - _Requirements: 6.1, 6.3_

  - [ ]* 1.13 Write property tests for error classification (Property 11)
    - **Property 11: Error Classification**
    - Generate random HTTP status codes and error types, verify correct classification as transient or permanent
    - **Validates: Requirements 6.1, 6.3**

- [ ] 2. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 3. Implement Webhook Worker
  - [ ] 3.1 Implement HMAC-SHA256 webhook signature validation
    - Create `workers/webhook-worker/src/signature.ts` with a function that computes and compares HMAC-SHA256 signatures
    - Reject requests with HTTP 401 if signature is invalid or absent
    - _Requirements: 12.1, 12.2_

  - [ ]* 3.2 Write property tests for webhook signature validation (Property 17)
    - **Property 17: Webhook Signature Validation**
    - Generate random payloads + secrets, compute HMAC-SHA256, verify accept/reject logic
    - **Validates: Requirements 12.1, 12.2**

  - [ ] 3.3 Implement GitHub push payload parser
    - Create `workers/webhook-worker/src/parser.ts` with a function that extracts added/modified `.md` files from `/content/pl/` directory only
    - Ignore files outside `/content/pl/` and non-.md files
    - _Requirements: 3.2, 3.6_

  - [ ]* 3.4 Write property tests for payload parsing (Property 5)
    - **Property 5: Webhook Payload Parsing**
    - Generate random GitHub push payloads with mixed file paths, verify only `/content/pl/*.md` files are extracted
    - **Validates: Requirements 3.2, 3.6**

  - [ ] 3.5 Implement translation job enqueuing logic
    - Create `workers/webhook-worker/src/enqueue.ts` with logic to: create/update Article_Group in D1, enqueue one job per target language for new articles, enqueue re-translation jobs only for languages with existing translations for modified articles
    - Check `webhook_log` for idempotency (skip already-processed commit+file combinations)
    - _Requirements: 3.3, 3.4, 3.5_

  - [ ]* 3.6 Write property tests for enqueuing logic (Properties 6, 20)
    - **Property 6: Translation Job Enqueuing**
    - **Property 20: Translation Idempotency**
    - Generate random article states + target languages, verify correct number of jobs enqueued. Generate repeated commit SHAs, verify no duplicate jobs.
    - **Validates: Requirements 3.3, 3.4**

  - [ ] 3.7 Wire Webhook Worker entrypoint
    - Create `workers/webhook-worker/src/index.ts` combining signature validation, payload parsing, and enqueue logic
    - Ensure response is returned within 5 seconds (defer all heavy processing to queue)
    - Write `wrangler.toml` with D1 binding, Queue binding, and secrets references
    - _Requirements: 3.1, 3.5, 12.1_

  - [ ]* 3.8 Write unit tests for Webhook Worker
    - Test: valid webhook with single new file, multiple files, only non-Polish files (no-op), invalid signature rejection
    - _Requirements: 3.1, 3.2, 3.5, 3.6, 12.1, 12.2_

- [ ] 4. Implement Queue Consumer and AI Provider
  - [ ] 4.1 Implement OpenAI AI Provider
    - Create `workers/queue-consumer/src/ai-provider.ts` implementing the `AIProvider` interface from shared types
    - Use `gpt-4o-mini` model with structured JSON output for title/slug/meta extraction
    - Include system prompt for medical content translation preserving markdown structure
    - Implement `estimateCost()` based on token counts and model rates
    - _Requirements: 5.1, 5.2, 4.2, 4.3_

  - [ ] 4.2 Implement translation history logging
    - Create `workers/queue-consumer/src/history.ts` with a function to record translation attempts in `translation_history` table
    - Record: ai_provider, ai_model, input_tokens, output_tokens, estimated_cost_usd, execution_time_ms, status, error_message, attempt_number
    - _Requirements: 6.6, 7.1_

  - [ ]* 4.3 Write property tests for history logging (Property 12)
    - **Property 12: Translation History Logging**
    - Generate random translation attempt results, verify all required fields are stored correctly
    - **Validates: Requirements 6.6, 7.1**

  - [ ] 4.4 Implement translated markdown file builder
    - Create `workers/queue-consumer/src/builder.ts` with a function that constructs the complete translated markdown file
    - Include frontmatter: title, description, slug, source_ref, translation_date, ai_model, author, tags
    - Append translated body content after frontmatter
    - _Requirements: 4.6, 4.7, 9.1, 9.2_

  - [ ]* 4.5 Write property tests for frontmatter completeness (Property 7)
    - **Property 7: Translated Frontmatter Completeness**
    - Generate random AI translation results, verify output frontmatter contains all required fields (title, description, slug, source_ref, translation_date, ai_model)
    - **Validates: Requirements 4.7, 9.1, 9.2**

  - [ ] 4.6 Implement GitHub file push utility
    - Create `workers/queue-consumer/src/github.ts` with functions to: fetch file content from GitHub API, push (create/update) file to GitHub API using the dedicated bot token
    - _Requirements: 4.1, 4.4, 12.6_

  - [ ] 4.7 Implement manual translation detection logic
    - Create `workers/queue-consumer/src/manual-detection.ts` (or in webhook-worker) with logic to detect non-bot pushes to target language folders
    - Match source_ref frontmatter field to link to Source_Article; mark as "Unlinked" if source_ref is missing
    - _Requirements: 8.1, 8.2, 8.3, 8.5_

  - [ ]* 4.8 Write property tests for manual detection (Properties 15, 16)
    - **Property 15: Manual Translation Detection**
    - **Property 16: Source Ref Matching**
    - Generate random push events with bot/non-bot identities, verify classification. Generate translations with/without source_ref, verify linking/unlinking.
    - **Validates: Requirements 8.1, 8.3, 8.5**

  - [ ] 4.9 Wire Queue Consumer entrypoint
    - Create `workers/queue-consumer/src/index.ts` with the `queue()` handler processing batches of `TranslationJob` messages
    - Implement: fetch source → call AI → build translated file → push to GitHub → update D1 status → log history
    - Handle transient errors with `message.retry()` and permanent errors with `message.ack()` + mark Failed
    - Write `wrangler.toml` with D1 binding, Queue consumer binding, and secrets references
    - _Requirements: 4.1, 4.2, 4.4, 4.5, 5.1, 6.1, 6.3, 13.1_

  - [ ]* 4.10 Write property tests for history preservation (Property 13)
    - **Property 13: History Preservation on Re-translation**
    - Generate random re-translation sequences, verify previous history entries are preserved and count increments by one
    - **Validates: Requirements 7.4**

  - [ ]* 4.11 Write unit tests for Queue Consumer
    - Test: successful translation end-to-end (mocked AI), failed translation with error capture, retranslation preserving history
    - _Requirements: 4.1, 4.4, 4.5, 6.1, 6.3, 7.4_

- [ ] 5. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 6. Implement Admin Dashboard
  - [ ] 6.1 Implement dashboard authentication
    - Create `workers/admin-dashboard/src/auth.ts` with password-based authentication using `ADMIN_TOKEN` from Worker Secrets
    - Return HTTP 401 for requests without valid credentials, not revealing any data
    - _Requirements: 10.5, 12.4_

  - [ ]* 6.2 Write property tests for dashboard authentication (Property 18)
    - **Property 18: Dashboard Authentication**
    - Generate random requests with valid/invalid/missing tokens, verify correct accept/reject behavior
    - **Validates: Requirements 10.5, 12.4**

  - [ ] 6.3 Implement dashboard statistics API
    - Create `workers/admin-dashboard/src/stats.ts` with D1 queries for: total articles per language, translation coverage %, current queue length, recent failures, total estimated cost, aggregate statistics (total tokens, average cost per article)
    - _Requirements: 10.2, 7.5_

  - [ ]* 6.4 Write property tests for aggregate statistics (Property 14)
    - **Property 14: Aggregate Statistics Correctness**
    - Generate random sets of translation_history records, verify computed aggregates match: total_tokens, total_cost, translations_completed, translations_failed, average_cost
    - **Validates: Requirements 7.5**

  - [ ] 6.5 Implement retry and bulk translate actions
    - Create `workers/admin-dashboard/src/actions.ts` with: retry single failed translation (enqueue new job), "Translate All Missing" bulk action (enqueue jobs for all Not_Started articles)
    - _Requirements: 6.5, 10.4, 7.3_

  - [ ] 6.6 Implement dashboard HTML frontend
    - Create `workers/admin-dashboard/src/dashboard.html` (or inline template) with: summary cards, article table with status/cost/timestamps, failed items list with retry buttons, bulk translate button, active AI provider/model display
    - Serve as static HTML from the Worker with embedded CSS (no build step)
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 5.3, 10.6_

  - [ ] 6.7 Wire Admin Dashboard entrypoint
    - Create `workers/admin-dashboard/src/index.ts` with routing: GET / → dashboard HTML, POST /retry/:articleId → retry action, POST /translate-all → bulk action, GET /api/stats → JSON stats
    - Write `wrangler.toml` with D1 binding, Queue binding, and secrets references
    - _Requirements: 10.1, 10.5, 12.4_

  - [ ]* 6.8 Write unit tests for Admin Dashboard
    - Test: authentication success/failure, retry button action, bulk translate action, stats response format
    - _Requirements: 10.2, 10.4, 10.5, 12.4_

- [ ] 7. Implement Astro Static Sites (Polish + English)
  - [ ] 7.1 Create Polish Astro site (zyciezbolem.pl)
    - Initialize Astro project in `sites/pl/` with content collection reading from `/content/pl/`
    - Configure `astro.config.mjs` with `site: 'https://zyciezbolem.pl'` and sitemap integration
    - Create article page template with: `<html lang="pl">`, canonical URL, Schema.org Article markup
    - _Requirements: 1.1, 1.2, 1.3, 1.5, 9.5, 9.6_

  - [ ] 7.2 Create English Astro site (myneuralgia.com)
    - Initialize Astro project in `sites/en/` with content collection reading from `/content/en/`
    - Configure `astro.config.mjs` with `site: 'https://myneuralgia.com'` and sitemap integration
    - Create article page template with: `<html lang="en">`, canonical URL, Schema.org Article markup
    - _Requirements: 1.1, 1.2, 1.3, 1.5, 9.5, 9.6_

  - [ ] 7.3 Implement hreflang cross-referencing logic
    - Create shared Astro component/utility that reads sibling language articles by matching `source_ref` frontmatter
    - Generate `<link rel="alternate" hreflang="xx" href="...">` elements in page `<head>` for all published sibling translations
    - Include both directions: Polish articles link to English, English articles link to Polish
    - _Requirements: 1.4, 9.4_

  - [ ]* 7.4 Write property tests for hreflang and sitemap (Properties 1, 2, 3)
    - **Property 1: Domain Isolation (Sitemap)**
    - **Property 2: Hreflang Completeness**
    - **Property 3: Canonical Self-Reference**
    - Generate random article sets, verify: sitemap contains only same-domain URLs, hreflang includes all sibling translations, canonical equals self URL
    - **Validates: Requirements 1.2, 1.4, 1.5, 9.4**

  - [ ] 7.5 Configure Cloudflare Pages projects
    - Create Pages project configuration for each domain with build commands pointing to respective Astro sites
    - Configure custom domains: `zyciezbolem.pl` → Polish Pages project, `myneuralgia.com` → English Pages project
    - _Requirements: 1.1, 1.7, 13.3_

- [ ] 8. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 9. Implement Article Import Script
  - [ ] 9.1 Implement import script
    - Create `scripts/import.ts` that: lists all `.md` files in `/content/pl/` via GitHub API, parses YAML frontmatter, generates slug from filename or title, inserts `article_group` and source `articles` record in D1, creates `Not_Started` translation records for each target language
    - Make idempotent: check existing records before insert (no duplicates)
    - Log results: imported count, skipped count, errors with filenames
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6_

  - [ ]* 9.2 Write property tests for article group integrity (Property 4)
    - **Property 4: Article Group Integrity**
    - Generate random sequences of import operations, verify: exactly one source per group, at most one translation per language per group
    - **Validates: Requirements 2.3, 2.4**

  - [ ]* 9.3 Write unit tests for import script
    - Test: file with valid frontmatter, file with missing fields (error logged, continue), duplicate import (idempotent), slug generation from filename
    - _Requirements: 11.2, 11.4, 11.5, 11.6_

- [ ] 10. Deployment and wiring
  - [ ] 10.1 Create Cloudflare D1 database and run migrations
    - Write deployment script or instructions using `wrangler d1 create` and `wrangler d1 execute` to create the database and apply the schema
    - Seed the `settings` table with default values (AI model, target languages)
    - _Requirements: 2.1, 5.5, 13.4_

  - [ ] 10.2 Deploy Workers and configure secrets
    - Create deployment script using `wrangler deploy` for each worker (webhook-worker, queue-consumer, admin-dashboard)
    - Configure secrets: `GITHUB_WEBHOOK_SECRET`, `GITHUB_TOKEN`, `OPENAI_API_KEY`, `ADMIN_TOKEN`
    - Create Cloudflare Queue `translation-queue` and bind to workers
    - _Requirements: 12.3, 12.6, 13.1, 13.2_

  - [ ] 10.3 Configure GitHub webhook
    - Document setup for GitHub webhook pointing to the Webhook Worker URL with push events
    - Configure webhook secret matching the Worker's `GITHUB_WEBHOOK_SECRET`
    - _Requirements: 3.1, 12.1_

  - [ ] 10.4 Create GitHub Actions workflow for Astro site builds (if needed beyond Pages auto-build)
    - Verify Cloudflare Pages auto-builds work correctly for both domains on push to content folders
    - Configure build settings: root directory, build command, output directory per Pages project
    - _Requirements: 1.7, 13.3_

- [ ] 11. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation after each major phase
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- All Workers use TypeScript with Vitest + fast-check for testing
- The system is designed to run entirely within Cloudflare free tier limits

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "1.3"] },
    { "id": 2, "tasks": ["1.4", "1.6", "1.8", "1.10", "1.12"] },
    { "id": 3, "tasks": ["1.5", "1.7", "1.9", "1.11", "1.13"] },
    { "id": 4, "tasks": ["3.1", "3.3", "4.1", "6.1"] },
    { "id": 5, "tasks": ["3.2", "3.4", "3.5", "4.2", "4.4", "4.6", "4.7", "6.2", "6.3"] },
    { "id": 6, "tasks": ["3.6", "3.7", "4.3", "4.5", "4.8", "4.9", "6.4", "6.5", "6.6"] },
    { "id": 7, "tasks": ["3.8", "4.10", "4.11", "6.7"] },
    { "id": 8, "tasks": ["6.8", "7.1", "7.2"] },
    { "id": 9, "tasks": ["7.3"] },
    { "id": 10, "tasks": ["7.4", "7.5", "9.1"] },
    { "id": 11, "tasks": ["9.2", "9.3"] },
    { "id": 12, "tasks": ["10.1"] },
    { "id": 13, "tasks": ["10.2", "10.3", "10.4"] }
  ]
}
```
