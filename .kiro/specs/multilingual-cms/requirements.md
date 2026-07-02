# Requirements Document

## Introduction

A multilingual blog system for Trigeminal Neuralgia content, built entirely on Cloudflare's free-tier serverless platform. The system translates Polish articles from zyciezbolem.pl into English (myneuralgia.com) and future languages using AI, with zero ongoing maintenance after deployment. Content is authored in Pages CMS (web UI), stored as markdown in GitHub, translated automatically via Cloudflare Workers + Queues + OpenAI API, and published as static Astro sites on Cloudflare Pages. The admin (a non-technical user) interacts only through Pages CMS and a simple admin dashboard — no terminal, no CLI, no DevOps.

## Glossary

- **Pages_CMS**: The existing web-based content editor (app.pagescms.org) that the admin uses to create and edit markdown articles stored in GitHub
- **Source_Article**: The original Polish markdown article from which all translations are derived
- **Translation**: A localized version of a Source_Article for a target language, stored as a markdown file in the GitHub repository
- **Translation_Worker**: A Cloudflare Worker that receives GitHub webhooks and orchestrates the translation pipeline
- **Translation_Queue**: A Cloudflare Queue that holds pending translation jobs with built-in retry and dead-letter support
- **Queue_Consumer**: A Cloudflare Worker that processes messages from the Translation_Queue by calling the AI_Provider
- **AI_Provider**: An external AI translation service accessed via API (currently OpenAI; architecture supports Gemini, Claude in future)
- **D1_Database**: A Cloudflare D1 serverless SQLite database storing article metadata, translation status, history, and cost tracking
- **Article_Group**: A Source_Article and all its linked Translations across languages, tracked in D1_Database
- **Domain_Site**: A language-specific Astro static site deployed to its own Cloudflare Pages project (e.g., zyciezbolem.pl, myneuralgia.com)
- **Admin_Dashboard**: A simple Cloudflare Worker-served web page for viewing translation status, queue state, costs, and triggering retries
- **Webhook_Worker**: A Cloudflare Worker endpoint that receives GitHub webhook events and validates their signatures
- **Draft**: A translated markdown file pushed to the GitHub repository that has not yet been marked as published by the admin in Pages_CMS
- **Retry_Policy**: The automatic retry mechanism provided by Cloudflare Queues with configurable maximum attempts before marking a translation as "Failed"

## Requirements

### Requirement 1: Multi-Domain Static Site Management

**User Story:** As an admin, I want each language version hosted on its own domain as a separate static site, so that each blog has independent SEO, branding, and configuration without any server maintenance.

#### Acceptance Criteria

1. THE system SHALL deploy each Domain_Site as a separate Cloudflare Pages project, each serving a distinct custom domain
2. WHEN a Domain_Site is built, THE Astro build process SHALL generate a separate sitemap.xml containing only articles published on that Domain_Site
3. WHEN a Domain_Site is built, THE Astro build process SHALL generate a domain-specific robots.txt file
4. WHEN an article has translations available in other languages, THE Astro build process SHALL include hreflang link elements pointing to all alternate language versions across Domain_Sites
5. THE Astro build process SHALL include a canonical URL on each article page pointing to the article's own URL on its Domain_Site
6. THE system SHALL store each language's articles in a separate folder within the same GitHub repository (e.g., /content/pl/, /content/en/)
7. WHEN a markdown file is added or updated in a language folder, THE connected Cloudflare Pages project SHALL automatically rebuild and deploy the corresponding Domain_Site

### Requirement 2: Article Source and Translation Linking

**User Story:** As an admin, I want every translation linked to its Polish source article in a database, so that I can track translation coverage and maintain content relationships across languages.

#### Acceptance Criteria

1. THE D1_Database SHALL store each article as part of an Article_Group consisting of one Source_Article and zero or more linked Translations
2. WHEN a Source_Article is detected via webhook, THE Translation_Worker SHALL create an Article_Group record in D1_Database with a unique group identifier
3. THE D1_Database SHALL enforce that each Article_Group has exactly one Source_Article in Polish
4. THE D1_Database SHALL allow each Article_Group to have at most one Translation per target language
5. WHEN a Translation is completed (via AI or manually), THE system SHALL update D1_Database to link the Translation to its Source_Article within the same Article_Group
6. THE D1_Database SHALL track translation status for each target language per Article_Group with values: Not_Started, Queued, In_Progress, Draft, Published, Failed

### Requirement 3: Automatic Translation Trigger via GitHub Webhook

**User Story:** As an admin, I want translations to start automatically when I publish a new article in Pages CMS, so that I do not need to manually trigger any technical process.

#### Acceptance Criteria

1. WHEN a markdown file is pushed to the Polish articles folder in the GitHub repository, THE Webhook_Worker SHALL receive the GitHub webhook event
2. WHEN the Webhook_Worker receives a push event, THE Webhook_Worker SHALL parse the commit payload to identify new or modified markdown files in the Polish articles folder
3. WHEN a new Source_Article is detected, THE Webhook_Worker SHALL create an Article_Group record in D1_Database and enqueue a translation job in the Translation_Queue for each configured target language
4. WHEN an existing Source_Article is modified, THE Webhook_Worker SHALL enqueue a re-translation job in the Translation_Queue for each target language that has an existing Translation
5. THE Webhook_Worker SHALL respond to GitHub within 5 seconds to prevent webhook timeout, deferring all heavy processing to the Translation_Queue
6. IF the webhook payload contains no changes to the Polish articles folder, THEN THE Webhook_Worker SHALL acknowledge the event and take no further action

### Requirement 4: AI Translation via Cloudflare Queue

**User Story:** As an admin, I want translations processed reliably in the background without blocking my workflow, so that articles are translated even during high load or temporary API failures.

#### Acceptance Criteria

1. WHEN a translation job is dequeued, THE Queue_Consumer SHALL fetch the Source_Article markdown content from the GitHub repository via API
2. THE Queue_Consumer SHALL send the Source_Article content to the configured AI_Provider with a system prompt instructing professional localization
3. THE AI_Provider request SHALL instruct preservation of: markdown formatting, headings hierarchy, lists, tables, blockquotes, image references, YAML frontmatter structure, internal link patterns, and FAQ sections
4. WHEN the AI_Provider returns a successful translation, THE Queue_Consumer SHALL push the translated markdown file to the appropriate language folder in the GitHub repository
5. WHEN the translated file is pushed to GitHub, THE Queue_Consumer SHALL update the D1_Database translation status to "Draft"
6. THE Queue_Consumer SHALL generate a localized URL slug for each Translation based on the translated title, stored in the markdown frontmatter
7. THE translated markdown file SHALL include frontmatter fields for: translated title, meta description, slug, source article reference, translation date, and AI model used

### Requirement 5: AI Provider Abstraction

**User Story:** As an admin, I want to switch AI translation providers or models in the future without rebuilding the system, so that I can take advantage of better or cheaper models as they become available.

#### Acceptance Criteria

1. THE Queue_Consumer SHALL implement an AI_Provider interface that separates translation logic from any specific AI service API
2. THE system SHALL support OpenAI API (GPT models) as the initial AI_Provider implementation
3. THE Admin_Dashboard SHALL display the currently active AI_Provider and model name
4. WHEN a new AI_Provider is added, THE system SHALL require only implementation of the provider interface without changes to webhook, queue, or database logic
5. THE system SHALL store AI_Provider configuration (model name, API endpoint pattern) in Cloudflare Worker environment variables or D1_Database settings table

### Requirement 6: Translation Error Handling and Retry

**User Story:** As an admin, I want the system to automatically retry failed translations and show me clear failure information, so that temporary API issues do not require my intervention.

#### Acceptance Criteria

1. IF the AI_Provider returns a timeout error, HTTP 5xx error, or rate limit response (HTTP 429), THEN THE Translation_Queue SHALL retain the message for automatic retry using Cloudflare Queues built-in retry mechanism
2. THE Translation_Queue SHALL use exponential backoff between retry attempts as configured in the Cloudflare Queue settings
3. IF a translation job fails after the configured maximum number of retry attempts, THEN THE Queue_Consumer SHALL update D1_Database translation status to "Failed" and store the final error message
4. THE Admin_Dashboard SHALL display failed translations with error messages, failure timestamps, and a manual retry button
5. WHEN the admin clicks the retry button, THE Admin_Dashboard SHALL enqueue a new translation job in the Translation_Queue for the failed article
6. THE Queue_Consumer SHALL log each attempt (success or failure) with timestamp, error type, and attempt number in the translation_history table of D1_Database

### Requirement 7: Translation History and Cost Tracking

**User Story:** As an admin, I want to see the full translation history for each article including cost data, so that I can monitor my OpenAI spending and troubleshoot any issues.

#### Acceptance Criteria

1. WHEN a translation job is executed, THE Queue_Consumer SHALL record in D1_Database: AI model used, input token count, output token count, estimated cost (USD), execution start timestamp, execution duration in milliseconds, final status, and error message if applicable
2. THE Admin_Dashboard SHALL display the translation history for each article showing all recorded fields
3. THE Admin_Dashboard SHALL provide a "Re-translate" button for each article that enqueues a new translation job
4. WHEN an article is re-translated, THE system SHALL push the new translated file to GitHub (overwriting the previous draft) while preserving all previous history entries in D1_Database
5. THE Admin_Dashboard SHALL display aggregate statistics: total tokens used, total estimated cost, translations completed, translations failed, and average cost per article

### Requirement 8: Manual Translation Mode

**User Story:** As an admin, I want to paste a manually translated article directly through Pages CMS, so that I can use professional human translations or make corrections without the AI pipeline.

#### Acceptance Criteria

1. THE system SHALL detect when a translated markdown file is pushed directly to a target language folder (not by the Queue_Consumer's GitHub token) and treat it as a manual translation
2. WHEN a manual translation is detected, THE Webhook_Worker SHALL update D1_Database to link the Translation to the corresponding Source_Article and mark the origin as "Manual"
3. THE system SHALL match a manual translation to its Source_Article using a source_ref field in the markdown frontmatter
4. WHEN a manual translation is recorded, THE system SHALL create a translation_history entry in D1_Database with origin "Manual" and timestamp
5. IF a manual translation file lacks a source_ref frontmatter field, THEN THE system SHALL log a warning in D1_Database and mark the article as "Unlinked" for admin review

### Requirement 9: Per-Language SEO Configuration

**User Story:** As an admin, I want each language site to have fully independent SEO settings, so that each domain ranks well in its target geographic and language market.

#### Acceptance Criteria

1. THE translated markdown frontmatter SHALL contain independent meta title, meta description, and URL slug for each Translation
2. WHEN a Translation is created by AI, THE Queue_Consumer SHALL populate meta title, meta description, and slug in the translated markdown frontmatter from the AI_Provider response
3. THE admin SHALL be able to edit meta title, meta description, and slug for any Translation by editing the markdown file in Pages_CMS
4. THE Astro build process SHALL output hreflang link elements on each published article page referencing all alternate language versions using data from frontmatter source references
5. THE Astro build process SHALL generate structured data (Schema.org Article markup) for each published article with language-appropriate values
6. THE Astro build process SHALL set the html lang attribute to the correct language code for each Domain_Site

### Requirement 10: Admin Dashboard

**User Story:** As an admin, I want a simple web dashboard to monitor translation status, queue health, and costs, so that I can see at a glance whether everything is working without using any technical tools.

#### Acceptance Criteria

1. THE Admin_Dashboard SHALL be served by a Cloudflare Worker and accessible via a dedicated URL
2. THE Admin_Dashboard SHALL display: total articles per language, translation coverage percentage per language, current queue length, recent failures (last 10), and total estimated API cost
3. THE Admin_Dashboard SHALL display the Translation_Queue contents with status, retry count, and time in queue for each pending job
4. THE Admin_Dashboard SHALL provide retry buttons for failed translations and a "Translate All Missing" bulk action button
5. THE Admin_Dashboard SHALL require authentication (password) before granting access
6. THE Admin_Dashboard SHALL load all data from D1_Database with response time under 2 seconds for the main dashboard view

### Requirement 11: Content Import of Existing Articles

**User Story:** As an admin, I want to import my existing 128 Polish markdown articles into the system's tracking database, so that I can immediately begin translating them without recreating any content.

#### Acceptance Criteria

1. THE system SHALL provide a one-time import script that reads all existing markdown files from the Polish articles folder in the GitHub repository
2. WHEN importing an article, THE import script SHALL parse YAML frontmatter and create an Article_Group record in D1_Database
3. WHEN importing an article, THE import script SHALL create a translations record with status "Not_Started" for each configured target language
4. THE import script SHALL generate a URL slug from the article filename or frontmatter title for each imported Source_Article
5. IF an import encounters a parsing error for a specific file, THEN THE import script SHALL log the error with the filename and continue importing remaining files
6. THE import script SHALL be idempotent: running it again does not create duplicate Article_Group records

### Requirement 12: Security

**User Story:** As an admin, I want the system secured against unauthorized access and webhook spoofing, so that only legitimate events trigger translations and only I can access the dashboard.

#### Acceptance Criteria

1. WHEN a GitHub webhook event is received, THE Webhook_Worker SHALL validate the webhook signature using the configured GitHub webhook secret before processing the payload
2. IF the webhook signature validation fails, THEN THE Webhook_Worker SHALL reject the request with HTTP 401 and take no action
3. THE system SHALL store all API keys (OpenAI, GitHub token) in Cloudflare Worker Secrets (encrypted environment variables), not in code or D1_Database
4. THE Admin_Dashboard SHALL require authentication using a password stored in Cloudflare Worker Secrets
5. THE Admin_Dashboard SHALL serve all pages over HTTPS (enforced by Cloudflare by default)
6. THE Queue_Consumer SHALL use a dedicated GitHub token with minimal permissions (only content write access to the repository) for pushing translated files

### Requirement 13: Zero-Maintenance Operation

**User Story:** As an admin, I want the entire system to run indefinitely without any technical intervention from me, so that I can focus on writing content and reviewing translations.

#### Acceptance Criteria

1. WHEN the Translation_Queue contains pending jobs, THE Queue_Consumer SHALL process them automatically without manual triggering
2. THE Cloudflare Queue SHALL persist all messages durably so that no translation job is lost during Worker cold starts
3. WHEN a translated markdown file is pushed to GitHub, THE Cloudflare Pages project SHALL automatically detect the change and rebuild the Domain_Site without manual intervention
4. THE system SHALL operate entirely within Cloudflare free tier limits: Workers (100,000 requests/day), D1 (5 million rows read/day, 100,000 rows written/day), Queues (1 million operations/month), Pages (500 builds/month)
5. IF a Cloudflare Worker encounters an unhandled error, THEN THE Translation_Queue SHALL retry the job per its Retry_Policy without admin intervention
6. THE system SHALL require no scheduled maintenance, no database migrations after initial deployment, and no manual restarts under normal operation
