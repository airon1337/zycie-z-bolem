/**
 * Admin Dashboard Worker — shows translation status, queue health, costs.
 * Protected by password.
 */

interface Env {
  DB: D1Database;
  TRANSLATION_QUEUE: Queue;
  DASHBOARD_PASSWORD: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // Authentication check
    const authHeader = request.headers.get('Authorization');
    const urlPassword = url.searchParams.get('key');
    const providedPassword = urlPassword || (authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null);

    if (providedPassword !== env.DASHBOARD_PASSWORD) {
      return new Response('Unauthorized. Add ?key=YOUR_PASSWORD to URL.', {
        status: 401,
        headers: { 'WWW-Authenticate': 'Bearer' },
      });
    }

    // Routing
    if (url.pathname === '/api/stats') return handleStats(env);
    if (url.pathname === '/api/retry' && request.method === 'POST') return handleRetry(request, env);
    if (url.pathname === '/api/translate-all' && request.method === 'POST') return handleTranslateAll(env);
    return handleDashboard(env);
  },
};

async function handleStats(env: Env): Promise<Response> {
  const [articles, translations, history, failed] = await Promise.all([
    env.DB.prepare(`SELECT COUNT(*) as count FROM article_groups`).first<{ count: number }>(),
    env.DB.prepare(`SELECT status, COUNT(*) as count FROM translations GROUP BY status`).all(),
    env.DB.prepare(`SELECT SUM(input_tokens) as totalIn, SUM(output_tokens) as totalOut, SUM(estimated_cost_usd) as totalCost, COUNT(*) as attempts FROM translation_history WHERE status = 'success'`).first(),
    env.DB.prepare(`SELECT t.article_group_id, ag.source_file_path, t.error_message, t.last_attempt_at FROM translations t JOIN article_groups ag ON t.article_group_id = ag.id WHERE t.status = 'failed' ORDER BY t.updated_at DESC LIMIT 10`).all(),
  ]);

  return Response.json({
    totalArticles: articles?.count || 0,
    translationsByStatus: translations.results,
    tokenStats: history,
    recentFailures: failed.results,
  });
}

async function handleRetry(request: Request, env: Env): Promise<Response> {
  const { articleGroupId, language } = await request.json() as any;

  const group = await env.DB.prepare(
    `SELECT source_file_path FROM article_groups WHERE id = ?`
  ).bind(articleGroupId).first<{ source_file_path: string }>();

  if (!group) return Response.json({ error: 'Article not found' }, { status: 404 });

  await env.DB.prepare(
    `UPDATE translations SET status = 'queued', error_message = NULL, updated_at = datetime('now')
     WHERE article_group_id = ? AND language_code = ?`
  ).bind(articleGroupId, language).run();

  await env.TRANSLATION_QUEUE.send({
    articleGroupId,
    sourceFilePath: group.source_file_path,
    sourceRepo: 'airon1337/zycie-z-bolem',
    targetLanguage: language || 'en',
    isRetranslation: true,
    triggeredBy: 'admin',
    commitSha: 'manual-retry',
  });

  return Response.json({ ok: true, message: 'Retried' });
}

async function handleTranslateAll(env: Env): Promise<Response> {
  const missing = await env.DB.prepare(
    `SELECT t.article_group_id, t.language_code, ag.source_file_path
     FROM translations t
     JOIN article_groups ag ON t.article_group_id = ag.id
     WHERE t.status IN ('not_started', 'failed')`
  ).all();

  let enqueued = 0;
  for (const row of missing.results as any[]) {
    await env.DB.prepare(
      `UPDATE translations SET status = 'queued', error_message = NULL, updated_at = datetime('now')
       WHERE article_group_id = ? AND language_code = ?`
    ).bind(row.article_group_id, row.language_code).run();

    await env.TRANSLATION_QUEUE.send({
      articleGroupId: row.article_group_id,
      sourceFilePath: row.source_file_path,
      sourceRepo: 'airon1337/zycie-z-bolem',
      targetLanguage: row.language_code,
      isRetranslation: false,
      triggeredBy: 'admin',
      commitSha: 'bulk-translate',
    });
    enqueued++;
  }

  return Response.json({ ok: true, enqueued });
}

async function handleDashboard(env: Env): Promise<Response> {
  const stats = await env.DB.prepare(`
    SELECT
      (SELECT COUNT(*) FROM article_groups) as total_articles,
      (SELECT COUNT(*) FROM translations WHERE status = 'draft') as drafts,
      (SELECT COUNT(*) FROM translations WHERE status = 'published') as published,
      (SELECT COUNT(*) FROM translations WHERE status = 'queued' OR status = 'in_progress') as in_queue,
      (SELECT COUNT(*) FROM translations WHERE status = 'failed') as failed,
      (SELECT COUNT(*) FROM translations WHERE status = 'not_started') as not_started,
      (SELECT COALESCE(SUM(estimated_cost_usd), 0) FROM translation_history WHERE status = 'success') as total_cost,
      (SELECT COALESCE(SUM(input_tokens + output_tokens), 0) FROM translation_history WHERE status = 'success') as total_tokens
  `).first() as any;

  const failures = await env.DB.prepare(`
    SELECT t.article_group_id, ag.source_file_path, t.language_code, t.error_message, t.retry_count, t.last_attempt_at
    FROM translations t
    JOIN article_groups ag ON t.article_group_id = ag.id
    WHERE t.status = 'failed'
    ORDER BY t.updated_at DESC
    LIMIT 20
  `).all();

  const html = generateDashboardHTML(stats, failures.results as any[]);
  return new Response(html, { headers: { 'Content-Type': 'text/html; charset=utf-8' } });
}

function generateDashboardHTML(stats: any, failures: any[]): string {
  const failureRows = failures.map(f => `
    <tr>
      <td>${f.source_file_path.split('/').pop()}</td>
      <td>${f.language_code}</td>
      <td style="color:red">${f.error_message || 'Unknown'}</td>
      <td>${f.retry_count}</td>
      <td>${f.last_attempt_at || '-'}</td>
      <td><button onclick="retry('${f.article_group_id}','${f.language_code}')">🔄 Retry</button></td>
    </tr>
  `).join('');

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>MyNeuralgia — Translation Dashboard</title>
  <style>
    * { margin:0; padding:0; box-sizing:border-box; }
    body { font-family: -apple-system, system-ui, sans-serif; background:#f8fafc; padding:2rem; color:#1e293b; }
    h1 { color:#2c5d55; margin-bottom:1.5rem; }
    .cards { display:grid; grid-template-columns:repeat(auto-fit,minmax(150px,1fr)); gap:1rem; margin-bottom:2rem; }
    .card { background:white; border-radius:12px; padding:1.25rem; box-shadow:0 1px 3px rgba(0,0,0,.1); text-align:center; }
    .card .num { font-size:2rem; font-weight:700; color:#2c5d55; }
    .card .label { font-size:.85rem; color:#64748b; margin-top:.25rem; }
    table { width:100%; border-collapse:collapse; background:white; border-radius:12px; overflow:hidden; box-shadow:0 1px 3px rgba(0,0,0,.1); }
    th, td { padding:.75rem 1rem; text-align:left; border-bottom:1px solid #e2e8f0; font-size:.9rem; }
    th { background:#f1f5f9; font-weight:600; }
    button { background:#2c5d55; color:white; border:none; padding:.4rem .8rem; border-radius:6px; cursor:pointer; font-size:.8rem; }
    button:hover { background:#3a7a6f; }
    .actions { margin:1.5rem 0; display:flex; gap:1rem; }
    .actions button { padding:.6rem 1.2rem; font-size:1rem; }
  </style>
</head>
<body>
  <h1>🌐 Translation Dashboard</h1>

  <div class="cards">
    <div class="card"><div class="num">${stats.total_articles}</div><div class="label">Polish Articles</div></div>
    <div class="card"><div class="num">${stats.drafts}</div><div class="label">EN Drafts</div></div>
    <div class="card"><div class="num">${stats.published}</div><div class="label">EN Published</div></div>
    <div class="card"><div class="num">${stats.in_queue}</div><div class="label">In Queue</div></div>
    <div class="card"><div class="num" style="color:#dc2626">${stats.failed}</div><div class="label">Failed</div></div>
    <div class="card"><div class="num">${stats.not_started}</div><div class="label">Not Started</div></div>
    <div class="card"><div class="num">$${Number(stats.total_cost).toFixed(2)}</div><div class="label">Total Cost</div></div>
    <div class="card"><div class="num">${Number(stats.total_tokens).toLocaleString()}</div><div class="label">Total Tokens</div></div>
  </div>

  <div class="actions">
    <button onclick="translateAll()">🚀 Translate All Missing</button>
  </div>

  ${failures.length > 0 ? `
  <h2 style="margin:1.5rem 0 1rem; color:#dc2626;">❌ Failed Translations</h2>
  <table>
    <tr><th>Article</th><th>Lang</th><th>Error</th><th>Retries</th><th>Last Attempt</th><th>Action</th></tr>
    ${failureRows}
  </table>` : '<p style="margin-top:1rem;color:#16a34a">✅ No failures — everything looks good!</p>'}

  <script>
    const key = new URLSearchParams(window.location.search).get('key');
    async function retry(groupId, lang) {
      await fetch('/api/retry?key='+key, { method:'POST', body: JSON.stringify({articleGroupId:groupId,language:lang}), headers:{'Content-Type':'application/json'} });
      location.reload();
    }
    async function translateAll() {
      if(!confirm('Translate all missing/failed articles?')) return;
      const res = await fetch('/api/translate-all?key='+key, { method:'POST' });
      const data = await res.json();
      alert('Enqueued: ' + data.enqueued + ' articles');
      location.reload();
    }
  </script>
</body>
</html>`;
}
