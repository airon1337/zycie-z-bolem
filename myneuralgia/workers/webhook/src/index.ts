/**
 * Webhook Worker
 * Receives GitHub push events from the Polish repo (zycie-z-bolem).
 * When a new/modified article .md is detected, creates an article_group
 * in D1 and enqueues a translation job.
 */

interface Env {
  DB: D1Database;
  TRANSLATION_QUEUE: Queue;
  GITHUB_WEBHOOK_SECRET: string;
  SOURCE_CONTENT_PATH: string;
  SOURCE_REPO: string;
}

interface PushEvent {
  ref: string;
  commits: Array<{
    added: string[];
    modified: string[];
    removed: string[];
    message: string;
    author: { username: string };
  }>;
}

interface TranslationJob {
  articleGroupId: string;
  sourceFile: string;
  sourceTitle: string;
  targetLanguage: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    // Validate GitHub webhook signature
    const signature = request.headers.get("X-Hub-Signature-256");
    if (!signature) {
      return new Response("Missing signature", { status: 401 });
    }

    const body = await request.text();
    const isValid = await verifySignature(body, signature, env.GITHUB_WEBHOOK_SECRET);
    if (!isValid) {
      return new Response("Invalid signature", { status: 401 });
    }

    // Parse event
    const event = request.headers.get("X-GitHub-Event");
    if (event !== "push") {
      return new Response("OK - ignored event: " + event, { status: 200 });
    }

    const payload: PushEvent = JSON.parse(body);

    // Only process pushes to main branch
    if (payload.ref !== "refs/heads/main") {
      return new Response("OK - ignored branch", { status: 200 });
    }

    // Collect new/modified .md files in the articles folder
    const contentPath = env.SOURCE_CONTENT_PATH;
    const newFiles: string[] = [];
    const modifiedFiles: string[] = [];

    for (const commit of payload.commits) {
      for (const file of commit.added) {
        if (isArticleFile(file, contentPath)) {
          newFiles.push(file);
        }
      }
      for (const file of commit.modified) {
        if (isArticleFile(file, contentPath)) {
          modifiedFiles.push(file);
        }
      }
    }

    if (newFiles.length === 0 && modifiedFiles.length === 0) {
      return new Response("OK - no article changes", { status: 200 });
    }

    // Get target languages from settings
    const targetLangs = await getTargetLanguages(env.DB);

    // Process new articles
    for (const file of newFiles) {
      const filename = file.split("/").pop() || file;
      const title = extractTitleFromFilename(filename);
      const groupId = generateId();

      // Create article group (idempotent — skip if exists)
      const existing = await env.DB.prepare(
        "SELECT id FROM article_groups WHERE source_file = ?"
      ).bind(filename).first();

      if (existing) continue;

      await env.DB.prepare(
        "INSERT INTO article_groups (id, source_file, source_title, source_slug) VALUES (?, ?, ?, ?)"
      ).bind(groupId, filename, title, filenameToSlug(filename)).run();

      // Enqueue translation for each target language
      for (const lang of targetLangs) {
        const translationId = generateId();

        // Create translation record
        await env.DB.prepare(
          "INSERT OR IGNORE INTO translations (id, article_group_id, target_language, target_domain_id, status) VALUES (?, ?, ?, ?, 'queued')"
        ).bind(translationId, groupId, lang, lang).run();

        // Enqueue job
        const job: TranslationJob = {
          articleGroupId: groupId,
          sourceFile: filename,
          sourceTitle: title,
          targetLanguage: lang,
        };
        await env.TRANSLATION_QUEUE.send(job);
      }
    }

    // Process modified articles (re-translate)
    for (const file of modifiedFiles) {
      const filename = file.split("/").pop() || file;

      const group = await env.DB.prepare(
        "SELECT id, source_title FROM article_groups WHERE source_file = ?"
      ).bind(filename).first<{ id: string; source_title: string }>();

      if (!group) continue;

      for (const lang of targetLangs) {
        // Only re-translate if a translation already exists (don't create new ones on edit)
        const existing = await env.DB.prepare(
          "SELECT id, status FROM translations WHERE article_group_id = ? AND target_language = ?"
        ).bind(group.id, lang).first<{ id: string; status: string }>();

        if (!existing) continue;

        // Don't re-queue if already queued or in progress
        if (existing.status === "queued" || existing.status === "in_progress") continue;

        // Update status to queued
        await env.DB.prepare(
          "UPDATE translations SET status = 'queued', updated_at = datetime('now') WHERE id = ?"
        ).bind(existing.id).run();

        const job: TranslationJob = {
          articleGroupId: group.id,
          sourceFile: filename,
          sourceTitle: group.source_title || filename,
          targetLanguage: lang,
        };
        await env.TRANSLATION_QUEUE.send(job);
      }
    }

    const total = newFiles.length + modifiedFiles.length;
    return new Response(`OK - processed ${newFiles.length} new, ${modifiedFiles.length} modified articles`, {
      status: 200,
    });
  },
};

// --- Helper functions ---

function isArticleFile(path: string, contentPath: string): boolean {
  return path.startsWith(contentPath + "/") && path.endsWith(".md") && !path.endsWith("index.md");
}

function extractTitleFromFilename(filename: string): string {
  // Remove .md extension and numeric prefix
  let name = filename.replace(/\.md$/, "");
  name = name.replace(/^\d+-/, "");
  // Convert hyphens to spaces, capitalize
  name = name.replace(/-/g, " ");
  return name.charAt(0).toUpperCase() + name.slice(1);
}

function filenameToSlug(filename: string): string {
  return filename.replace(/\.md$/, "");
}

function generateId(): string {
  return crypto.randomUUID();
}

async function getTargetLanguages(db: D1Database): Promise<string[]> {
  const result = await db.prepare(
    "SELECT value FROM settings WHERE key = 'target_languages'"
  ).first<{ value: string }>();

  if (!result) return ["en"];
  try {
    return JSON.parse(result.value);
  } catch {
    return ["en"];
  }
}

async function verifySignature(
  payload: string,
  signature: string,
  secret: string
): Promise<boolean> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(payload));
  const digest = "sha256=" + arrayBufferToHex(sig);
  return timingSafeEqual(digest, signature);
}

function arrayBufferToHex(buffer: ArrayBuffer): string {
  return Array.from(new Uint8Array(buffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return result === 0;
}
