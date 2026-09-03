import { cn } from '../lib/cn';
import { Loader2 } from 'lucide-react';
export function EmptyState({ icon, title, hint, className }:
  { icon?: React.ReactNode; title: string; hint?: string; className?: string }) {
  return (
    <div className={cn('flex flex-col items-center justify-center gap-2 py-10 text-center', className)}>
      {icon && <div className="text-fg-faint [&_svg]:size-7">{icon}</div>}
      <div className="text-sm font-semibold text-fg-muted">{title}</div>
      {hint && <div className="max-w-xs text-xs text-fg-faint">{hint}</div>}
    </div>
  );
}
export function LoadingState({ label = 'Loading…' }: { label?: string }) {
  return (
    <div className="flex items-center justify-center gap-2 py-10 text-sm text-fg-muted">
      <Loader2 className="size-4 animate-spin" />{label}
    </div>
  );
}
export function ErrorState({ title = 'Something went wrong', hint }: { title?: string; hint?: string }) {
  return <EmptyState title={title} hint={hint} />;
}
