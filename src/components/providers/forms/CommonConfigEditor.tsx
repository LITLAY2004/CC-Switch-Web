import { useTranslation } from "react-i18next";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { Save, Wand2 } from "lucide-react";
import { toast } from "sonner";
import { formatJSON } from "@/utils/formatters";

interface CommonConfigEditorProps {
  value: string;
  onChange: (value: string) => void;
  useCommonConfig: boolean;
  onCommonConfigToggle: (checked: boolean) => void;
  commonConfigSnippet: string;
  onCommonConfigSnippetChange: (value: string) => void;
  commonConfigError: string;
  onEditClick: () => void;
  isModalOpen: boolean;
  onModalClose: () => void;
}

export function CommonConfigEditor({
  value,
  onChange,
  useCommonConfig,
  onCommonConfigToggle,
  commonConfigSnippet,
  onCommonConfigSnippetChange,
  commonConfigError,
  onEditClick,
  isModalOpen,
  onModalClose,
}: CommonConfigEditorProps) {
  const { t } = useTranslation();

  const handleFormatMain = () => {
    if (!value.trim()) return;

    try {
      const formatted = formatJSON(value);
      onChange(formatted);
      toast.success(t("common.formatSuccess", { defaultValue: "格式化成功" }));
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : String(error);
      toast.error(
        t("common.formatError", {
          defaultValue: "格式化失败：{{error}}",
          error: errorMessage,
        }),
      );
    }
  };

  const handleFormatModal = () => {
    if (!commonConfigSnippet.trim()) return;

    try {
      const formatted = formatJSON(commonConfigSnippet);
      onCommonConfigSnippetChange(formatted);
      toast.success(t("common.formatSuccess", { defaultValue: "格式化成功" }));
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : String(error);
      toast.error(
        t("common.formatError", {
          defaultValue: "格式化失败：{{error}}",
          error: errorMessage,
        }),
      );
    }
  };

  return (
    <>
      <div className="space-y-2">
        <div className="flex items-center justify-between">
          <Label htmlFor="settingsConfig">{t("provider.configJson")}</Label>
          <div className="flex items-center gap-2">
            <label className="inline-flex items-center gap-2 text-sm text-muted-foreground cursor-pointer">
              <input
                type="checkbox"
                id="useCommonConfig"
                checked={useCommonConfig}
                onChange={(e) => onCommonConfigToggle(e.target.checked)}
                className="w-4 h-4 text-blue-500 bg-white dark:bg-gray-800 border-border-default rounded focus:ring-blue-500 dark:focus:ring-blue-400 focus:ring-2"
              />
              <span>
                {t("claudeConfig.writeCommonConfig", {
                  defaultValue: "写入通用配置",
                })}
              </span>
            </label>
          </div>
        </div>
        <div className="flex items-center justify-end">
          <button
            type="button"
            onClick={onEditClick}
            className="text-xs text-blue-400 dark:text-blue-500 hover:text-blue-500 dark:hover:text-blue-400 transition-colors"
          >
            {t("claudeConfig.editCommonConfig", {
              defaultValue: "编辑通用配置",
            })}
          </button>
        </div>
        {commonConfigError && !isModalOpen && (
          <p className="text-xs text-red-500 dark:text-red-400 text-right">
            {commonConfigError}
          </p>
        )}
        <textarea
          id="settingsConfig"
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={`{
  "env": {
    "ANTHROPIC_BASE_URL": "https://your-api-endpoint.com",
    "ANTHROPIC_AUTH_TOKEN": "your-api-key-here"
  }
}`}
          rows={14}
          className="w-full px-3 py-2 border border-border-default dark:bg-gray-800 dark:text-gray-100 rounded-lg text-sm font-mono focus:outline-none focus:ring-2 focus:ring-blue-500/20 dark:focus:ring-blue-400/20 transition-colors resize-y min-h-[16rem]"
          autoComplete="off"
          autoCorrect="off"
          autoCapitalize="none"
          spellCheck={false}
          lang="en"
          inputMode="text"
          data-gramm="false"
          data-gramm_editor="false"
          data-enable-grammarly="false"
        />
        <div className="flex items-center justify-between">
          <button
            type="button"
            onClick={handleFormatMain}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-gray-700 dark:text-gray-300 hover:text-blue-600 dark:hover:text-blue-400 transition-colors"
          >
            <Wand2 className="w-3.5 h-3.5" />
            {t("common.format", { defaultValue: "格式化" })}
          </button>
        </div>
      </div>

      <Dialog
        open={isModalOpen}
        onOpenChange={(open) => !open && onModalClose()}
      >
        <DialogContent className="sm:max-w-[600px] max-h-[90vh] flex flex-col p-0">
          <DialogHeader className="px-6 pt-6 pb-0">
            <DialogTitle>
              {t("claudeConfig.editCommonConfigTitle", {
                defaultValue: "编辑通用配置片段",
              })}
            </DialogTitle>
            <DialogDescription>
              {t("claudeConfig.commonConfigDescription", {
                defaultValue: "管理通用配置片段并应用到启用它的供应商。",
              })}
            </DialogDescription>
          </DialogHeader>
          <div className="flex-1 overflow-auto px-6 py-4 space-y-4">
            <p className="text-sm text-muted-foreground">
              {t("claudeConfig.commonConfigHint", {
                defaultValue: "通用配置片段将合并到所有启用它的供应商配置中",
              })}
            </p>
            <textarea
              value={commonConfigSnippet}
              onChange={(e) => onCommonConfigSnippetChange(e.target.value)}
              rows={12}
              className="w-full px-3 py-2 border border-border-default dark:bg-gray-800 dark:text-gray-100 rounded-lg text-sm font-mono focus:outline-none focus:ring-2 focus:ring-blue-500/20 dark:focus:ring-blue-400/20 transition-colors resize-y min-h-[14rem]"
              autoComplete="off"
              autoCorrect="off"
              autoCapitalize="none"
              spellCheck={false}
              lang="en"
              inputMode="text"
              data-gramm="false"
              data-gramm_editor="false"
              data-enable-grammarly="false"
            />
            <div className="flex items-center justify-between">
              <button
                type="button"
                onClick={handleFormatModal}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-gray-700 dark:text-gray-300 hover:text-blue-600 dark:hover:text-blue-400 transition-colors"
              >
                <Wand2 className="w-3.5 h-3.5" />
                {t("common.format", { defaultValue: "格式化" })}
              </button>
              {commonConfigError && (
                <p className="text-sm text-red-500 dark:text-red-400">
                  {commonConfigError}
                </p>
              )}
            </div>
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={onModalClose}>
              {t("common.cancel")}
            </Button>
            <Button type="button" onClick={onModalClose} className="gap-2">
              <Save className="w-4 h-4" />
              {t("common.save")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
