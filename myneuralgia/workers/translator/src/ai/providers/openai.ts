import { AIProvider, TranslationRequest, TranslationResult } from "../types";

/**
 * OpenAI Provider
 * Uses the Chat Completions API for translation.
 */
export class OpenAIProvider implements AIProvider {
  name = "openai";
  private apiKey: string;

  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }

  async translate(request: TranslationRequest): Promise<TranslationResult> {
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${this.apiKey}`,
      },
      body: JSON.stringify({
        model: request.model,
        messages: [
          {
            role: "system",
            content: request.systemPrompt,
          },
          {
            role: "user",
            content: `Translate the following article from ${request.sourceLanguage} to ${request.targetLanguage}:\n\n${request.sourceContent}`,
          },
        ],
        temperature: 0.3,
        max_tokens: 8000,
      }),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      const status = response.status;

      if (status === 429) {
        throw new Error(`RATE_LIMIT: OpenAI rate limit exceeded. ${errorBody}`);
      }
      if (status >= 500) {
        throw new Error(`SERVER_ERROR: OpenAI server error (${status}). ${errorBody}`);
      }
      throw new Error(`API_ERROR: OpenAI returned ${status}. ${errorBody}`);
    }

    const data = (await response.json()) as {
      choices: Array<{ message: { content: string } }>;
      usage: { prompt_tokens: number; completion_tokens: number };
    };

    const content = data.choices[0]?.message?.content;
    if (!content) {
      throw new Error("EMPTY_RESPONSE: OpenAI returned empty content");
    }

    // Parse frontmatter from the translated content
    const { title, slug, metaTitle, metaDescription } = parseFrontmatter(content);

    return {
      translatedContent: content,
      translatedTitle: title,
      translatedSlug: slug,
      translatedMetaTitle: metaTitle,
      translatedMetaDescription: metaDescription,
      inputTokens: data.usage.prompt_tokens,
      outputTokens: data.usage.completion_tokens,
      model: request.model,
    };
  }

  estimateCost(inputTokens: number, outputTokens: number, model: string): number {
    // Pricing as of 2024 (USD per 1M tokens)
    const pricing: Record<string, { input: number; output: number }> = {
      "gpt-4o-mini": { input: 0.15, output: 0.6 },
      "gpt-4o": { input: 2.5, output: 10.0 },
      "gpt-4-turbo": { input: 10.0, output: 30.0 },
    };

    const price = pricing[model] || pricing["gpt-4o-mini"];
    return (inputTokens * price.input + outputTokens * price.output) / 1_000_000;
  }
}

function parseFrontmatter(markdown: string): {
  title: string;
  slug: string;
  metaTitle: string;
  metaDescription: string;
} {
  const fmMatch = markdown.match(/^---\n([\s\S]*?)\n---/);
  if (!fmMatch) {
    return { title: "", slug: "", metaTitle: "", metaDescription: "" };
  }

  const fm = fmMatch[1];
  const getValue = (key: string): string => {
    const match = fm.match(new RegExp(`^${key}:\\s*"?([^"\\n]*)"?`, "m"));
    return match ? match[1].trim().replace(/^"|"$/g, "") : "";
  };

  return {
    title: getValue("title"),
    slug: getValue("slug"),
    metaTitle: getValue("meta_title"),
    metaDescription: getValue("meta_description"),
  };
}
