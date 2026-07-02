/**
 * Translation Queue Consumer Worker
 * Processes translation jobs from Cloudflare Queue:
 * 1. Fetches source article from Polish repo
 * 2. Sends to AI provider for localization
 * 3. Pushes translated .md to English repo
 * 4. Updates D1 with status and history
 */

import { getProvider } from "./ai/providers/index";
import { TranslationRequest } from "./ai/types";
import { fetchFile, pushFile } from "./github";

interface Env {
  DB: D1Database;
  GITHUB_TOKEN: string;
  OPENAI_API_KEY: string;
  SOURCE_REPO: string;
  SOURCE_CONTENT_PATH: string;
  TARGET_REPO: string;
  TARGET_CONTENT_PATH: string;
}

interface TranslationJob {
  articleGroupId: string;
  sourceFile: string;
  sourceTitle: string;
  targetLanguage: string;
}

export default {
  async queue(batch: MessageBatch<TranslationJob>, env: Env): Promise<void> {
    for (const message of batch.messages) {
      const job = message.body;
      const startTime = Date.now();

      try {
        await processTranslation(job, env, startTime);
        message.ack();
      } catch (error) {
        const errorMsg = error instanceof Error ? error.message : "Unknown error";
        console.error(`Translation failed for ${job.sourceFile}: ${errorMsg}`);

        // Log attempt in history
        await logAttempt(env.DB, job, startTime, "failed", errorMsg);

        // Update retry count
        await env.DB.prepare(
          `UPDATE translations 
           SET retry_count = retry_count + 1, 
               error_message = ?, 
               last_attempt_at = datetime('now'),
               updated_at = datetime('now')
           WHERE article_group_id = ? AND target_language = ?`
        ).bind(errorMsg, job.articleGroupId, job.targetLanguage).run();

        // Check if max retries reached
        const settings = await getSetting(env.DB, "max_retries");
        const maxRetries = parseInt(settings || "5");

        const translation = await env.DB.prepare(
          "SELECT retry_count FROM translations WHERE article_group_id = ? AND target_language = ?"
        ).bind(job.articleGroupId, job.targetLanguage).first<{ retry_count: number }>();

        if (translation && translation.retry_count >= maxRetries) {
          // Mark as failed permanently
          await env.DB.prepare(
            `UPDATE translations SET status = 'failed', updated_at = datetime('now')
             WHERE article_group_id = ? AND target_language = ?`
          ).bind(job.articleGroupId, job.targetLanguage).run();
          message.ack(); // Don't retry anymore
        } else {
          message.retry(); // Let the queue retry with backoff
        }
      }
    }
  },
};

async function processTranslation(
  job: TranslationJob,
  env: Env,
  startTime: number
): Promise<void> {
  // 1. Update status to in_progress
  await env.DB.prepare(
    `UPDATE translations SET status = 'in_progress', updated_at = datetime('now')
     WHERE article_group_id = ? AND target_language = ?`
  ).bind(job.articleGroupId, job.targetLanguage).run();

  // 2. Fetch source article from GitHub
  const sourcePath = `${env.SOURCE_CONTENT_PATH}/${job.sourceFile}`;
  const sourceFile = await fetchFile(env.SOURCE_REPO, sourcePath, env.GITHUB_TOKEN);

  // 3. Get AI settings
  const providerName = await getSetting(env.DB, "active_ai_provider") || "openai";
  const modelName = await getSetting(env.DB, "active_ai_model") || "gpt-4o-mini";
  const prompt = await getSetting(env.DB, "translation_prompt") || "";
  const promptVersion = hashString(prompt).substring(0, 8);

  // 4. Get AI provider and translate
  const apiKey = getApiKey(env, providerName);
  const provider = getProvider(providerName, apiKey);

  const request: TranslationRequest = {
    sourceContent: sourceFile.content,
    sourceLanguage: "pl",
    targetLanguage: job.targetLanguage,
    systemPrompt: prompt,
    model: modelName,
  };

  const result = await provider.translate(request);

  // 5. Push translated file to target repo
  const targetFilename = result.translatedSlug
    ? `${result.translatedSlug}.md`
    : job.sourceFile;
  const targetPath = `${env.TARGET_CONTENT_PATH}/${targetFilename}`;

  await pushFile(
    env.TARGET_REPO,
    targetPath,
    result.translatedContent,
    env.GITHUB_TOKEN,
    `[auto-translate] ${job.sourceTitle} → ${job.targetLanguage}`,
    "main"
  );

  // 6. Update D1: translation status
  await env.DB.prepare(
    `UPDATE translations 
     SET status = 'draft',
         file_path = ?,
         slug = ?,
         meta_title = ?,
         meta_description = ?,
         origin = 'ai',
         error_message = NULL,
         updated_at = datetime('now')
     WHERE article_group_id = ? AND target_language = ?`
  ).bind(
    targetPath,
    result.translatedSlug,
    result.translatedMetaTitle,
    result.translatedMetaDescription,
    job.articleGroupId,
    job.targetLanguage
  ).run();

  // 7. Log successful attempt in history
  const executionTime = Date.now() - startTime;
  const cost = provider.estimateCost(result.inputTokens, result.outputTokens, result.model);

  await env.DB.prepare(
    `INSERT INTO translation_history 
     (id, article_group_id, target_language, ai_provider, ai_model, prompt_version, 
      input_tokens, output_tokens, estimated_cost_usd, execution_time_ms, status, origin)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'success', 'ai')`
  ).bind(
    crypto.randomUUID(),
    job.articleGroupId,
    job.targetLanguage,
    providerName,
    modelName,
    promptVersion,
    result.inputTokens,
    result.outputTokens,
    cost,
    executionTime
  ).run();
}

async function logAttempt(
  db: D1Database,
  job: TranslationJob,
  startTime: number,
  status: string,
  errorMessage: string
): Promise<void> {
  const executionTime = Date.now() - startTime;
  await db.prepare(
    `INSERT INTO translation_history 
     (id, article_group_id, target_language, status, error_message, execution_time_ms, origin)
     VALUES (?, ?, ?, ?, ?, ?, 'ai')`
  ).bind(
    crypto.randomUUID(),
    job.articleGroupId,
    job.targetLanguage,
    status,
    errorMessage,
    executionTime
  ).run();
}

async function getSetting(db: D1Database, key: string): Promise<string | null> {
  const result = await db.prepare(
    "SELECT value FROM settings WHERE key = ?"
  ).bind(key).first<{ value: string }>();
  return result?.value || null;
}

function getApiKey(env: Env, provider: string): string {
  switch (provider) {
    case "openai":
      return env.OPENAI_API_KEY;
    // Future: case "anthropic": return env.ANTHROPIC_API_KEY;
    default:
      return env.OPENAI_API_KEY;
  }
}

function hashString(str: string): string {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash |= 0;
  }
  return Math.abs(hash).toString(16);
}
