import { forwardRef } from 'react';
import { cn } from '../lib/cn';
type Variant = 'primary' | 'secondary' | 'ghost' | 'outline' | 'danger' | 'success';
type Size = 'sm' | 'md';
const V: Record<Variant, string> = {
  primary:   'bg-primary text-primary-fg hover:brightness-110',
  secondary: 'bg-panel-hover text-fg hover:bg-elevated',
  ghost:     'bg-transparent text-fg-muted hover:bg-panel-hover hover:text-fg',
  outline:   'bg-transparent text-fg border border-border hover:bg-panel-hover',
  danger:    'bg-danger/15 text-danger hover:bg-danger/25',
  success:   'bg-success/15 text-success hover:bg-success/25',
};
const S: Record<Size, string> = { sm: 'h-7 px-2.5 text-2xs gap-1.5', md: 'h-9 px-3.5 text-[13px] gap-2' };
export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant; size?: Size;
}
export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ variant = 'secondary', size = 'md', className, ...p }, ref) => (
    <button ref={ref} className={cn(
      'inline-flex items-center justify-center rounded-sm font-semibold whitespace-nowrap',
      'transition-[filter,background-color,transform] duration-DEFAULT active:translate-y-px',
      'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/50',
      'disabled:opacity-45 disabled:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0',
      V[variant], S[size], className)} {...p} />
  ));
Button.displayName = 'Button';

export function IconButton({ className, ...p }: ButtonProps) {
  return <Button variant="ghost" className={cn('h-8 w-8 px-0', className)} {...p} />;
}
