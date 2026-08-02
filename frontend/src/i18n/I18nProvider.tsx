import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import type { PropsWithChildren } from 'react';
import { languageLabels, messages, type Language } from './messages';

const storageKey = 'paymuster.language';

interface I18nContextValue {
  language: Language;
  languages: readonly Language[];
  languageLabels: typeof languageLabels;
  setLanguage: (language: Language) => void;
  t: (key: string) => string;
}

const I18nContext = createContext<I18nContextValue | undefined>(undefined);

function readStoredLanguage(): Language {
  const stored = typeof window === 'undefined' ? null : window.localStorage.getItem(storageKey);
  return stored === 'hi' || stored === 'pa' || stored === 'en' ? stored : 'en';
}

export function I18nProvider({ children }: PropsWithChildren) {
  const [language, setLanguageState] = useState<Language>(readStoredLanguage);
  const setLanguage = (nextLanguage: Language) => {
    setLanguageState(nextLanguage);
    window.localStorage.setItem(storageKey, nextLanguage);
  };
  const value = useMemo(() => ({
    language,
    languages: ['en', 'hi', 'pa'] as const,
    languageLabels,
    setLanguage,
    t: (key: string) => messages[language][key] ?? messages.en[key] ?? key,
  }), [language]);

  useEffect(() => {
    document.documentElement.lang = language === 'hi' ? 'hi-IN' : language === 'pa' ? 'pa-IN' : 'en-IN';
  }, [language]);

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n() {
  const context = useContext(I18nContext);
  if (!context) throw new Error('useI18n must be used within I18nProvider');
  return context;
}
