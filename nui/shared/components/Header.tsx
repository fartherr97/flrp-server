import { cn } from '../lib/cn';
import { IconButton } from './Button';
import { X } from 'lucide-react';
export function AppHeader({ title, subtitle, logo, right, onClose }:
  { title: string; subtitle?: string; logo?: string; right?: React.ReactNode; onClose?: () => void }) {
  return (
    <header className="flex items-center gap-3 border-b border-border-soft px-4 py-3">
      {logo && <img src={logo} alt="" className="size-9 rounded-md object-cover ring-1 ring-border" />}
      <div className="min-w-0">
        <div className="text-[15px] font-bold leading-tight">{title}</div>
        {subtitle && <div className="text-xs text-fg-muted">{subtitle}</div>}
      </div>
      <div className="ml-auto flex items-center gap-2">{right}{onClose && <IconButton onClick={onClose}><X /></IconButton>}</div>
    </header>
  );
}
export function KeybindHint({ keys, children, className }: { keys: string; children?: React.ReactNode; className?: string }) {
  return (
    <span className={cn('text-2xs text-fg-faint', className)}>
      {children}<kbd className="mx-1 rounded border border-border bg-panel-hover px-1.5 py-0.5 font-bold text-fg-muted">{keys}</kbd>
    </span>
  );
}
