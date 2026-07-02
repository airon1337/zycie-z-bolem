-- Multilingual CMS — Cloudflare D1 Schema
-- Single source of truth for translation tracking

-- Domains (language sites)
CREATE TABLE IF NOT EXISTS domains (
  id TEXT PRIMARY KEY,
  hostname TEXT UNIQUE NOT NULL,
  language_code TEXT NOT NULL,
  display_name TEXT NOT NULL,
  content_repo TEXT NOT NULL,
  content_path TEXT NOT NULL,
  settings_json TEXT DEFAULT '{}',
  created_at TEXT DEFAULT (datetime('now'))
);

-- Article groups (one source + many translations)
CREATE TABLE IF NOT EXISTS article_groups (
  id TEXT PRIMARY KEY,
  source_file TEXT UNIQUE NOT NULL,
  source_title TEXT,
  source_slug TEXT,
  created_at TEXT DEFAULT (datetime('now'))
);

-- Translation status per article per language
CREATE TABLE IF NOT EXISTS translations (
  id TEXT PRIMARY KEY,
  article_group_id TEXT NOT NULL REFERENCES article_groups(id),
  target_language TEXT NOT NULL,
  target_domain_id TEXT REFERENCES domains(id),
  file_path TEXT,
  slug TEXT,
  meta_title TEXT,
  meta_description TEXT,
  status TEXT NOT NULL DEFAULT 'not_started',
  origin TEXT DEFAULT 'ai',
  error_message TEXT,
  retry_count INTEGER DEFAULT 0,
  last_attempt_at TEXT,
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now')),
  UNIQUE(article_group_id, target_language)
);

-- Full history of every translation attempt
CREATE TABLE IF NOT EXISTS translation_history (
  id TEXT PRIMARY KEY,
  article_group_id TEXT NOT NULL REFERENCES article_groups(id),
  target_language TEXT NOT NULL,
  ai_provider TEXT,
  ai_model TEXT,
  prompt_version TEXT,
  input_tokens INTEGER,
  output_tokens INTEGER,
  estimated_cost_usd REAL,
  execution_time_ms INTEGER,
  status TEXT NOT NULL,
  error_message TEXT,
  origin TEXT DEFAULT 'ai',
  created_at TEXT DEFAULT (datetime('now'))
);

-- System settings (editable from dashboard)
CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT DEFAULT (datetime('now'))
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_translations_status ON translations(status);
CREATE INDEX IF NOT EXISTS idx_translations_group ON translations(article_group_id);
CREATE INDEX IF NOT EXISTS idx_translations_language ON translations(target_language);
CREATE INDEX IF NOT EXISTS idx_history_group ON translation_history(article_group_id);
CREATE INDEX IF NOT EXISTS idx_history_created ON translation_history(created_at DESC);

-- Initial data
INSERT OR IGNORE INTO domains (id, hostname, language_code, display_name, content_repo, content_path) VALUES
  ('pl', 'zyciezbolem.pl', 'pl', 'Życie z bólem', 'airon1337/zycie-z-bolem', 'artykuly'),
  ('en', 'myneuralgia.com', 'en', 'My Neuralgia', 'airon1337/myneuralgia', 'site/src/content/articles');

INSERT OR IGNORE INTO settings (key, value) VALUES
  ('active_ai_provider', 'openai'),
  ('active_ai_model', 'gpt-4o-mini'),
  ('max_retries', '5'),
  ('target_languages', '["en"]'),
  ('translation_prompt', 'You are a professional medical content localizer specializing in neurology and chronic pain.

Your task: Translate the following Polish article about Trigeminal Neuralgia into natural, fluent English. This is NOT a literal translation — it is a professional localization for English-speaking patients.

RULES:
1. Preserve the author''s personal, empathetic tone (first person, supportive)
2. Adapt cultural references for English-speaking audience
3. Keep all medical terminology accurate (use standard English medical terms)
4. Preserve ALL formatting: headings, lists, bold, links, blockquotes
5. Preserve all source/bibliography links unchanged
6. Generate an SEO-friendly English slug from the translated title
7. Generate a meta title (max 60 chars) and meta description (max 155 chars) optimized for English SEO
8. Keep the disclaimer about content being educational, not medical advice
9. If the article references Polish institutions, add brief context for international readers
10. Maintain the same heading hierarchy (H2, H3)

OUTPUT FORMAT: Return valid markdown with YAML frontmatter containing:
---
title: "Translated title"
slug: "english-slug-here"
meta_title: "SEO title (max 60 chars)"
meta_description: "SEO description (max 155 chars)"
date: "(keep original date)"
source_ref: "(original Polish filename)"
translated_at: "(current date ISO)"
translated_by: "(model name)"
translation_origin: "ai"
status: "draft"
tags: [relevant, english, tags]
---

Then the translated article body in markdown.');
