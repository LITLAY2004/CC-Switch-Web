import { invoke } from "./adapter";
import type { UsageResult } from "@/types";
import type { AppId } from "./types";
import i18n from "@/i18n";

export const usageApi = {
  async query(providerId: string, appId: AppId): Promise<UsageResult> {
    try {
      return await invoke("queryProviderUsage", {
        providerId: providerId,
        app: appId,
      });
    } catch (error: unknown) {
      // 提取错误消息：优先使用后端返回的错误信息
      const message =
        typeof error === "string"
          ? error
          : error instanceof Error
            ? error.message
            : "";

      // 如果没有错误消息，使用国际化的默认提示
      return {
        success: false,
        error: message || i18n.t("errors.usage_query_failed"),
      };
    }
  },

  async testScript(
    providerId: string,
    appId: AppId,
    scriptCode: string,
    timeout?: number,
    apiKey?: string,
    baseUrl?: string,
    accessToken?: string,
    userId?: string,
  ): Promise<UsageResult> {
    try {
      return await invoke("testUsageScript", {
        providerId: providerId,
        app: appId,
        scriptCode: scriptCode,
        timeout: timeout,
        apiKey: apiKey,
        baseUrl: baseUrl,
        accessToken: accessToken,
        userId: userId,
      });
    } catch (error: unknown) {
      const message =
        typeof error === "string"
          ? error
          : error instanceof Error
            ? error.message
            : "";

      return {
        success: false,
        error: message || i18n.t("errors.usage_query_failed"),
      };
    }
  },
};
