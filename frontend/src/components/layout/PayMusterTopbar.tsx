import { ThemeSwitcher } from '../../theme/ThemeSwitcher';
import { LanguageSwitcher } from '../../i18n/LanguageSwitcher';
import { useI18n } from '../../i18n/I18nProvider';
import { CompanySwitcher } from './CompanySwitcher';
import { MobileNavDrawer } from './MobileNavDrawer';
import type { AuthSession } from '../../lib/auth-session';

// Greeting follows the viewer's actual local time — no hardcoded time of day.
function greetingKey(hour: number): string {
  if (hour < 12) return 'topbar.goodMorning';
  if (hour < 17) return 'topbar.goodAfternoon';
  return 'topbar.goodEvening';
}

export function PayMusterTopbar({ session }: { session: AuthSession }) {
  const { t } = useI18n();

  return (
    <header className="flex flex-wrap items-center justify-between gap-pm-4 rounded-pm-xl border border-pm-border bg-pm-surface p-pm-4 shadow-pm-4">
      <div>
        <p className="text-sm font-medium text-pm-brand">{t(greetingKey(new Date().getHours()))}</p>
        <h1 className="text-xl font-semibold text-pm-text-primary">{t('topbar.controlCenter')}</h1>
      </div>
      <div className="flex items-center gap-pm-3 md:gap-pm-4">
        <MobileNavDrawer session={session} />
        <CompanySwitcher session={session} />
        <img src="/paymuster_logo.png" alt="PayMuster" className="hidden h-8 w-8 md:block" />
        <ThemeSwitcher />
        <LanguageSwitcher />
      </div>
    </header>
  );
}
