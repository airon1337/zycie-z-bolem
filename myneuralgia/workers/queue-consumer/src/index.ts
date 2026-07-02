/**
 * Queue Consumer Worker — processes translation jobs.
 * Fetches Polish article from GitHub, translates via OpenAI, pushes English .md to myneuralgia repo.
 */

interface Env {
  DB: D1Database;
  OPENAI_API_KEY: string;
  GITHUB_TOKEN: string;
  TARGET_REPO: string;
  TARGET_FOLDER: string;
  AI_MODEL: string;
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
  async queue(batch: MessageBatch<TranslationJob>, env: Env): Promise<void> {
    for (const message of batch.messages) {
      const job = message.body;
      const startTime = Date.now();

      try {
        // 1. Update status to in_progress
        await env.DB.prepare(
          `UPDATE translations SET status = 'in_progress', updated_at = datetime('now')
           WHERE article_group_id = ? AND language_code = ?`
        ).bind(job.articleGroupId, job.targetLanguage).run();

        // 2. Fetch source article from GitHub
        const sourceContent = await fetchFileFromGitHub(job.sourceRepo, job.sourceFilePath, env.GITHUB_TOKEN);

        // 3. Get translation prompt from settings
        const promptRow = await env.DB.prepare(
          `SELECT value FROM settings WHERE key = 'translation_prompt'`
        ).first<{ value: string }>();

        const systemPrompt = promptRow?.value || DEFAULT_TRANSLATION_PROMPT;
        const model = env.AI_MODEL || 'gpt-4o-mini';

        // 4. Call OpenAI for translation
        const translationResult = await translateWithOpenAI(
          sourceContent,
          systemPrompt,
          model,
          job.targetLanguage,
          env.OPENAI_API_KEY
        );

        // 5. Build translated markdown file
        const translatedMd = buildTranslatedMarkdown(
          translationResult,
          job.sourceFilePath,
          model
        );

        // 6. Push to target repo
        const targetPath = `${env.TARGET_FOLDER}/${translationResult.slug}.md`;
        await pushFileToGitHub(
          env.TARGET_REPO,
          targetPath,
          translatedMd,
          `Add translated article: ${translationResult.title}`,
          env.GITHUB_TOKEN
        );

        // 7. Update D1 — status = draft
        const executionTime = Date.now() - startTime;
        await env.DB.prepare(
          `UPDATE translations
           SET status = 'draft', slug = ?, title = ?, translation_origin = 'ai',
               file_path = ?, updated_at = datetime('now')
           WHERE article_group_id = ? AND language_code = ?`
        ).bind(
          translationResult.slug,
          translationResult.title,
          targetPath,
          job.articleGroupId,
          job.targetLanguage
        ).run();

        // 8. Log translation history
        await env.DB.prepare(
          `INSERT INTO translation_history
           (id, article_group_id, language_code, ai_provider, ai_model, input_tokens, output_tokens,
            estimated_cost_usd, execution_time_ms, status, origin, created_at)
           VALUES (?, ?, ?, 'openai', ?, ?, ?, ?, ?, 'success', 'ai', datetime('now'))`
        ).bind(
          crypto.randomUUID(),
          job.articleGroupId,
          job.targetLanguage,
          model,
          translationResult.inputTokens,
          translationResult.outputTokens,
          translationResult.estimatedCost,
          executionTime
        ).run();

        message.ack();
      } catch (error: any) {
        const executionTime = Date.now() - startTime;
        const errorMsg = error.message || 'Unknown error';

        // Log the failed attempt
        await env.DB.prepare(
          `INSERT INTO translation_history
           (id, article_group_id, language_code, ai_provider, ai_model, input_tokens, output_tokens,
            estimated_cost_usd, execution_time_ms, status, error_message, origin, created_at)
           VALUES (?, ?, ?, 'openai', ?, 0, 0, 0, ?, 'failed', ?, 'ai', datetime('now'))`
        ).bind(
          crypto.randomUUID(),
          job.articleGroupId,
          job.targetLanguage,
          env.AI_MODEL || 'gpt-4o-mini',
          executionTime,
          errorMsg
        ).run();

        // Increment retry count
        await env.DB.prepare(
          `UPDATE translations SET retry_count = retry_count + 1, error_message = ?, last_attempt_at = datetime('now'), updated_at = datetime('now')
           WHERE article_group_id = ? AND language_code = ?`
        ).bind(errorMsg, job.articleGroupId, job.targetLanguage).run();

        // Check if this is a permanent error (don't retry)
        if (isPermanentError(error)) {
          await env.DB.prepare(
            `UPDATE translations SET status = 'failed', updated_at = datetime('now')
             WHERE article_group_id = ? AND language_code = ?`
          ).bind(job.articleGroupId, job.targetLanguage).run();
          message.ack(); // Stop retrying
        } else {
          message.retry(); // Transient error — let Queue retry with backoff
        }
      }
    }
  },
};

// --- OpenAI Translation ---

interface TranslationResultData {
  title: string;
  slug: string;
  metaTitle: string;
  metaDescription: string;
  content: string;
  tags: string[];
  inputTokens: number;
  outputTokens: number;
  estimatedCost: number;
}

async function translateWithOpenAI(
  sourceContent: string,
  systemPrompt: string,
  model: string,
  targetLang: string,
  apiKey: string
): Promise<TranslationResultData> {
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: 'system', content: systemPrompt },
        {
          role: 'user',
          content: `Translate the following Polish article to English (target: ${targetLang}). Return JSON with fields: title, slug, metaTitle, metaDescription, content (markdown body), tags (array of English tags).\n\n---\n\n${sourceContent}`,
        },
      ],
      response_format: { type: 'json_object' },
      temperature: 0.3,
    }),
  });

  if (!response.ok) {
    const status = response.status;
    const text = await response.text();
    const err = new Error(`OpenAI API error: ${status} - ${text}`);
    (err as any).status = status;
    throw err;
  }

  const data = await response.json() as any;
  const usage = data.usage;
  const content = data.choices[0].message.content;
  const parsed = JSON.parse(content);

  // Estimate cost (gpt-4o-mini pricing as of 2024)
  const inputCost = (usage.prompt_tokens / 1_000_000) * 0.15;
  const outputCost = (usage.completion_tokens / 1_000_000) * 0.60;

  return {
    title: parsed.title || 'Untitled',
    slug: slugify(parsed.slug || parsed.title || 'untitled'),
    metaTitle: parsed.metaTitle || parsed.title || '',
    metaDescription: parsed.metaDescription || '',
    content: parsed.content || '',
    tags: parsed.tags || [],
    inputTokens: usage.prompt_tokens,
    outputTokens: usage.completion_tokens,
    estimatedCost: Math.round((inputCost + outputCost) * 1000000) / 1000000,
  };
}

function buildTranslatedMarkdown(result: TranslationResultData, sourceRef: string, model: string): string {
  const now = new Date().toISOString().slice(0, 10);
  const frontmatter = [
    '---',
    `title: "${result.title.replace(/"/g, '\\"')}"`,
    `slug: "${result.slug}"`,
    `date: "${now}"`,
    `status: draft`,
    `meta_title: "${result.metaTitle.replace(/"/g, '\\"')}"`,
    `meta_description: "${result.metaDescription.replace(/"/g, '\\"')}"`,
    `tags: [${result.tags.map(t => `"${t}"`).join(', ')}]`,
    `source_ref: "${sourceRef}"`,
    `translated_at: "${now}"`,
    `translated_by: "openai/${model}"`,
    `translation_origin: ai`,
    '---',
    '',
  ].join('\n');

  return frontmatter + result.content;
}

// --- GitHub Helpers ---

async function fetchFileFromGitHub(repo: string, path: string, token: string): Promise<string> {
  const url = `https://api.github.com/repos/${repo}/contents/${path}`;
  const res = await fetch(url, {
    headers: {
      'Authorization': `Bearer ${token}`,
      'Accept': 'application/vnd.github.v3.raw',
      'User-Agent': 'myneuralgia-worker',
    },
  });
  if (!res.ok) throw new Error(`GitHub fetch failed: ${res.status} for ${path}`);
  return await res.text();
}

async function pushFileToGitHub(
  repo: string,
  path: string,
  content: string,
  commitMessage: string,
  token: string
): Promise<void> {
  // Check if file exists (to get SHA for update)
  const checkUrl = `https://api.github.com/repos/${repo}/contents/${path}`;
  let sha: string | undefined;

  const checkRes = await fetch(checkUrl, {
    headers: {
      'Authorization': `Bearer ${token}`,
      'User-Agent': 'myneuralgia-worker',
    },
  });
  if (checkRes.ok) {
    const existing = await checkRes.json() as any;
    sha = existing.sha;
  }

  // Create or update file
  const body: any = {
    message: commitMessage,
    content: btoa(unescape(encodeURIComponent(content))), // UTF-8 → base64
    branch: 'main',
  };
  if (sha) body.sha = sha;

  const putRes = await fetch(checkUrl, {
    method: 'PUT',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
      'User-Agent': 'myneuralgia-worker',
    },
    body: JSON.stringify(body),
  });

  if (!putRes.ok) {
    const text = await putRes.text();
    throw new Error(`GitHub push failed: ${putRes.status} - ${text}`);
  }
}

// --- Utilities ---

function slugify(text: string): string {
  return text
    .toLowerCase()
    .replace(/[ąà]/g, 'a').replace(/[ćč]/g, 'c').replace(/[ęè]/g, 'e')
    .replace(/[łl]/g, 'l').replace(/[ńñ]/g, 'n').replace(/[óò]/g, 'o')
    .replace(/[śš]/g, 's').replace(/[źżž]/g, 'z').replace(/[ü]/g, 'u')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80);
}

function isPermanentError(error: any): boolean {
  const status = error.status || error.statusCode;
  if (!status) return false;
  // 4xx errors (except 429 rate limit) are permanent
  if (status >= 400 && status < 500 && status !== 429) return true;
  return false;
}

const DEFAULT_TRANSLATION_PROMPT = `You are a professional medical content translator specializing in neurology and chronic pain.

TASK: Translate the Polish article about trigeminal neuralgia into natural, fluent English.

RULES:
- This is LOCALIZATION, not literal translation. Adapt the text for an English-speaking patient audience.
- Preserve the warm, empathetic, first-person tone of the author (Natalia, a patient living with pain since 2014).
- Keep all medical terminology accurate (use standard English medical terms).
- Preserve ALL markdown formatting: headings, bold, lists, links, blockquotes.
- Generate an SEO-optimized English slug (short, keyword-rich, no Polish characters).
- Generate an English meta_title (max 60 chars) and meta_description (max 155 chars).
- Translate tags to their English equivalents.
- Do NOT add content that isn't in the original.
- Keep the disclaimer at the end.

RESPOND WITH VALID JSON containing: title, slug, metaTitle, metaDescription, content, tags`;
