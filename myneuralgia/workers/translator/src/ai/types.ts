/**
 * AI Provider Interface
 * Implement this to add a new translation provider (OpenAI, Claude, Gemini, etc.)
 */

export interface TranslationRequest {
  sourceContent: string;
  sourceLanguage: string;
  targetLanguage: string;
  systemPrompt: string;
  model: string;
}

export interface TranslationResult {
  translatedContent: string;   // Full markdown with frontmatter
  translatedTitle: string;
  translatedSlug: string;
  translatedMetaTitle: string;
  translatedMetaDescription: string;
  inputTokens: number;
  outputTokens: number;
  model: string;
}

export interface AIProvider {
  name: string;
  translate(request: TranslationRequest): Promise<TranslationResult>;
  estimateCost(inputTokens: number, outputTokens: number, model: string): number;
}
