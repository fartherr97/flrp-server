import { useEscape } from '../lib/nui';
import { cn } from '../lib/cn';
import { IconButton } from './Button';
import { X } from 'lucide-react';
export function Modal({ open, onClose, title, subtitle, children, footer, width = 'max-w-md', dim = true }:
  { open: boolean; onClose: () => void; title?: string; subtitle?: string; children: React.ReactNode;
    footer?: React.ReactNode; width?: string; dim?: boolean }) {
  useEscape(onClose, open);
  if (!open) return null;
  return (
    <div className={cn('absolute inset-0 z-50 flex items-center justify-center p-6 animate-flrp-in', dim && 'bg-black/45')}>
      <div className={cn('w-full rounded-lg border border-border bg-elevated shadow-xl shadow-black/40 animate-flrp-rise', width)}>
        {(title || onClose) && (
          <div className="flex items-start gap-3 border-b border-border-soft px-4 py-3">
            <div className="min-w-0">
              {title && <div className="text-[15px] font-bold">{title}</div>}
              {subtitle && <div className="text-xs text-fg-muted">{subtitle}</div>}
            </div>
            <IconButton className="ml-auto" onClick={onClose}><X /></IconButton>
          </div>
        )}
        <div className="px-4 py-4">{children}</div>
        {footer && <div className="flex justify-end gap-2 border-t border-border-soft px-4 py-3">{footer}</div>}
      </div>
    </div>
  );
}
