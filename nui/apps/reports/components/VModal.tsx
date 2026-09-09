import { X } from 'lucide-react';
import { cn } from '@flrp/components';

/** Centered dialog in the vReports idiom: dim overlay, 2px border, 8px radius. */
export function VModal({ open, onClose, title, icon, children, footer, width = 'w-[560px]', surface = 'bg-panel', hideClose }:
  { open: boolean; onClose: () => void; title?: React.ReactNode; icon?: React.ReactNode; children: React.ReactNode;
    footer?: React.ReactNode; width?: string; surface?: string; hideClose?: boolean }) {
  if (!open) return null;
  return (
    <div className="absolute inset-0 z-50 flex items-center justify-center bg-black/70 animate-flrp-in" onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div className={cn('relative max-h-[90vh] max-w-[95vw] overflow-y-auto rounded-[8px] border-2 border-border p-5 animate-flrp-rise v-shadow', surface, width)}>
        {title && (
          <div className="mb-3 flex items-center justify-center gap-1.5 text-lg font-semibold">
            {icon}{title}
          </div>
        )}
        {!hideClose && (
          <button onClick={onClose} className="absolute right-3 top-3 rounded-sm p-1 text-fg-muted transition-colors hover:text-fg" aria-label="Close">
            <X className="size-4" />
          </button>
        )}
        {children}
        {footer && <div className="mt-4 flex flex-wrap items-center justify-end gap-2">{footer}</div>}
      </div>
    </div>
  );
}
