export type ThemeMode = 'dark' | 'light' | 'amoled' | 'system';

export const themeModes: readonly ThemeMode[] = ['dark', 'light', 'amoled', 'system'];

export const themeLabels: Record<ThemeMode, string> = {
  dark: 'Dark',
  light: 'Light',
  amoled: 'AMOLED',
  system: 'System',
};

export const designTokens = {
  colors: {
    brand: '#15D1C2',
    brandStrong: '#0E7C86',
    success: '#10B981',
    warning: '#FDBA2D',
    danger: '#EF4444',
    info: '#3B82F6',
  },
  spacing: {
    0: '0px',
    1: '4px',
    2: '8px',
    3: '12px',
    4: '16px',
    5: '20px',
    6: '24px',
    7: '32px',
    8: '40px',
    9: '48px',
    10: '64px',
  },
  radius: {
    sm: '4px',
    md: '8px',
    lg: '12px',
    xl: '16px',
    max: '999px',
  },
  motion: {
    fast: '150ms ease-out',
    standard: '200ms ease-out',
    deliberate: '300ms ease-out',
  },
} as const;
