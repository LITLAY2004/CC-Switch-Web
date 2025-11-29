import React from "react";
import { Save } from "lucide-react";
import { useTranslation } from "react-i18next";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";

interface CodexCommonConfigModalProps {
  isOpen: boolean;
  onClose: () => void;
  value: string;
  onChange: (value: string) => void;
  error?: string;
}

/**
 * CodexCommonConfigModal - Common Codex configuration editor modal
 * Allows editing of common TOML configuration shared across providers
 */
export const CodexCommonConfigModal: React.FC<CodexCommonConfigModalProps> = ({
  isOpen,
  onClose,
  value,
  onChange,
  error,
}) => {
  const { t } = useTranslation();

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <DialogContent
        zIndex="nested"
        className="max-w-2xl max-h-[90vh] flex flex-col p-0"
      >
        <DialogHeader className="px-6 pt-6 pb-0">
          <DialogTitle>{t("codexConfig.editCommonConfigTitle")}</DialogTitle>
          <DialogDescription>
            {t("codexConfig.commonConfigDescription", {
              defaultValue: "管理所有 Codex 供应商共享的配置片段。",
            })}
          </DialogDescription>
        </DialogHeader>

        <div className="flex-1 overflow-auto px-6 py-4 space-y-4">
          <p className="text-sm text-gray-500 dark:text-gray-400">
            {t("codexConfig.commonConfigHint")}
          </p>

          <textarea
            value={value}
            onChange={(e) => onChange(e.target.value)}
            placeholder={`# Common Codex config

# Add your common TOML configuration here`}
            rows={12}
            className="w-full px-3 py-2 border border-border-default  dark:bg-gray-800 dark:text-gray-100 rounded-lg text-sm font-mono focus:outline-none focus:ring-2 focus:ring-blue-500/20 dark:focus:ring-blue-400/20 focus:border-border-active  transition-colors resize-y"
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

          {error && (
            <p className="text-sm text-red-500 dark:text-red-400">{error}</p>
          )}
        </div>

        <DialogFooter>
          <Button type="button" variant="outline" onClick={onClose}>
            {t("common.cancel")}
          </Button>
          <Button type="button" onClick={onClose} className="gap-2">
            <Save className="w-4 h-4" />
            {t("common.save")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
};
