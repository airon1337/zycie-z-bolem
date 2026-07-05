export interface Env {
  DB: D1Database;
  MAX_COMMENTS_PER_ARTICLE: string;
  RATE_LIMIT_COUNT: string;
  RATE_LIMIT_WINDOW_SEC: string;
  ALLOWED_ORIGIN: string;
}

function cors(env: Env, request?: Request): Record<string, string> {
  const origin = request?.headers.get('Origin') || '';
  const allowed = [env.ALLOWED_ORIGIN, 'https://myneuralgia-en.pages.dev'];
  const match = allowed.includes(origin) ? origin : env.ALLOWED_ORIGIN;
  return {
    'Access-Control-Allow-Origin': match,
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
}

function hashIP(ip: string): string {
  // Simple hash - not crypto-grade but enough for rate limiting
  let h = 0;
  for (let i = 0; i < ip.length; i++) {
    h = ((h << 5) - h + ip.charCodeAt(i)) | 0;
  }
  return 'ip_' + Math.abs(h).toString(36);
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors(env, request) });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    try {
      // GET /comments?slug=xxx
      if (path === '/comments' && request.method === 'GET') {
        const slug = url.searchParams.get('slug');
        if (!slug) return json(env, { error: 'Missing slug' }, 400);

        const comments = await env.DB.prepare(
          'SELECT id, author_name, content, created_at FROM comments WHERE article_slug = ? ORDER BY created_at ASC'
        ).bind(slug).all();

        const reactions = await env.DB.prepare(
          'SELECT reaction, COUNT(*) as count FROM reactions WHERE article_slug = ? GROUP BY reaction'
        ).bind(slug).all();

        const counts = { up: 0, down: 0 };
        for (const r of reactions.results) {
          if (r.reaction === 'up') counts.up = r.count as number;
          if (r.reaction === 'down') counts.down = r.count as number;
        }

        return json(env, { comments: comments.results, reactions: counts });
      }

      // POST /comments { slug, name?, content }
      if (path === '/comments' && request.method === 'POST') {
        const body = await request.json() as any;
        const slug = body.slug?.trim();
        const content = body.content?.trim();
        const name = (body.name?.trim() || 'Anonymous').slice(0, 50);
        const honeypot = body.website || '';

        if (!slug || !content) return json(env, { error: 'Missing fields' }, 400);
        if (honeypot) return json(env, { error: 'Spam detected' }, 403);
        if (content.length < 3 || content.length > 1000) return json(env, { error: 'Comment must be 3-1000 chars' }, 400);

        const ip = request.headers.get('CF-Connecting-IP') || 'unknown';
        const ipHash = hashIP(ip);

        // Check max comments per article
        const maxComments = parseInt(env.MAX_COMMENTS_PER_ARTICLE || '10');
        const countResult = await env.DB.prepare(
          'SELECT COUNT(*) as cnt FROM comments WHERE article_slug = ?'
        ).bind(slug).first();
        if ((countResult?.cnt as number) >= maxComments) {
          return json(env, { error: 'Maximum comments reached for this article' }, 429);
        }

        // Rate limit: N comments per IP per window
        const rateLimit = parseInt(env.RATE_LIMIT_COUNT || '3');
        const window = parseInt(env.RATE_LIMIT_WINDOW_SEC || '300');
        const since = new Date(Date.now() - window * 1000).toISOString();
        const recentResult = await env.DB.prepare(
          'SELECT COUNT(*) as cnt FROM comments WHERE ip_hash = ? AND created_at > ?'
        ).bind(ipHash, since).first();
        if ((recentResult?.cnt as number) >= rateLimit) {
          return json(env, { error: 'Too many comments. Please wait a few minutes.' }, 429);
        }

        // Insert
        await env.DB.prepare(
          'INSERT INTO comments (article_slug, author_name, content, ip_hash) VALUES (?, ?, ?, ?)'
        ).bind(slug, name, content, ipHash).run();

        return json(env, { success: true }, 201);
      }

      // POST /reactions { slug, reaction: "up"|"down" }
      if (path === '/reactions' && request.method === 'POST') {
        const body = await request.json() as any;
        const slug = body.slug?.trim();
        const reaction = body.reaction;

        if (!slug || !['up', 'down'].includes(reaction)) {
          return json(env, { error: 'Invalid request' }, 400);
        }

        const ip = request.headers.get('CF-Connecting-IP') || 'unknown';
        const ipHash = hashIP(ip);

        // One reaction per IP per article (upsert)
        await env.DB.prepare(
          'INSERT INTO reactions (article_slug, reaction, ip_hash) VALUES (?, ?, ?) ON CONFLICT(article_slug, ip_hash) DO UPDATE SET reaction = ?'
        ).bind(slug, reaction, ipHash, reaction).run();

        return json(env, { success: true });
      }

      return json(env, { error: 'Not found' }, 404);
    } catch (e: any) {
      return json(env, { error: e.message || 'Internal error' }, 500);
    }
  },
};

function json(env: Env, data: any, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...cors(env, request) },
  });
}

