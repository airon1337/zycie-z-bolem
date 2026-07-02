import { AIProvider } from "../types";
import { OpenAIProvider } from "./openai";

/**
 * Provider Registry
 * Add new providers here. The system picks the active one from D1 settings.
 * 
 * To add a new provider (e.g. Claude):
 * 1. Create ./claude.ts implementing AIProvider
 * 2. Add it to this registry
 * 3. Update D1 setting 'active_ai_provider' to 'anthropic'
 */
export function getProvider(providerName: string, apiKey: string): AIProvider {
  switch (providerName) {
    case "openai":
      return new OpenAIProvider(apiKey);
    // Future providers:
    // case "anthropic":
    //   return new AnthropicProvider(apiKey);
    // case "google":
    //   return new GeminiProvider(apiKey);
    default:
      throw new Error(`Unknown AI provider: ${providerName}`);
  }
}
