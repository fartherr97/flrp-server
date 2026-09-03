import { cn } from '../lib/cn';
export const Panel = ({ className, ...p }: React.HTMLAttributes<HTMLDivElement>) => (
  <div className={cn('rounded-lg border border-border-soft bg-panel', className)} {...p} />
);
export const Card = ({ className, ...p }: React.HTMLAttributes<HTMLDivElement>) => (
  <div className={cn('rounded border border-border-soft bg-panel p-3', className)} {...p} />
);
export const SectionLabel = ({ className, ...p }: React.HTMLAttributes<HTMLDivElement>) => (
  <div className={cn('text-2xs font-bold uppercase tracking-wider text-fg-faint', className)} {...p} />
);
