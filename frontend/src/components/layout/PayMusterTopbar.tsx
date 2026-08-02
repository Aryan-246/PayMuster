import { ThemeSwitcher } from '../../theme/ThemeSwitcher';
import { LanguageSwitcher } from '../../i18n/LanguageSwitcher';
import { useI18n } from '../../i18n/I18nProvider';

export function PayMusterTopbar() {
  const { t } = useI18n();

  return (
    <header className="flex flex-wrap items-center justify-between gap-pm-4 rounded-pm-xl border border-pm-border bg-pm-surface p-pm-4 shadow-pm-4">
      <div>
        <p className="text-sm font-medium text-pm-brand">{t('topbar.goodEvening')}</p>
        <h1 className="text-xl font-semibold text-pm-text-primary">{t('topbar.controlCenter')}</h1>
      </div>
      <div className="flex items-center gap-pm-3 md:gap-pm-4">
        <img src="/paymuster_logo.png" alt="PayMuster" className="hidden h-8 w-8 md:block" />
        <ThemeSwitcher />
        <LanguageSwitcher />
        <label className="flex items-center gap-2 rounded-pm-md border border-pm-border bg-pm-background px-3 py-2 text-sm text-pm-text-secondary">
          <span>⌕</span>
          <input aria-label={t('topbar.search')} className="w-40 bg-transparent text-pm-text-primary outline-none placeholder:text-pm-text-tertiary" placeholder={t('topbar.search')} />
        </label>
        <button className="min-h-10 rounded-pm-md border border-pm-brand/20 bg-pm-brand/10 px-pm-4 py-pm-2 text-sm font-medium text-pm-brand transition duration-pm-fast hover:bg-pm-brand/20">
          {t('topbar.sync')}
        </button>
      </div>
    </header>
  );
}
