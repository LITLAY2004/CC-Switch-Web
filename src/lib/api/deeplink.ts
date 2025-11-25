import { invoke } from "./adapter";

export interface DeepLinkImportRequest {
  version: string;
  resource: string;
  app: "claude" | "codex" | "gemini";
  name: string;
  homepage: string;
  endpoint: string;
  apiKey: string;
  model?: string;
  notes?: string;
}

export const deeplinkApi = {
  /**
   * Parse a deep link URL
   * @param url The ccswitch:// URL to parse
   * @returns Parsed deep link request
   */
  parseDeeplink: async (url: string): Promise<DeepLinkImportRequest> => {
    return invoke("parse_deeplink", { url });
  },

  /**
   * Import a provider from a deep link request
   * @param request The deep link import request
   * @returns The ID of the imported provider
   */
  importFromDeeplink: async (
    request: DeepLinkImportRequest,
  ): Promise<string> => {
    return invoke("import_from_deeplink", { request });
  },
};
