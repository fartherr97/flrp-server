import { forwardRef } from 'react';
import { cn } from '../lib/cn';
const base = 'w-full rounded-sm border border-border bg-black/25 px-3 text-[13px] text-fg placeholder:text-fg-faint ' +
  'outline-none transition-colors duration-DEFAULT focus:border-primary/70 focus:ring-2 focus:ring-primary/25 disabled:opacity-50';
export const Input = forwardRef<HTMLInputElement, React.InputHTMLAttributes<HTMLInputElement>>(
  ({ className, ...p }, ref) => <input ref={ref} className={cn(base, 'h-9', className)} {...p} />);
Input.displayName = 'Input';
export const Textarea = forwardRef<HTMLTextAreaElement, React.TextareaHTMLAttributes<HTMLTextAreaElement>>(
  ({ className, ...p }, ref) => <textarea ref={ref} className={cn(base, 'py-2 leading-relaxed resize-none', className)} {...p} />);
Textarea.displayName = 'Textarea';
export function Field({ label, hint, children }: { label: string; hint?: string; children: React.ReactNode }) {
  return (
    <label className="block space-y-1.5">
      <span className="block text-2xs font-bold uppercase tracking-wider text-fg-faint">
        {label}{hint && <span className="ml-1.5 font-medium normal-case tracking-normal text-fg-faint/80">{hint}</span>}
      </span>
      {children}
    </label>
  );
}
