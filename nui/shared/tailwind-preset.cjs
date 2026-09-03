/** FLRP shared Tailwind preset. Every app extends this so colours, radii,
 *  fonts and motion are identical across all FLRP interfaces. */
const hsl = (v) => `hsl(var(--flrp-${v}) / <alpha-value>)`;
module.exports = {
  theme: {
    extend: {
      colors: {
        bg:          hsl('bg'),
        panel:       { DEFAULT: hsl('panel'), hover: hsl('panel-hover') },
        elevated:    hsl('elevated'),
        border:      { DEFAULT: hsl('border'), soft: hsl('border-soft') },
        fg:          { DEFAULT: hsl('text'), muted: hsl('text-muted'), faint: hsl('text-faint') },
        primary:     { DEFAULT: hsl('primary'), fg: hsl('primary-fg') },
        success:     hsl('success'),
        warning:     hsl('warning'),
        danger:      hsl('danger'),
        info:        hsl('info'),
      },
      borderColor:     { DEFAULT: hsl('border') },
      borderRadius:    { DEFAULT: 'var(--flrp-radius)', sm: 'var(--flrp-radius-sm)', lg: 'var(--flrp-radius-lg)' },
      fontFamily:      { sans: ['Inter', 'Geist', 'system-ui', 'Segoe UI', 'Roboto', 'sans-serif'] },
      transitionDuration: { DEFAULT: 'var(--flrp-speed)' },
      fontSize: {
        '2xs': ['0.6875rem', { lineHeight: '1rem' }],
      },
      keyframes: {
        'flrp-in':   { from: { opacity: '0' }, to: { opacity: '1' } },
        'flrp-rise': { from: { opacity: '0', transform: 'translateY(6px) scale(.99)' }, to: { opacity: '1', transform: 'none' } },
        'flrp-slide':{ from: { opacity: '0', transform: 'translateX(10px)' }, to: { opacity: '1', transform: 'none' } },
      },
      animation: {
        'flrp-in':   'flrp-in var(--flrp-speed) ease',
        'flrp-rise': 'flrp-rise 160ms cubic-bezier(.2,.8,.2,1)',
        'flrp-slide':'flrp-slide var(--flrp-speed) ease',
      },
    },
  },
};
