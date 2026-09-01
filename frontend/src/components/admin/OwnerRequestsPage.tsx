import { useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useI18n } from '../../i18n/I18nProvider';
import { authenticatedGetJson, authenticatedPostJson, ApiError } from '../../lib/api';
import type { AuthSession } from '../../lib/auth-session';
import { GlassPanel } from '../ui/GlassPanel';
import { LoadingState } from '../ui/LoadingState';
import { BrandButton } from '../ui/BrandButton';
import { DataTable } from '../ui/DataTable';
import { ConfirmDialog } from '../ui/ConfirmDialog';

// Mirrors adminService.getOwnerRequests' include shape — GET /api/v1/admin/owner-requests
// (manage_system = SUPER_ADMIN-only server-side).
interface OwnerRequestApiRecord {
  id: string;
  publicId: string | null;
  companyName: string;
  gstin: string | null;
  status: 'PENDING' | 'APPROVED' | 'REJECTED';
  createdAt: string;
  user: {
    publicId: string | null;
    email: string;
    firstName: string | null;
    lastName: string | null;
    role: string;
  } | null;
}

interface OwnerRequestsEnvelope {
  success: boolean;
  data: OwnerRequestApiRecord[];
  meta: { requestId: string };
}

export function OwnerRequestsPage({ session }: { session: AuthSession }) {
  const { t } = useI18n();
  const queryClient = useQueryClient();
  const [actingOn, setActingOn] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  // Rejection is irreversible — it always asks for explicit confirmation.
  const [rejecting, setRejecting] = useState<OwnerRequestApiRecord | null>(null);

  const requestsQuery = useQuery({
    queryKey: ['owner-requests', session.user.publicId],
    queryFn: () => authenticatedGetJson<OwnerRequestsEnvelope>('/api/v1/admin/owner-requests', session.accessToken),
  });

  const requests = requestsQuery.data?.data ?? [];
  const pendingRequests = requests.filter((r) => r.status === 'PENDING');

  const resolveRequest = async (id: string, action: 'approve' | 'reject') => {
    setActingOn(id);
    setActionError(null);
    try {
      if (action === 'approve') {
        await authenticatedPostJson(`/api/v1/admin/owner-requests/${id}/approve`, session.accessToken, {});
      } else {
        await authenticatedPostJson(`/api/v1/admin/owner-requests/${id}/reject`, session.accessToken, {});
      }
      // Authoritative refresh after the mutation — the table re-renders from
      // the real server state, never from locally patched rows.
      await queryClient.invalidateQueries({ queryKey: ['owner-requests'] });
    } catch (error) {
      setActionError(
        error instanceof ApiError ? error.message : `${t('admin.actionFailed')}: ${action}`,
      );
    } finally {
      setActingOn(null);
      setRejecting(null);
    }
  };

  return (
    <div className="space-y-pm-4">
      <GlassPanel>
        <p className="text-[11px] uppercase tracking-[0.34em] text-pm-brand">{t('admin.ownerRequests')}</p>
        <h2 className="mt-pm-2 text-2xl font-semibold tracking-tight text-pm-text-primary">{t('admin.ownerRequestsTitle')}</h2>
        <p className="mt-pm-3 text-sm text-pm-text-secondary">{t('admin.ownerRequestsDescription')}</p>
      </GlassPanel>

      {requestsQuery.isPending ? (
        <LoadingState />
      ) : requestsQuery.isError ? (
        <GlassPanel>
          <p className="text-sm font-semibold text-pm-text-primary">{t('admin.requestsLoadError')}</p>
          <div className="mt-pm-4">
            <BrandButton tone="secondary" onClick={() => void requestsQuery.refetch()}>
              {t('common.retry')}
            </BrandButton>
          </div>
        </GlassPanel>
      ) : (
        <>
          <section className="grid gap-pm-4 md:grid-cols-3">
            <GlassPanel>
              <p className="text-sm text-pm-text-secondary">{t('admin.totalRequests')}</p>
              <p className="mt-pm-2 text-2xl font-semibold text-pm-text-primary">{requests.length}</p>
            </GlassPanel>
            <GlassPanel>
              <p className="text-sm text-pm-text-secondary">{t('admin.pending')}</p>
              <p className="mt-pm-2 text-2xl font-semibold text-pm-warning">{pendingRequests.length}</p>
            </GlassPanel>
            <GlassPanel>
              <p className="text-sm text-pm-text-secondary">{t('admin.approved')}</p>
              <p className="mt-pm-2 text-2xl font-semibold text-pm-success">
                {requests.filter((r) => r.status === 'APPROVED').length}
              </p>
            </GlassPanel>
          </section>

          <GlassPanel>
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-semibold text-pm-text-primary">{t('admin.requestsList')}</p>
                <p className="text-sm text-pm-text-secondary">{t('admin.requestsListDescription')}</p>
              </div>
            </div>
            <div className="mt-pm-4">
              <DataTable
                rows={requests.map((req) => ({
                  id: req.id,
                  name: req.user
                    ? `${req.user.firstName ?? ''} ${req.user.lastName ?? ''}`.trim() || req.user.email
                    : t('attendance.unassigned'),
                  status: req.status.toLowerCase(),
                  statusLabel: req.status === 'PENDING'
                    ? t('admin.pending')
                    : req.status === 'APPROVED'
                      ? t('admin.approved')
                      : t('admin.reject'),
                  value: `${req.companyName}${req.publicId ? ` · ${req.publicId}` : ''}`,
                }))}
              />
            </div>
            {actionError && (
              <div className="mt-pm-4 rounded-pm-lg border border-pm-danger/30 bg-pm-danger/10 p-pm-3">
                <p className="text-sm text-pm-danger">{actionError}</p>
              </div>
            )}
            <div className="mt-pm-4 flex flex-wrap gap-pm-3">
              {pendingRequests.map((req) => (
                <div key={req.id} className="flex items-center gap-pm-3 rounded-pm-lg border border-pm-border bg-pm-raised p-pm-3">
                  <div className="flex-1">
                    <p className="text-sm font-medium text-pm-text-primary">
                      {req.user
                        ? `${req.user.firstName ?? ''} ${req.user.lastName ?? ''}`.trim() || req.user.email
                        : t('attendance.unassigned')}
                    </p>
                    <p className="text-xs text-pm-text-secondary">
                      {req.companyName}
                      {req.publicId ? ` · ${req.publicId}` : ''}
                      {req.user?.email ? ` · ${req.user.email}` : ''}
                    </p>
                  </div>
                  <BrandButton
                    disabled={actingOn === req.id}
                    onClick={() => void resolveRequest(req.id, 'approve')}
                  >
                    {actingOn === req.id ? '…' : t('admin.approve')}
                  </BrandButton>
                  <BrandButton
                    tone="secondary"
                    disabled={actingOn === req.id}
                    onClick={() => setRejecting(req)}
                  >
                    {actingOn === req.id ? '…' : t('admin.reject')}
                  </BrandButton>
                </div>
              ))}
              {pendingRequests.length === 0 && (
                <p className="text-sm text-pm-text-secondary">{t('admin.noPendingRequests')}</p>
              )}
            </div>
          </GlassPanel>
        </>
      )}

      {rejecting && (
        <ConfirmDialog
          open
          title={t('admin.rejectConfirmTitle')}
          description={`${t('admin.rejectConfirmDescription')} ${rejecting.companyName}`}
          confirmLabel={t('admin.reject')}
          cancelLabel={t('admin.cancel')}
          destructive
          busy={actingOn === rejecting.id}
          onConfirm={() => void resolveRequest(rejecting.id, 'reject')}
          onCancel={() => setRejecting(null)}
        />
      )}
    </div>
  );
}
