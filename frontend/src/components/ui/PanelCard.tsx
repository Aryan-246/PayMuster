interface PanelCardProps {
  title: string;
  subtitle: string;
  children: React.ReactNode;
}

export function PanelCard({ title, subtitle, children }: PanelCardProps) {
  const { t } = useI18n();

  return (
    <section className="rounded-pm-xl border border-pm-border bg-pm-surface p-pm-5 shadow-pm-3">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm font-semibold text-pm-text-primary">{title}</p>
          <p className="mt-1 text-sm text-pm-text-secondary">{subtitle}</p>
        </div>
        <button className="rounded-pm-max border border-pm-border px-3 py-1.5 text-sm text-pm-text-secondary transition duration-pm-fast hover:border-pm-brand/50 hover:text-pm-text-primary">
          {t('common.view')}
        </button>
      </div>
      <div className="mt-4">{children}</div>
    </section>
  );
}
import { useI18n } from '../../i18n/I18nProvider';
