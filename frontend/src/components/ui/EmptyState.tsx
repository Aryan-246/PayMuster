interface EmptyStateProps {
  title: string;
  description: string;
}

export function EmptyState({ title, description }: EmptyStateProps) {
  const { t } = useI18n();

  return (
    <div className="rounded-pm-xl border border-dashed border-pm-border bg-pm-surface p-pm-8 text-center">
      <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-pm-lg bg-pm-brand/10 text-2xl text-pm-brand">✦</div>
      <p className="mt-4 text-lg font-semibold text-pm-text-primary">{title}</p>
      <p className="mt-2 text-sm text-pm-text-secondary">{description}</p>
      <button className="mt-5 rounded-pm-md bg-pm-brand px-4 py-2 text-sm font-semibold text-pm-background transition hover:opacity-90">
        {t('common.createFirstItem')}
      </button>
    </div>
  );
}
import { useI18n } from '../../i18n/I18nProvider';
