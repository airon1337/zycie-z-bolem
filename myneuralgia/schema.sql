-- Cloudflare D1 Schema for MyNeuralgia CMS
-- Run with: wrangler d1 execute myneuralgia-cms --file=./schema.sql

CREATE TABLE IF NOT EXISTS article_groups (
  id TEXT PRIMARY KEY,
  source_file_path TEXT UNIQUE NOT NULL,
  source_title TEXT,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS translations (
  id TEXT PRIMARY KEY,
  article_group_id TEXT NOT NULL REFERENCES article_groups(id),
  language_code TEXT NOT NULL,
  file_path TEXT,
  slug TEXT,
  title TEXT,
  meta_title TEXT,
  meta_description TEXT,
  status TEXT NOT NULL DEFAULT 'not_started',
  translation_origin TEXT,
  error_message TEXT,
  retry_count INTEGER DEFAULT 0,
  last_attempt_at TEXT,
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now')),
  UNIQUE(article_group_id, language_code)
);

CREATE TABLE IF NOT EXISTS translation_history (
  id TEXT PRIMARY KEY,
  article_group_id TEXT NOT NULL REFERENCES article_groups(id),
  language_code TEXT NOT NULL,
  ai_provider TEXT,
  ai_model TEXT,
  input_tokens INTEGER DEFAULT 0,
  output_tokens INTEGER DEFAULT 0,
  estimated_cost_usd REAL DEFAULT 0.0,
  execution_time_ms INTEGER DEFAULT 0,
  status TEXT NOT NULL,
  error_message TEXT,
  origin TEXT DEFAULT 'ai',
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT DEFAULT (datetime('now'))
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_translations_status ON translations(status);
CREATE INDEX IF NOT EXISTS idx_translations_group ON translations(article_group_id);
CREATE INDEX IF NOT EXISTS idx_history_group ON translation_history(article_group_id);
CREATE INDEX IF NOT EXISTS idx_history_created ON translation_history(created_at);

-- Default settings
INSERT OR IGNORE INTO settings (key, value) VALUES ('translation_prompt', 'You are a professional medical content translator specializing in neurology and chronic pain.

TASK: Translate the Polish article about trigeminal neuralgia into natural, fluent English.

RULES:
- This is LOCALIZATION, not literal translation. Adapt the text for an English-speaking patient audience.
- Preserve the warm, empathetic, first-person tone of the author (Natalia, a patient living with pain since 2014).
- Keep all medical terminology accurate (use standard English medical terms).
- Preserve ALL markdown formatting: headings, bold, lists, links, blockquotes.
- Generate an SEO-optimized English slug (short, keyword-rich, no Polish characters).
- Generate an English meta_title (max 60 chars) and meta_description (max 155 chars).
- Translate tags to their English equivalents.
- Do NOT add content that is not in the original.
- Keep the disclaimer at the end.

RESPOND WITH VALID JSON containing: title, slug, metaTitle, metaDescription, content, tags');

INSERT OR IGNORE INTO settings (key, value) VALUES ('active_ai_provider', 'openai');
INSERT OR IGNORE INTO settings (key, value) VALUES ('active_ai_model', 'gpt-4o-mini');
INSERT OR IGNORE INTO settings (key, value) VALUES ('max_retries', '5');
INSERT OR IGNORE INTO settings (key, value) VALUES ('target_languages', 'en');
