import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useI18n } from '../../i18n/I18nProvider';
import { authenticatedGetJson } from '../../lib/api';
import type { AuthSession } from '../../lib/auth-session';
import { GlassPanel } from '../ui/GlassPanel';
import { LoadingState } from '../ui/LoadingState';
import { DataTable } from '../ui/DataTable';
import { BrandButton } from '../ui/BrandButton';
import { useActiveCompany } from '../../lib/active-company';

// Mirrors payrollRepository.getPayRuns' include shape — the fields of
// GET /api/v1/payroll only (behind view_payroll + COMPANY tenant scope
// server-side; orgId travels in x-company-id, never in the URL).
interface PayRunApiRecord {
  id: string;
  publicId: string | null;
  totalAmount: string;
  approvedAt: string | null;
  createdAt: string;
  payCycle: { startDate: string; endDate: string; status: string } | null;
  payRunItems: {
    id: string;
    netPay: string;
    staff: { publicId: string | null; firstName: string; lastName: string } | null;
  }[];
}

interface PayrollEnvelope {
  success: boolean;
  data: PayRunApiRecord[];
  meta: { requestId: string };
}

// Decimal totals arrive as strings to preserve precision; format for display only.
function formatInr(value: string): string {
  const amount = Number(value);
  if (!Number.isFinite(amount)) return '₹0';
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0,
  }).format(amount);
}

function formatPeriod(start: string | undefined, end: string | undefined): string {
  const startDate = start ? new Date(start) : null;
  const endDate = end ? new Date(end) : null;
  const validStart = startDate && !Number.isNaN(startDate.getTime());
  const validEnd = endDate && !Number.isNaN(endDate.getTime());
  if (!validStart || !validEnd) return '—';
  return `${startDate!.toLocaleDateString(undefined, { month: 'short', year: 'numeric' })} · ${startDate!.toLocaleDateString()} – ${endDate!.toLocaleDateString()}`;
}

export function PayrollPage({ session }: { session: AuthSession }) {
  const { t } = useI18n();
  const { activeOrgId } = useActiveCompany();

  const payrollQuery = useQuery({
    queryKey: ['payroll-runs', activeOrgId],
    queryFn: () =>
      authenticatedGetJson<PayrollEnvelope>('/api/v1/payroll', session.accessToken, {
        'x-company-id': activeOrgId,
      }),
    enabled: Boolean(activeOrgId),
  });

  const payRuns = useMemo(() => payrollQuery.data?.data ?? [], [payrollQuery.data]);

  // Tallies derive from the real response — a pay run counts as approved only
  // when approvedAt is set (PayRun has no status column).
  const approvedCount = payRuns.filter((run) => run.approvedAt !== null).length;
  const pendingCount = payRuns.length - approvedCount;
  const totalPay = payRuns.reduce((sum, run) => sum + Number(run.totalAmount), 0);

  return (
    <div className="space-y-pm-4">
      <GlassPanel>
        <p className="text-[11px] uppercase tracking-[0.34em] text-pm-brand">{t('dashboard.payroll')}</p>
        <h2 className="mt-pm-2 text-2xl font-semibold tracking-tight text-pm-text-primary">{t('admin.payrollRecords')}</h2>
        <p className="mt-pm-3 text-sm text-pm-text-secondary">{t('admin.payrollDescription')}</p>
      </GlassPanel>

      <section className="grid gap-pm-4 md:grid-cols-3">
        <GlassPanel>
          <p className="text-sm text-pm-text-secondary">{t('admin.totalPayroll')}</p>
          <p className="mt-pm-2 text-2xl font-semibold text-pm-text-primary">
            {formatInr(String(Number.isFinite(totalPay) ? totalPay : 0))}
          </p>
        </GlassPanel>
        <GlassPanel>
          <p className="text-sm text-pm-text-secondary">{t('payroll.approved')}</p>
          <p className="mt-pm-2 text-2xl font-semibold text-pm-success">{approvedCount}</p>
        </GlassPanel>
        <GlassPanel>
          <p className="text-sm text-pm-text-secondary">{t('admin.pending')}</p>
          <p className="mt-pm-2 text-2xl font-semibold text-pm-warning">{pendingCount}</p>
        </GlassPanel>
      </section>

      {payrollQuery.isPending ? (
        <LoadingState />
      ) : payrollQuery.isError ? (
        <GlassPanel>
          <p className="text-sm font-semibold text-pm-text-primary">{t('payroll.loadError')}</p>
          <div className="mt-pm-4">
            <BrandButton tone="secondary" onClick={() => void payrollQuery.refetch()}>
              {t('common.retry')}
            </BrandButton>
          </div>
        </GlassPanel>
      ) : payRuns.length === 0 ? (
        <GlassPanel>
          <div className="rounded-pm-lg border border-dashed border-pm-border bg-pm-raised p-pm-5 text-center">
            <p className="text-sm text-pm-text-secondary">{t('payroll.empty')}</p>
          </div>
        </GlassPanel>
      ) : (
        <GlassPanel>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-semibold text-pm-text-primary">{t('admin.payrollList')}</p>
              <p className="text-sm text-pm-text-secondary">{t('admin.payrollListDescription')}</p>
            </div>
          </div>
          <div className="mt-pm-4">
            <DataTable
              rows={payRuns.map((run) => ({
                id: run.id,
                name: run.publicId ?? formatPeriod(run.payCycle?.startDate, run.payCycle?.endDate),
                status: run.approvedAt ? 'approved' : 'pending',
                statusLabel: run.approvedAt ? t('payroll.approved') : t('admin.pending'),
                value: `${formatInr(run.totalAmount)} · ${run.payRunItems.length} ${t('payroll.items')}`,
              }))}
            />
          </div>
        </GlassPanel>
      )}
    </div>
  );
}
