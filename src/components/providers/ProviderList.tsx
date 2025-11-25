import { CSS } from "@dnd-kit/utilities";
import { DndContext, closestCenter } from "@dnd-kit/core";
import {
  SortableContext,
  useSortable,
  verticalListSortingStrategy,
} from "@dnd-kit/sortable";
import type { CSSProperties } from "react";
import type { Provider } from "@/types";
import type { AppId } from "@/lib/api";
import { useDragSort } from "@/hooks/useDragSort";
import { ProviderCard } from "@/components/providers/ProviderCard";
import { ProviderEmptyState } from "@/components/providers/ProviderEmptyState";

interface ProviderListProps {
  providers: Record<string, Provider>;
  currentProviderId: string;
  backupProviderId?: string | null;
  appId: AppId;
  isEditMode?: boolean;
  onSwitch: (provider: Provider) => void;
  onEdit: (provider: Provider) => void;
  onDelete: (provider: Provider) => void;
  onDuplicate: (provider: Provider) => void;
  onConfigureUsage?: (provider: Provider) => void;
  onOpenWebsite: (url: string) => void;
  onCreate?: () => void;
  isLoading?: boolean;
  onAutoFailover?: (targetId: string) => void;
}

export function ProviderList({
  providers,
  currentProviderId,
  backupProviderId,
  appId,
  isEditMode = false,
  onSwitch,
  onEdit,
  onDelete,
  onDuplicate,
  onConfigureUsage,
  onOpenWebsite,
  onCreate,
  isLoading = false,
  onAutoFailover,
}: ProviderListProps) {
  const { sortedProviders, sensors, handleDragEnd } = useDragSort(
    providers,
    appId,
  );

  if (isLoading) {
    return (
      <div className="space-y-3">
        {[0, 1, 2].map((index) => (
          <div
            key={index}
            className="h-28 w-full rounded-lg border border-dashed border-muted-foreground/40 bg-muted/40"
          />
        ))}
      </div>
    );
  }

  if (sortedProviders.length === 0) {
    return <ProviderEmptyState onCreate={onCreate} />;
  }

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={closestCenter}
      onDragEnd={handleDragEnd}
    >
      <SortableContext
        items={sortedProviders.map((provider) => provider.id)}
        strategy={verticalListSortingStrategy}
      >
        <div className="space-y-3">
          {sortedProviders.map((provider) => (
            <SortableProviderCard
              key={provider.id}
              provider={provider}
              isCurrent={provider.id === currentProviderId}
              backupProviderId={backupProviderId}
              appId={appId}
              isEditMode={isEditMode}
              onSwitch={onSwitch}
              onEdit={onEdit}
              onDelete={onDelete}
              onDuplicate={onDuplicate}
              onConfigureUsage={onConfigureUsage}
              onOpenWebsite={onOpenWebsite}
              onAutoFailover={onAutoFailover}
            />
          ))}
        </div>
      </SortableContext>
    </DndContext>
  );
}

interface SortableProviderCardProps {
  provider: Provider;
  isCurrent: boolean;
  backupProviderId?: string | null;
  appId: AppId;
  isEditMode: boolean;
  onSwitch: (provider: Provider) => void;
  onEdit: (provider: Provider) => void;
  onDelete: (provider: Provider) => void;
  onDuplicate: (provider: Provider) => void;
  onConfigureUsage?: (provider: Provider) => void;
  onOpenWebsite: (url: string) => void;
  onAutoFailover?: (targetId: string) => void;
}

function SortableProviderCard({
  provider,
  isCurrent,
  backupProviderId,
  appId,
  isEditMode,
  onSwitch,
  onEdit,
  onDelete,
  onDuplicate,
  onConfigureUsage,
  onOpenWebsite,
  onAutoFailover,
}: SortableProviderCardProps) {
  const {
    setNodeRef,
    attributes,
    listeners,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: provider.id });

  const style: CSSProperties = {
    transform: CSS.Transform.toString(transform),
    transition,
  };

  return (
    <div ref={setNodeRef} style={style}>
      <ProviderCard
        provider={provider}
        isCurrent={isCurrent}
        backupProviderId={backupProviderId}
        appId={appId}
        isEditMode={isEditMode}
        onSwitch={onSwitch}
        onEdit={onEdit}
        onDelete={onDelete}
        onDuplicate={onDuplicate}
        onConfigureUsage={
          onConfigureUsage ? (item) => onConfigureUsage(item) : () => undefined
        }
        onOpenWebsite={onOpenWebsite}
        onAutoFailover={onAutoFailover}
        dragHandleProps={{
          attributes,
          listeners,
          isDragging,
        }}
      />
    </div>
  );
}
