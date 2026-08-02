import { themeModes } from './tokens';
import { useTheme } from './ThemeProvider';
import { useI18n } from '../i18n/I18nProvider';

export function ThemeSwitcher() {
  const { mode, setMode } = useTheme();
  const { t } = useI18n();

  return (
    <label className="flex min-h-10 items-center gap-2 rounded-pm-md border border-pm-border bg-pm-surface px-pm-3 text-sm text-pm-text-secondary">
      <span className="sr-only">{t('theme.label')}</span>
      <select
        aria-label={t('theme.label')}
        value={mode}
        onChange={(event) => setMode(event.target.value as (typeof themeModes)[number])}
        className="bg-transparent text-pm-text-primary outline-none"
      >
        {themeModes.map((themeMode) => (
          <option key={themeMode} value={themeMode} className="bg-pm-surface text-pm-text-primary">
            {t(`theme.${themeMode}`)}
          </option>
        ))}
      </select>
    </label>
  );
}
