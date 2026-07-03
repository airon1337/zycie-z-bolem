/**
 * Queue Consumer Worker — translates articles using Cloudflare Workers AI (FREE)
 */

interface Env {
  DB: D1Database;
  AI: any; // Cloudflare Workers AI binding
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
      console.log(`GOT JOB: ${job.sourceFilePath} -> ${job.targetLanguage}`);

      try {
        // Step 1: Fetch source from GitHub
        console.log(`Fetching from GitHub...`);
        const contentsUrl = `https://api.github.com/repos/${job.sourceRepo}/contents/${encodeURIComponent(job.sourceFilePath.split('/')[0])}`;
        
        const listRes = await fetch(contentsUrl, {
          headers: {
            'Authorization': `token ${env.GITHUB_TOKEN}`,
            'User-Agent': 'myneuralgia-worker',
            'Accept': 'application/vnd.github.v3+json',
          },
        });
        
        if (!listRes.ok) {
          const errText = await listRes.text();
          console.log(`List ERROR: ${listRes.status}`);
          message.ack();
          await env.DB.prepare(`UPDATE translations SET status = 'failed', error_message = ? WHERE article_group_id = ? AND language_code = ?`)
            .bind(`GitHub List ${listRes.status}`, job.articleGroupId, job.targetLanguage).run();
          return;
        }

        const files = await listRes.json() as any[];
        const filename = job.sourceFilePath.split('/').pop();
        const targetFile = files.find((f: any) => f.name === filename);
        
        if (!targetFile) {
          console.log(`File "${filename}" not found`);
          message.ack();
          await env.DB.prepare(`UPDATE translations SET status = 'failed', error_message = ? WHERE article_group_id = ? AND language_code = ?`)
            .bind(`File not found: ${filename}`, job.articleGroupId, job.targetLanguage).run();
          return;
        }

        const contentRes = await fetch(targetFile.download_url);
        if (!contentRes.ok) {
          message.ack();
          await env.DB.prepare(`UPDATE translations SET status = 'failed', error_message = ? WHERE article_group_id = ? AND language_code = ?`)
            .bind(`Download failed: ${contentRes.status}`, job.articleGroupId, job.targetLanguage).run();
          return;
        }

        const sourceContent = await contentRes.text();
        console.log(`Got source: ${sourceContent.length} chars`);

        // Step 2: Call Cloudflare Workers AI (FREE!)
        console.log('Calling Workers AI...');
        const model = env.AI_MODEL || '@cf/meta/llama-3.1-8b-instruct';
        
        const prompt = `You are a professional medical translator. Translate this Polish article about trigeminal neuralgia into natural English.

RULES:
- Localize, don't translate literally. Adapt for English patients.
- Keep the warm, empathetic first-person tone.
- Keep medical terms accurate in English.
- Preserve markdown formatting (headings, bold, lists, links).
- Generate an English URL slug (short, no Polish chars).

RESPOND WITH ONLY VALID JSON:
{"title": "English title", "slug": "url-slug", "metaTitle": "SEO title max 60 chars", "metaDescription": "SEO desc max 155 chars", "content": "Full translated markdown content", "tags": ["tag1", "tag2"]}

ARTICLE:

${sourceContent}`;

        const aiResult = await env.AI.run(model, {
          messages: [{ role: 'user', content: prompt }],
          max_tokens: 4096,
          temperature: 0.3,
        });

        if (!aiResult || !aiResult.response) {
          console.log(`AI returned empty: ${JSON.stringify(aiResult).slice(0, 300)}`);
          message.ack();
          await env.DB.prepare(`UPDATE translations SET status = 'failed', error_message = ? WHERE article_group_id = ? AND language_code = ?`)
            .bind('Workers AI empty response', job.articleGroupId, job.targetLanguage).run();
          return;
        }

        console.log(`AI response length: ${aiResult.response.length}`);
        
        // Try to parse JSON from response
        let translated: any;
        try {
          // Remove potential markdown code blocks
          let jsonText = aiResult.response.trim();
          if (jsonText.startsWith('```')) {
            jsonText = jsonText.replace(/^```(?:json)?\n?/, '').replace(/\n?```$/, '');
          }
          // Fix common JSON issues from LLMs: unescaped newlines in strings
          jsonText = jsonText.replace(/\r?\n/g, '\\n');
          // But fix the structural \\n that should be real (between keys)
          jsonText = jsonText.replace(/\\n"/g, '\n"').replace(/\\n}/g, '\n}').replace(/\\n]/g, '\n]').replace(/{\\n/g, '{\n').replace(/\[\\n/g, '[\n');
          translated = JSON.parse(jsonText);
        } catch (parseErr: any) {
          // Fallback: try to extract fields manually with regex
          console.log(`JSON parse failed, trying regex extraction...`);
          const raw = aiResult.response;
          const titleMatch = raw.match(/"title"\s*:\s*"([^"]+)"/);
          const slugMatch = raw.match(/"slug"\s*:\s*"([^"]+)"/);
          const metaTitleMatch = raw.match(/"metaTitle"\s*:\s*"([^"]+)"/);
          const metaDescMatch = raw.match(/"metaDescription"\s*:\s*"([^"]+)"/);
          
          // Extract content between "content": " and the last ", "tags" or "}
          const contentMatch = raw.match(/"content"\s*:\s*"([\s\S]*?)"\s*,\s*"tags"/);
          
          if (titleMatch && contentMatch) {
            translated = {
              title: titleMatch[1],
              slug: slugMatch ? slugMatch[1] : 'untitled',
              metaTitle: metaTitleMatch ? metaTitleMatch[1] : titleMatch[1],
              metaDescription: metaDescMatch ? metaDescMatch[1] : '',
              content: contentMatch[1].replace(/\\n/g, '\n').replace(/\\"/g, '"'),
              tags: [],
            };
            console.log(`Regex extraction OK: "${translated.title}"`);
          } else {
            console.log(`Regex extraction also failed. Raw start: ${raw.slice(0, 200)}`);
            message.ack();
            await env.DB.prepare(`UPDATE translations SET status = 'failed', error_message = ? WHERE article_group_id = ? AND language_code = ?`)
              .bind(`JSON parse failed: ${parseErr.message}`, job.articleGroupId, job.targetLanguage).run();
            return;
          }
        }

        console.log(`Translated! Title: "${translated.title}"`);

        // Step 3: Build markdown
        const slug = (translated.slug || 'untitled').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 80);
        const now = new Date().toISOString().slice(0, 10);
        const md = `---
title: "${(translated.title || '').replace(/"/g, '\\"')}"
slug: "${slug}"
date: "${now}"
status: draft
meta_title: "${(translated.metaTitle || translated.title || '').replace(/"/g, '\\"')}"
meta_description: "${(translated.metaDescription || '').replace(/"/g, '\\"')}"
source_ref: "${job.sourceFilePath}"
translated_at: "${now}"
translated_by: "workers-ai/${model}"
translation_origin: ai
---

${translated.content || ''}
`;

        // Step 4: Push to GitHub
        const targetPath = `${env.TARGET_FOLDER}/${slug}.md`;
        console.log(`Pushing to ${env.TARGET_REPO}/${targetPath}`);
        
        const putRes = await fetch(`https://api.github.com/repos/${env.TARGET_REPO}/contents/${targetPath}`, {
          method: 'PUT',
          headers: {
            'Authorization': `token ${env.GITHUB_TOKEN}`,
            'Content-Type': 'application/json',
            'User-Agent': 'myneuralgia-worker',
          },
          body: JSON.stringify({
            message: `Add translation: ${translated.title}`,
            content: btoa(unescape(encodeURIComponent(md))),
            branch: 'main',
          }),
        });

        if (!putRes.ok) {
          const errText = await putRes.text();
          console.log(`Push ERROR: ${putRes.status} - ${errText.slice(0, 300)}`);
          message.ack();
          await env.DB.prepare(`UPDATE translations SET status = 'failed', error_message = ? WHERE article_group_id = ? AND language_code = ?`)
            .bind(`Push failed: ${putRes.status}`, job.articleGroupId, job.targetLanguage).run();
          return;
        }
        console.log('Push SUCCESS!');

        // Step 5: Update DB
        await env.DB.prepare(`UPDATE translations SET status = 'draft', slug = ?, title = ?, translation_origin = 'ai', file_path = ?, updated_at = datetime('now') WHERE article_group_id = ? AND language_code = ?`)
          .bind(slug, translated.title, targetPath, job.articleGroupId, job.targetLanguage).run();

        await env.DB.prepare(`INSERT INTO translation_history (id, article_group_id, language_code, ai_provider, ai_model, input_tokens, output_tokens, estimated_cost_usd, execution_time_ms, status, origin, created_at) VALUES (?, ?, ?, 'workers-ai', ?, 0, 0, 0, 0, 'success', 'ai', datetime('now'))`)
          .bind(crypto.randomUUID(), job.articleGroupId, job.targetLanguage, model).run();

        console.log('ALL DONE! Article translated and pushed.');
        message.ack();

      } catch (err: any) {
        console.log(`UNCAUGHT ERROR: ${err.message}`);
        message.ack();
        await env.DB.prepare(`UPDATE translations SET status = 'failed', error_message = ? WHERE article_group_id = ? AND language_code = ?`)
          .bind(err.message?.slice(0, 500) || 'Unknown', job.articleGroupId, job.targetLanguage).run();
      }
    }
  },
};
