/**
 * Webhook Worker — receives GitHub push events from the Polish repo,
 * validates signature, detects new/modified articles, enqueues translation jobs.
 */

interface Env {
  DB: D1Database;
  TRANSLATION_QUEUE: Queue;
  GITHUB_WEBHOOK_SECRET: string;
  TARGET_LANGUAGES: string;
  SOURCE_REPO: string;
  SOURCE_FOLDER: string;
}

interface PushEvent {
  ref: string;
  commits: Array<{
    id: string;
    added: string[];
    modified: string[];
    removed: string[];
  }>;
}

interface TranslationJob {
  articleGroupId: string;
  sourceFilePath: string;
  sourceRepo: string;
  targetLanguage: string;
  isRetranslation: boolean;
  triggeredBy: 'webhook' | 'admin' | 'import';
  commitSha: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Only accept POST
    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    // Get raw body for signature verification
    const body = await request.text();

    // Validate GitHub webhook signature
    const signature = request.headers.get('x-hub-signature-256');
    if (!signature) {
      return new Response('Missing signature', { status: 401 });
    }

    const isValid = await verifySignature(body, signature, env.GITHUB_WEBHOOK_SECRET);
    if (!isValid) {
      return new Response('Invalid signature', { status: 401 });
    }

    // Parse event
    const event = request.headers.get('x-github-event');
    if (event === 'ping') {
      return new Response('Pong! Webhook connected successfully.', { status: 200 });
    }
    if (event !== 'push') {
      return new Response('Event ignored', { status: 200 });
    }

    const payload: PushEvent = JSON.parse(body);

    // Only process pushes to main branch
    if (payload.ref !== 'refs/heads/main') {
      return new Response('Branch ignored', { status: 200 });
    }

    // Collect new and modified .md files from the source folder
    const sourceFolder = env.SOURCE_FOLDER;
    const newFiles: string[] = [];
    const modifiedFiles: string[] = [];

    for (const commit of payload.commits) {
      for (const file of commit.added) {
        if (file.startsWith(sourceFolder + '/') && file.endsWith('.md') && file !== `${sourceFolder}/index.md`) {
          if (!newFiles.includes(file)) newFiles.push(file);
        }
      }
      for (const file of commit.modified) {
        if (file.startsWith(sourceFolder + '/') && file.endsWith('.md') && file !== `${sourceFolder}/index.md`) {
          if (!modifiedFiles.includes(file) && !newFiles.includes(file)) modifiedFiles.push(file);
        }
      }
    }

    if (newFiles.length === 0 && modifiedFiles.length === 0) {
      return new Response('No relevant changes', { status: 200 });
    }

    const targetLanguages = env.TARGET_LANGUAGES.split(',').map(l => l.trim());
    const commitSha = payload.commits[payload.commits.length - 1]?.id || 'unknown';
    let enqueued = 0;

    // Process NEW articles
    for (const file of newFiles) {
      const slug = fileToSlug(file, sourceFolder);
      const groupId = crypto.randomUUID();

      // Create article group in D1
      await env.DB.prepare(
        `INSERT OR IGNORE INTO article_groups (id, source_file_path, source_title, created_at)
         VALUES (?, ?, ?, datetime('now'))`
      ).bind(groupId, file, slug).run();

      // Get the actual group ID (in case it already existed)
      const existing = await env.DB.prepare(
        `SELECT id FROM article_groups WHERE source_file_path = ?`
      ).bind(file).first<{ id: string }>();

      const actualGroupId = existing?.id || groupId;

      // Enqueue translation for each target language
      for (const lang of targetLanguages) {
        // Create translations record
        await env.DB.prepare(
          `INSERT OR IGNORE INTO translations (id, article_group_id, language_code, slug, title, status, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, 'queued', datetime('now'), datetime('now'))`
        ).bind(crypto.randomUUID(), actualGroupId, lang, slug, slug).run();

        // Enqueue job
        const job: TranslationJob = {
          articleGroupId: actualGroupId,
          sourceFilePath: file,
          sourceRepo: env.SOURCE_REPO,
          targetLanguage: lang,
          isRetranslation: false,
          triggeredBy: 'webhook',
          commitSha,
        };
        await env.TRANSLATION_QUEUE.send(job);
        enqueued++;
      }
    }

    // Process MODIFIED articles (re-translate existing)
    for (const file of modifiedFiles) {
      const existing = await env.DB.prepare(
        `SELECT id FROM article_groups WHERE source_file_path = ?`
      ).bind(file).first<{ id: string }>();

      if (!existing) continue; // Not tracked, skip

      for (const lang of targetLanguages) {
        // Only re-translate if a translation already exists
        const translation = await env.DB.prepare(
          `SELECT id FROM translations WHERE article_group_id = ? AND language_code = ?`
        ).bind(existing.id, lang).first();

        if (!translation) continue;

        // Update status
        await env.DB.prepare(
          `UPDATE translations SET status = 'queued', updated_at = datetime('now') WHERE article_group_id = ? AND language_code = ?`
        ).bind(existing.id, lang).run();

        const job: TranslationJob = {
          articleGroupId: existing.id,
          sourceFilePath: file,
          sourceRepo: env.SOURCE_REPO,
          targetLanguage: lang,
          isRetranslation: true,
          triggeredBy: 'webhook',
          commitSha,
        };
        await env.TRANSLATION_QUEUE.send(job);
        enqueued++;
      }
    }

    return new Response(JSON.stringify({
      ok: true,
      newFiles: newFiles.length,
      modifiedFiles: modifiedFiles.length,
      enqueued,
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  },
};

// --- Helpers ---

async function verifySignature(payload: string, signature: string, secret: string): Promise<boolean> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const sig = await crypto.subtle.sign('HMAC', key, encoder.encode(payload));
  const hashHex = 'sha256=' + Array.from(new Uint8Array(sig)).map(b => b.toString(16).padStart(2, '0')).join('');
  return hashHex === signature;
}

function fileToSlug(filePath: string, sourceFolder: string): string {
  const filename = filePath.replace(sourceFolder + '/', '').replace('.md', '');
  return filename;
}
