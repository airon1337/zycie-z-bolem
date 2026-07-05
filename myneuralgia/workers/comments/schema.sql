CREATE TABLE IF NOT EXISTS comments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  article_slug TEXT NOT NULL,
  author_name TEXT DEFAULT 'Anonymous',
  content TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  ip_hash TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS reactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  article_slug TEXT NOT NULL,
  reaction TEXT NOT NULL CHECK(reaction IN ('up', 'down')),
  ip_hash TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(article_slug, ip_hash)
);

CREATE INDEX IF NOT EXISTS idx_comments_slug ON comments(article_slug);
CREATE INDEX IF NOT EXISTS idx_comments_ip ON comments(ip_hash, created_at);
CREATE INDEX IF NOT EXISTS idx_reactions_slug ON reactions(article_slug);
