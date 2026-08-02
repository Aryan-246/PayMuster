import { useI18n } from '../../i18n/I18nProvider';
import { BrandButton } from '../ui/BrandButton';
import { GlassPanel } from '../ui/GlassPanel';
import { PayMusterSidebar } from './PayMusterSidebar';
import { PayMusterTopbar } from './PayMusterTopbar';

const metrics = [
  ['metric.workersPresent', '184', 'metric.pending'],
  ['metric.payrollDue', '₹42.8k', 'metric.pending'],
  ['metric.sitesHealthy', '17', 'metric.alerts'],
  ['metric.expenses', '₹8.4k', 'metric.today'],
] as const;

const activity = [
  ['08:30', 'dashboard.attendanceSynced', 'dashboard.crewCheckedIn'],
  ['10:15', 'dashboard.approvalPending', 'dashboard.materialRequest'],
  ['14:00', 'dashboard.payrollReview', 'dashboard.weeklyRunReady'],
] as const;

export function PayMusterDashboard() {
  const { t } = useI18n();

  return (
    <div className="min-h-screen bg-pm-background px-pm-4 py-pm-4 text-pm-text-primary md:px-pm-6 lg:px-pm-8 lg:py-pm-6">
      <div className="mx-auto flex max-w-7xl gap-pm-4">
        <PayMusterSidebar />
        <main className="flex-1 space-y-pm-4">
          <PayMusterTopbar />
          <section className="grid gap-pm-4 xl:grid-cols-[1.4fr_0.8fr]">
            <GlassPanel>
              <p className="text-[11px] uppercase tracking-[0.34em] text-pm-brand">{t('dashboard.operatingSystem')}</p>
              <h2 className="mt-pm-2 max-w-2xl text-3xl font-semibold tracking-tight text-pm-text-primary">{t('dashboard.heroTitle')}</h2>
              <p className="mt-pm-3 max-w-xl text-sm leading-6 text-pm-text-secondary">{t('dashboard.heroDescription')}</p>
              <div className="mt-pm-5 flex flex-wrap gap-pm-3">
                <BrandButton>{t('dashboard.reviewToday')}</BrandButton>
                <BrandButton tone="secondary">{t('dashboard.openAi')}</BrandButton>
              </div>
            </GlassPanel>
            <GlassPanel>
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-semibold text-pm-text-primary">{t('dashboard.siteHealth')}</p>
                  <p className="text-sm text-pm-text-secondary">{t('dashboard.liveSnapshot')}</p>
                </div>
                <div className="rounded-pm-max bg-pm-success/10 px-3 py-1 text-sm font-medium text-pm-success">{t('dashboard.stable')}</div>
              </div>
              <div className="mt-pm-5 space-y-pm-3">
                {[
                  ['dashboard.crewCommute', '12 min late'],
                  ['dashboard.materials', '4 deliveries on track'],
                  ['dashboard.equipment', '3 checked in'],
                ].map(([label, value]) => (
                  <div key={label} className="rounded-pm-lg border border-pm-border bg-pm-raised p-pm-3">
                    <p className="text-sm text-pm-text-secondary">{t(label)}</p>
                    <p className="mt-1 font-medium text-pm-text-primary">{value}</p>
                  </div>
                ))}
              </div>
            </GlassPanel>
          </section>
          <section className="grid gap-pm-4 md:grid-cols-2 xl:grid-cols-4">
            {metrics.map(([label, value, trend]) => (
              <GlassPanel key={label}>
                <p className="text-sm text-pm-text-secondary">{t(label)}</p>
                <div className="mt-pm-4 flex items-end justify-between">
                  <p className="text-2xl font-semibold text-pm-text-primary">{value}</p>
                  <span className="rounded-pm-max bg-pm-brand/10 px-2.5 py-1 text-xs font-medium text-pm-brand">{t(trend)}</span>
                </div>
              </GlassPanel>
            ))}
          </section>
          <section className="grid gap-pm-4 xl:grid-cols-[1.15fr_0.85fr]">
            <GlassPanel>
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-semibold text-pm-text-primary">{t('dashboard.todayWorkforce')}</p>
                  <p className="text-sm text-pm-text-secondary">{t('dashboard.timelineDescription')}</p>
                </div>
                <button className="rounded-pm-max border border-pm-border bg-pm-raised px-3 py-1.5 text-sm text-pm-text-secondary">{t('dashboard.openTimeline')}</button>
              </div>
              <div className="mt-pm-5 space-y-pm-3">
                {activity.map(([time, title, details]) => (
                  <div key={title} className="flex items-start gap-pm-3 rounded-pm-lg border border-pm-border bg-pm-raised p-pm-3">
                    <div className="mt-0.5 h-2.5 w-2.5 rounded-pm-max bg-pm-brand" />
                    <div>
                      <p className="text-xs uppercase tracking-[0.28em] text-pm-text-tertiary">{time}</p>
                      <p className="text-sm font-semibold text-pm-text-primary">{t(title)}</p>
                      <p className="mt-1 text-sm text-pm-text-secondary">{t(details)}</p>
                    </div>
                  </div>
                ))}
              </div>
            </GlassPanel>
            <GlassPanel>
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-semibold text-pm-text-primary">{t('dashboard.aiInsight')}</p>
                  <p className="text-sm text-pm-text-secondary">{t('dashboard.aiDescription')}</p>
                </div>
                <div className="rounded-pm-max bg-pm-info/10 px-3 py-1 text-sm font-medium text-pm-info">{t('dashboard.live')}</div>
              </div>
              <div className="mt-pm-5 rounded-pm-xl border border-pm-info/20 bg-pm-info/10 p-pm-4">
                <p className="text-sm text-pm-text-secondary">{t('dashboard.aiMessage')}</p>
              </div>
            </GlassPanel>
          </section>
        </main>
      </div>
    </div>
  );
}
