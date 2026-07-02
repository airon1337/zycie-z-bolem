# MyNeuralgia — Multilingual CMS

English-language blog about Trigeminal Neuralgia, automatically translated from [zyciezbolem.pl](https://zyciezbolem.pl).

## Architecture

- **Astro** static site deployed to Cloudflare Pages
- **Cloudflare Workers** for webhook handling, translation queue processing, and admin dashboard
- **Cloudflare D1** for article tracking, translation history, and cost monitoring
- **Cloudflare Queues** for reliable background translation
- **OpenAI API** (gpt-4o-mini) for professional localization

## How it works

1. Write article in Polish via Pages CMS → pushes to `zycie-z-bolem` repo
2. GitHub webhook fires → Webhook Worker detects new article
3. Translation job enqueued → Queue Consumer calls OpenAI
4. Translated .md pushed to this repo → Cloudflare Pages auto-rebuilds
5. Review in Pages CMS → set status to published → live on myneuralgia.com

## Setup

See `SETUP.md` for deployment instructions.

## Costs

- Hosting: **$0** (Cloudflare free tier)
- Translation: **~$0.02-0.05 per article** (OpenAI gpt-4o-mini)
