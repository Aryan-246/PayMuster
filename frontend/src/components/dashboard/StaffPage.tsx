import { useI18n } from '../../i18n/I18nProvider';
import { GlassPanel } from '../ui/GlassPanel';
import { LoadingState } from '../ui/LoadingState';
import { DataTable } from '../ui/DataTable';
import { BrandButton } from '../ui/BrandButton';
import { useQuery } from '@tanstack/react-query';
import { authenticatedGetJson } from '../../lib/api';
import type { AuthSession } from '../../lib/auth-session';
import { useActiveCompany } from '../../lib/active-company';

// Mirrors the STAFF_SUMMARY_SELECT returned by GET /api/v1/staff — the roster
// fields only. Sensitive bank/payment fields are intentionally not part of this
// response, so there is nothing sensitive to render here.
interface StaffSummary {
  id: string;
  publicId: string | null;
  firstName: string;
  lastName: string;
  phone: string | null;
  email: string | null;
  workerType: string;
  status: string;
  joinDate: string | null;
  createdAt: string;
  updatedAt: string;
}

interface StaffListEnvelope {
  success: boolean;
  data: StaffSummary[];
  meta: { requestId: string; total: number; page: number; totalPages: number };
}

export function StaffPage({ session }: { session: AuthSession }) {
  const { t } = useI18n();
  const { activeOrgId } = useActiveCompany();

  const staffQuery = useQuery({
    queryKey: ['staff-directory', activeOrgId],
    queryFn: () =>
      authenticatedGetJson<StaffListEnvelope>('/api/v1/staff', session.accessToken, {
        'x-company-id': activeOrgId,
      }),
    enabled: Boolean(activeOrgId),
  });

  const staff = staffQuery.data?.data ?? [];
  // `total` is the authoritative count from the server; the rendered rows are
  // just the first page, so we show total rather than a page-limited tally.
  const total = staffQuery.data?.meta.total ?? 0;

  return (
    <div className="space-y-pm-4">
      <GlassPanel>
        <p className="text-[11px] uppercase tracking-[0.34em] text-pm-brand">{t('nav.workforce')}</p>
        <h2 className="mt-pm-2 text-2xl font-semibold tracking-tight text-pm-text-primary">{t('staff.title')}</h2>
        <p className="mt-pm-3 text-sm text-pm-text-secondary">{t('staff.description')}</p>
      </GlassPanel>

      {staffQuery.isPending ? (
        <LoadingState />
      ) : staffQuery.isError ? (
        <GlassPanel>
          <p className="text-sm font-semibold text-pm-text-primary">{t('staff.loadError')}</p>
          <div className="mt-pm-4">
            <BrandButton tone="secondary" onClick={() => void staffQuery.refetch()}>
              {t('common.retry')}
            </BrandButton>
          </div>
        </GlassPanel>
      ) : staff.length === 0 ? (
        <GlassPanel>
          <div className="rounded-pm-lg border border-dashed border-pm-border bg-pm-raised p-pm-5 text-center">
            <p className="text-sm text-pm-text-secondary">{t('staff.empty')}</p>
          </div>
        </GlassPanel>
      ) : (
        <GlassPanel>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-semibold text-pm-text-primary">{t('staff.title')}</p>
              <p className="text-sm text-pm-text-secondary">{t('staff.onRecord')}: {total}</p>
            </div>
          </div>
          <div className="mt-pm-4">
            <DataTable
              rows={staff.map((member) => ({
                id: member.id,
                name: `${member.firstName} ${member.lastName}`.trim(),
                status: member.status,
                value: member.workerType,
              }))}
            />
          </div>
        </GlassPanel>
      )}
    </div>
  );
}
