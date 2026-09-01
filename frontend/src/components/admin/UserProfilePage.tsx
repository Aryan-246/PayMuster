import { useState } from 'react';
import { useParams } from 'react-router-dom';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useI18n } from '../../i18n/I18nProvider';
import { authenticatedGetJson, authenticatedPostJson, ApiError } from '../../lib/api';
import type { AuthSession } from '../../lib/auth-session';
import { GlassPanel } from '../ui/GlassPanel';
import { LoadingState } from '../ui/LoadingState';
import { BrandButton } from '../ui/BrandButton';
import { ConfirmDialog } from '../ui/ConfirmDialog';

type AdminAction = 'SUSPEND' | 'UNSUSPEND' | 'RESET_PASSWORD';

const CONFIRM_COPY: Record<'SUSPEND' | 'RESET_PASSWORD', { title: string; description: string; confirm: string }> = {
  SUSPEND: {
    title: 'Suspend this account?',
    description: 'The user will immediately lose access to PayMuster until reactivated. Their data and history stay intact.',
    confirm: 'Suspend',
  },
  RESET_PASSWORD: {
    title: 'Reset this password?',
    description: 'A password reset will be triggered for this account. The user must complete it before signing in again.',
    confirm: 'Reset password',
  },
};

// Mirrors adminService.getUserById's returned user shape —
// GET /api/v1/admin/users/:id (manage_system = SUPER_ADMIN-only server-side).
interface AdminUserProfile {
  id: string;
  publicId: string | null;
  email: string | null;
  phone: string | null;
  name: string;
  role: string;
  status: string;
  isDisabled: boolean;
  emailVerified: boolean;
  createdAt: string;
  lastLoginAt: string | null;
  org: { id: string; name: string; publicId: string | null; status: string } | null;
}

interface AdminUserEnvelope {
  success: boolean;
  data: { user: AdminUserProfile };
  meta: { requestId: string };
}

function statusTone(status: string, isDisabled: boolean): string {
  if (isDisabled || status === 'SUSPENDED' || status === 'BLOCKED') {
    return 'bg-pm-danger/10 text-pm-danger';
  }
  if (status === 'VERIFIED') return 'bg-pm-success/10 text-pm-success';
  if (status === 'PENDING') return 'bg-pm-warning/10 text-pm-warning';
  return 'bg-pm-raised text-pm-text-secondary';
}

export function UserProfilePage({ session }: { session: AuthSession }) {
  const { t } = useI18n();
  const { id } = useParams<{ id: string }>();
  const queryClient = useQueryClient();
  const [actionMessage, setActionMessage] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [acting, setActing] = useState(false);
  // Destructive/impactful actions ask for explicit confirmation before firing.
  const [confirming, setConfirming] = useState<'SUSPEND' | 'RESET_PASSWORD' | null>(null);

  const profileQuery = useQuery({
    queryKey: ['admin-user', id],
    queryFn: () => authenticatedGetJson<AdminUserEnvelope>(`/api/v1/admin/users/${id}`, session.accessToken),
    enabled: Boolean(id),
  });

  const profile = profileQuery.data?.data.user;

  const handleAction = async (action: AdminAction) => {
    if (!id) return;
    setActing(true);
    setActionMessage(null);
    setActionError(null);
    try {
      if (action === 'RESET_PASSWORD') {
        await authenticatedPostJson(`/api/v1/admin/users/${id}/reset-password`, session.accessToken, {});
      } else {
        await authenticatedPostJson(`/api/v1/admin/users/${id}/action`, session.accessToken, { action });
      }
      setActionMessage(`${t('admin.actionSuccess')}: ${action.toLowerCase()}`);
      // Authoritative refresh — the profile re-renders from the real server
      // state after the action, never from locally patched fields.
      await queryClient.invalidateQueries({ queryKey: ['admin-user', id] });
    } catch (error) {
      setActionError(error instanceof ApiError ? error.message : `${t('admin.actionFailed')}: ${action.toLowerCase()}`);
    } finally {
      setActing(false);
      setConfirming(null);
    }
  };

  if (profileQuery.isPending) {
    return <LoadingState />;
  }

  if (profileQuery.isError || !profile) {
    return (
      <GlassPanel>
        <p className="text-sm font-semibold text-pm-text-primary">{t('admin.profileLoadError')}</p>
        <div className="mt-pm-4">
          <BrandButton tone="secondary" onClick={() => void profileQuery.refetch()}>
            {t('common.retry')}
          </BrandButton>
        </div>
      </GlassPanel>
    );
  }

  return (
    <div className="space-y-pm-4">
      <GlassPanel>
        <p className="text-[11px] uppercase tracking-[0.34em] text-pm-brand">{t('admin.userProfile')}</p>
        <h2 className="mt-pm-2 text-2xl font-semibold tracking-tight text-pm-text-primary">{t('admin.userProfileTitle')}</h2>
      </GlassPanel>

      <section className="grid gap-pm-4 md:grid-cols-2">
        <GlassPanel>
          <p className="text-sm font-semibold text-pm-text-primary">{t('admin.userDetails')}</p>
          <div className="mt-pm-4 space-y-pm-3">
            <div className="flex justify-between text-sm">
              <span className="text-pm-text-secondary">{t('admin.name')}</span>
              <span className="font-medium text-pm-text-primary">{profile.name}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-pm-text-secondary">{t('admin.email')}</span>
              <span className="font-medium text-pm-text-primary">{profile.email ?? '—'}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-pm-text-secondary">{t('admin.publicId')}</span>
              <span className="font-mono text-sm font-medium text-pm-brand">{profile.publicId ?? '—'}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-pm-text-secondary">{t('admin.role')}</span>
              <span className="font-medium text-pm-text-primary">{profile.role}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-pm-text-secondary">{t('admin.status')}</span>
              <span className={`rounded-pm-max px-2.5 py-1 text-xs font-medium ${statusTone(profile.status, profile.isDisabled)}`}>
                {profile.isDisabled ? 'BLOCKED' : profile.status}
              </span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-pm-text-secondary">{t('admin.lastLogin')}</span>
              <span className="font-medium text-pm-text-primary">
                {profile.lastLoginAt ? new Date(profile.lastLoginAt).toLocaleString() : '—'}
              </span>
            </div>
            {profile.org && (
              <div className="flex justify-between text-sm">
                <span className="text-pm-text-secondary">{t('admin.company')}</span>
                <span className="font-medium text-pm-text-primary">{profile.org.name}</span>
              </div>
            )}
          </div>
        </GlassPanel>

        <GlassPanel>
          <p className="text-sm font-semibold text-pm-text-primary">{t('admin.actions')}</p>
          <p className="mt-pm-2 text-sm text-pm-text-secondary">{t('admin.actionsDescription')}</p>
          <div className="mt-pm-5 flex flex-wrap gap-pm-3">
            <BrandButton disabled={acting} onClick={() => void handleAction('UNSUSPEND')}>
              {t('admin.activate')}
            </BrandButton>
            <BrandButton tone="secondary" disabled={acting} onClick={() => setConfirming('SUSPEND')}>
              {t('admin.suspend')}
            </BrandButton>
            <BrandButton tone="secondary" disabled={acting} onClick={() => setConfirming('RESET_PASSWORD')}>
              {t('admin.resetPassword')}
            </BrandButton>
          </div>
          {actionMessage && (
            <div className="mt-pm-4 rounded-pm-lg border border-pm-border bg-pm-raised p-pm-3">
              <p className="text-sm text-pm-text-primary">{actionMessage}</p>
            </div>
          )}
          {actionError && (
            <div className="mt-pm-4 rounded-pm-lg border border-pm-danger/30 bg-pm-danger/10 p-pm-3">
              <p className="text-sm text-pm-danger">{actionError}</p>
            </div>
          )}
        </GlassPanel>
      </section>

      {confirming && (
        <ConfirmDialog
          open
          title={CONFIRM_COPY[confirming].title}
          description={CONFIRM_COPY[confirming].description}
          confirmLabel={CONFIRM_COPY[confirming].confirm}
          cancelLabel="Cancel"
          destructive={confirming === 'SUSPEND'}
          busy={acting}
          onConfirm={() => void handleAction(confirming)}
          onCancel={() => setConfirming(null)}
        />
      )}
    </div>
  );
}
