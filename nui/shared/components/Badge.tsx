import { cn } from '../lib/cn';
type Tone = 'neutral' | 'primary' | 'success' | 'warning' | 'danger' | 'info';
const T: Record<Tone, string> = {
  neutral: 'bg-panel-hover text-fg-muted',
  primary: 'bg-primary/15 text-primary',
  success: 'bg-success/15 text-success',
  warning: 'bg-warning/15 text-warning',
  danger:  'bg-danger/15 text-danger',
  info:    'bg-info/15 text-info',
};
export function Badge({ tone = 'neutral', dot, className, children }:
  { tone?: Tone; dot?: boolean; className?: string; children: React.ReactNode }) {
  return (
    <span className={cn('inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-2xs font-semibold', T[tone], className)}>
      {dot && <span className="size-1.5 rounded-full bg-current" />}
      {children}
    </span>
  );
}
export function StatusIndicator({ tone = 'neutral', label }: { tone?: Tone; label: string }) {
  return <Badge tone={tone} dot>{label}</Badge>;
}
