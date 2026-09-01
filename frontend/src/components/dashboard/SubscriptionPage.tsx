import { useQuery } from '@tanstack/react-query';
import { useI18n } from '../../i18n/I18nProvider';
import { authenticatedGetJson } from '../../lib/api';
import { hasPermission } from '../../lib/permissions';
import type { AuthSession } from '../../lib/auth-session';
import { GlassPanel } from '../ui/GlassPanel';
import { LoadingState } from '../ui/LoadingState';
import { BrandButton } from '../ui/BrandButton';
import { useActiveCompany } from '../../lib/active-company';

// Mirrors subscription-state.controller.getSubscriptionState's data shape —
// GET /api/v1/subscription/state (requireAuth + COMPANY tenant scope server-side).
// enforcementEnabled is only present when the viewer holds manage_system or
// manage_billing — its absence is itself information, not an error.
interface SubscriptionState {
  subscription: {
    id: string;
    status: string;
    currentPeriodStart: string;
    currentPeriodEnd: string;
    trialEndsAt: string | null;
    cancelAtPeriodEnd: boolean;
    unlimitedAccess: boolean;
    plan: { code: string; name: string; interval: string } | null;
  } | null;
  effectiveAccess: {
    allowed: boolean;
    unlimited: boolean;
    limit: number | null;
    source: string;
  };
  enforcementEnabled?: boolean;
}

function formatDate(value: string | null | undefined): string {
  if (!value) return '—';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? '—' : date.toLocaleDateString();
}

function statusTone(status: string): string {
  if (status === 'ACTIVE' || status === 'TRIALING') return 'bg-pm-success/10 text-pm-success';
  if (status === 'PAST_DUE') return 'bg-pm-danger/10 text-pm-danger';
  if (status === 'EXPIRED' || status === 'CANCELED') return 'bg-pm-danger/10 text-pm-danger';
  return 'bg-pm-warning/10 text-pm-warning';
}

export function SubscriptionPage({ session }: { session: AuthSession }) {
  const { t } = useI18n();
  const { activeOrgId } = useActiveCompany();

  const stateQuery = useQuery({
    queryKey: ['subscription-state', activeOrgId],
    queryFn: () =>
      authenticatedGetJson<{ success: boolean; data: SubscriptionState }>('/api/v1/subscription/state', session.accessToken, {
        'x-company-id': activeOrgId,
      }),
    enabled: Boolean(activeOrgId),
  });

  const state = stateQuery.data?.data;
  const canSeeSwitch = hasPermission(session.user.role, 'manage_system') || hasPermission(session.user.role, 'manage_billing');

  return (
    <div className="space-y-pm-4">
      <GlassPanel>
        <p className="text-[11px] uppercase tracking-[0.34em] text-pm-brand">{t('subscription.supplyTitle')}</p>
        <h2 className="mt-pm-2 text-2xl font-semibold tracking-tight text-pm-text-primary">{t('subscription.title')}</h2>
        <p className="mt-pm-3 text-sm text-pm-text-secondary">{t('subscription.description')}</p>
      </GlassPanel>

      {stateQuery.isPending ? (
        <LoadingState />
      ) : stateQuery.isError ? (
        <GlassPanel>
          <p className="text-sm font-semibold text-pm-text-primary">{t('subscription.loadError')}</p>
          <div className="mt-pm-4">
            <BrandButton tone="secondary" onClick={() => void stateQuery.refetch()}>
              {t('common.retry')}
            </BrandButton>
          </div>
        </GlassPanel>
      ) : state ? (
        <>
          {canSeeSwitch && state.enforcementEnabled !== undefined && (
            <GlassPanel>
              <p className="text-sm font-semibold text-pm-text-primary">{t('subscription.enforcement')}</p>
              <p className="mt-pm-2 text-sm text-pm-text-secondary">
                {state.enforcementEnabled
                  ? t('subscription.enforcementOn')
                  : t('subscription.enforcementOff')}
              </p>
              <div className={`mt-pm-3 inline-flex rounded-pm-max px-3 py-1 text-sm font-medium ${state.enforcementEnabled ? 'bg-pm-success/10 text-pm-success' : 'bg-pm-warning/10 text-pm-warning'}`}>
                {state.enforcementEnabled ? t('subscription.on') : t('subscription.paused')}
              </div>
            </GlassPanel>
          )}

          <GlassPanel>
            <p className="text-sm font-semibold text-pm-text-primary">{t('subscription.current')}</p>
            {state.subscription ? (
              <div className="mt-pm-4 space-y-pm-3">
                <div className="flex justify-between text-sm">
                  <span className="text-pm-text-secondary">{t('subscription.plan')}</span>
                  <span className="font-medium text-pm-text-primary">{state.subscription.plan?.name ?? state.subscription.plan?.code ?? '—'}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-pm-text-secondary">{t('admin.status')}</span>
                  <span className={`rounded-pm-max px-2.5 py-1 text-xs font-medium ${statusTone(state.subscription.status)}`}>
                    {state.subscription.status}
                  </span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-pm-text-secondary">{t('subscription.period')}</span>
                  <span className="font-medium text-pm-text-primary">
                    {formatDate(state.subscription.currentPeriodStart)} – {formatDate(state.subscription.currentPeriodEnd)}
                  </span>
                </div>
                {state.subscription.trialEndsAt && (
                  <div className="flex justify-between text-sm">
                    <span className="text-pm-text-secondary">{t('subscription.trialEnds')}</span>
                    <span className="font-medium text-pm-text-primary">{formatDate(state.subscription.trialEndsAt)}</span>
                  </div>
                )}
                {state.subscription.unlimitedAccess && (
                  <div className="flex justify-between text-sm">
                    <span className="text-pm-text-secondary">{t('subscription.unlimitedAccess')}</span>
                    <span className="font-medium text-pm-success">{t('subscription.granted')}</span>
                  </div>
                )}
              </div>
            ) : (
              <div className="mt-pm-4 rounded-pm-lg border border-dashed border-pm-border bg-pm-raised p-pm-5 text-center">
                <p className="text-sm text-pm-text-secondary">{t('subscription.none')}</p>
              </div>
            )}
          </GlassPanel>

          <GlassPanel>
            <p className="text-sm font-semibold text-pm-text-primary">{t('subscription.effectiveAccess')}</p>
            <div className="mt-pm-4 space-y-pm-3">
              <div className="flex justify-between text-sm">
                <span className="text-pm-text-secondary">{t('subscription.mailFeature')}</span>
                <span className="font-medium text-pm-text-primary">
                  {state.effectiveAccess.unlimited
                    ? t('mail.unlimited')
                    : `${state.effectiveAccess.limit ?? 0}/${t('subscription.perMonth')}`}
                </span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-pm-text-secondary">{t('subscription.source')}</span>
                <span className="font-medium text-pm-text-primary">{state.effectiveAccess.source}</span>
              </div>
            </div>
          </GlassPanel>
        </>
      ) : null}
    </div>
  );
}
