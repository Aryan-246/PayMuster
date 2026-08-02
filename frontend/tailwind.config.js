/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        pm: {
          background: 'var(--pm-bg-primary)',
          surface: 'var(--pm-bg-secondary)',
          raised: 'var(--pm-bg-tertiary)',
          card: 'var(--pm-bg-card)',
          brand: {
            DEFAULT: 'var(--pm-color-primary)',
            strong: 'var(--pm-color-primary-strong)',
          },
          success: 'var(--pm-color-success)',
          warning: 'var(--pm-color-warning)',
          danger: 'var(--pm-color-danger)',
          info: 'var(--pm-color-info)',
          border: 'var(--pm-border)',
          'border-subtle': 'var(--pm-border-subtle)',
          text: {
            primary: 'var(--pm-text-primary)',
            secondary: 'var(--pm-text-secondary)',
            tertiary: 'var(--pm-text-tertiary)',
          },
        },
      },
      spacing: {
        'pm-0': 'var(--pm-space-0)',
        'pm-1': 'var(--pm-space-1)',
        'pm-2': 'var(--pm-space-2)',
        'pm-3': 'var(--pm-space-3)',
        'pm-4': 'var(--pm-space-4)',
        'pm-5': 'var(--pm-space-5)',
        'pm-6': 'var(--pm-space-6)',
        'pm-7': 'var(--pm-space-7)',
        'pm-8': 'var(--pm-space-8)',
        'pm-9': 'var(--pm-space-9)',
        'pm-10': 'var(--pm-space-10)',
      },
      borderRadius: {
        'pm-sm': 'var(--pm-radius-sm)',
        'pm-md': 'var(--pm-radius-md)',
        'pm-lg': 'var(--pm-radius-lg)',
        'pm-xl': 'var(--pm-radius-xl)',
        'pm-max': 'var(--pm-radius-max)',
      },
      boxShadow: {
        'pm-1': 'var(--pm-shadow-1)',
        'pm-2': 'var(--pm-shadow-2)',
        'pm-3': 'var(--pm-shadow-3)',
        'pm-4': 'var(--pm-shadow-4)',
        'pm-5': 'var(--pm-shadow-5)',
      },
      transitionTimingFunction: {
        'pm-ease': 'ease-out',
      },
      transitionDuration: {
        'pm-fast': '150ms',
        'pm-standard': '200ms',
        'pm-deliberate': '300ms',
      },
    },
  },
  plugins: [],
};
