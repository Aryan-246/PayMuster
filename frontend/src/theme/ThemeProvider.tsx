import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import type { PropsWithChildren } from 'react';
import type { ThemeMode } from './tokens';

const storageKey = 'paymuster.theme-mode';
const defaultTheme: ThemeMode = 'dark';

interface ThemeContextValue {
  mode: ThemeMode;
  resolvedMode: Exclude<ThemeMode, 'system'>;
  setMode: (mode: ThemeMode) => void;
}

const ThemeContext = createContext<ThemeContextValue | undefined>(undefined);

function readStoredMode(): ThemeMode {
  if (typeof window === 'undefined') return defaultTheme;

  const storedMode = window.localStorage.getItem(storageKey);
  return storedMode === 'dark' || storedMode === 'light' || storedMode === 'amoled' || storedMode === 'system'
    ? storedMode
    : defaultTheme;
}

function getSystemMode(): Exclude<ThemeMode, 'system'> {
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

export function ThemeProvider({ children }: PropsWithChildren) {
  const [mode, setModeState] = useState<ThemeMode>(readStoredMode);
  const [systemMode, setSystemMode] = useState<Exclude<ThemeMode, 'system'>>(() =>
    typeof window === 'undefined' ? 'dark' : getSystemMode(),
  );

  const resolvedMode = mode === 'system' ? systemMode : mode;

  useEffect(() => {
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    const handleChange = () => setSystemMode(getSystemMode());

    handleChange();
    mediaQuery.addEventListener('change', handleChange);
    return () => mediaQuery.removeEventListener('change', handleChange);
  }, []);

  useEffect(() => {
    document.documentElement.dataset.theme = resolvedMode;
    document.documentElement.style.colorScheme = resolvedMode === 'light' ? 'light' : 'dark';
  }, [resolvedMode]);

  const setMode = (nextMode: ThemeMode) => {
    setModeState(nextMode);
    window.localStorage.setItem(storageKey, nextMode);
  };

  const value = useMemo(() => ({ mode, resolvedMode, setMode }), [mode, resolvedMode]);

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme() {
  const context = useContext(ThemeContext);
  if (!context) throw new Error('useTheme must be used within ThemeProvider');
  return context;
}
