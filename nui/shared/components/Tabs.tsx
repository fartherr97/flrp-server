import { cn } from '../lib/cn';
export function Tabs<T extends string>({ tabs, value, onChange, className }:
  { tabs: { id: T; label: string; icon?: React.ReactNode }[]; value: T; onChange: (id: T) => void; className?: string }) {
  return (
    <div className={cn('flex gap-1 border-b border-border-soft', className)}>
      {tabs.map((t) => (
        <button key={t.id} onClick={() => onChange(t.id)}
          className={cn('flex items-center gap-2 px-3 py-2 text-[13px] font-semibold -mb-px border-b-2 transition-colors duration-DEFAULT [&_svg]:size-4',
            value === t.id ? 'border-primary text-fg' : 'border-transparent text-fg-muted hover:text-fg')}>
          {t.icon}{t.label}
        </button>
      ))}
    </div>
  );
}
