import { useI18n } from './I18nProvider';

export function LanguageSwitcher() {
  const { language, languages, languageLabels, setLanguage, t } = useI18n();

  return (
    <label className="flex min-h-10 items-center gap-2 rounded-pm-md border border-pm-border bg-pm-surface px-pm-3 text-sm text-pm-text-secondary">
      <span className="sr-only">{t('language.label')}</span>
      <select aria-label={t('language.label')} value={language} onChange={(event) => setLanguage(event.target.value as (typeof languages)[number])} className="bg-transparent text-pm-text-primary outline-none">
        {languages.map((option) => <option key={option} value={option} className="bg-pm-surface text-pm-text-primary">{languageLabels[option]}</option>)}
      </select>
    </label>
  );
}
