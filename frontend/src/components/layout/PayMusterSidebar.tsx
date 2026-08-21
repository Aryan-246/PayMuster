import { useI18n } from '../../i18n/I18nProvider';
import { BrandButton } from '../ui/BrandButton';

const items = [
  { key: 'nav.overview', icon: '◉', active: true },
  { key: 'nav.workforce', icon: '◌' },
  { key: 'nav.sites', icon: '◍' },
  { key: 'nav.attendance', icon: '◎' },
  { key: 'nav.payroll', icon: '◈' },
  { key: 'nav.ownerRequests', icon: '◇' },
  { key: 'nav.ai', icon: '✦' },
];

export function PayMusterSidebar() {
  const { t } = useI18n();

  return (
    <aside className="hidden w-[280px] shrink-0 flex-col rounded-pm-xl border border-pm-border bg-pm-surface p-pm-5 shadow-pm-5 xl:flex">
      <div className="flex items-center gap-pm-3">
        <div className="flex h-10 w-10 items-center justify-center rounded-pm-lg bg-pm-brand/10">
          <img src="/paymuster_logo.png" alt="PayMuster logo" className="h-6 w-6 object-contain" />
        </div>
        <div>
          <p className="text-[10px] uppercase tracking-[0.36em] text-pm-brand">PayMuster</p>
          <p className="text-sm font-semibold text-pm-text-primary">{t('nav.workforceOs')}</p>
        </div>
      </div>
      <div className="mt-pm-6 rounded-pm-xl border border-pm-brand/20 bg-pm-brand/10 p-pm-3">
        <p className="text-[11px] uppercase tracking-[0.28em] text-pm-brand">{t('nav.today')}</p>
        <p className="mt-2 text-sm font-medium text-pm-text-primary">97.6% crew readiness</p>
      </div>
      <nav className="mt-pm-6 space-y-pm-2">
        {items.map((item) => (
          <button key={item.key} className={`flex min-h-12 w-full items-center justify-between rounded-pm-md px-pm-3 py-pm-3 text-left text-sm transition duration-pm-fast ${item.active ? 'bg-pm-raised text-pm-text-primary shadow-[inset_3px_0_0_var(--pm-color-primary)]' : 'text-pm-text-secondary hover:bg-pm-raised hover:text-pm-text-primary'}`}>
            <span className="flex items-center gap-pm-3"><span className="text-base">{item.icon}</span>{t(item.key)}</span>
            {item.active ? <span className="text-pm-brand">●</span> : null}
          </button>
        ))}
      </nav>
      <div className="mt-auto rounded-pm-xl border border-pm-border bg-pm-card p-pm-4">
        <p className="text-sm font-semibold text-pm-text-primary">{t('nav.projectPulse')}</p>
        <p className="mt-2 text-sm text-pm-text-secondary">{t('nav.approvalsSummary')}</p>
        <div className="mt-pm-4"><BrandButton tone="secondary">{t('nav.openCommandCenter')}</BrandButton></div>
      </div>
    </aside>
  );
}
