import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useI18n } from '../../i18n/I18nProvider';
import { authenticatedGetJson } from '../../lib/api';
import type { AuthSession } from '../../lib/auth-session';
import { GlassPanel } from '../ui/GlassPanel';
import { LoadingState } from '../ui/LoadingState';
import { DataTable } from '../ui/DataTable';
import { BrandButton } from '../ui/BrandButton';
import { useActiveCompany } from '../../lib/active-company';

// Mirrors attendanceRepository.getAttendanceRecords' include shape — the roster
// fields of GET /api/v1/attendance only (behind view_attendance + COMPANY
// tenant scope server-side; orgId travels in x-company-id, never in the URL).
interface AttendanceApiRecord {
  id: string;
  date: string;
  status: 'PRESENT' | 'ABSENT' | 'HALF_DAY' | 'LEAVE' | 'HOLIDAY' | 'OVERTIME';
  checkInTime: string | null;
  checkOutTime: string | null;
  overtimeHours: number | null;
  staff: { publicId: string | null; firstName: string; lastName: string } | null;
  site: { publicId: string | null; name: string } | null;
}

interface AttendanceEnvelope {
  success: boolean;
  data: AttendanceApiRecord[];
  meta: { requestId: string };
}

const STATUS_FILTERS = [
  'PRESENT',
  'ABSENT',
  'HALF_DAY',
  'LEAVE',
  'HOLIDAY',
  'OVERTIME',
] as const;

const STATUS_LABEL_KEYS: Record<AttendanceApiRecord['status'], string> = {
  PRESENT: 'admin.present',
  ABSENT: 'admin.absent',
  HALF_DAY: 'attendance.halfDay',
  LEAVE: 'attendance.leave',
  HOLIDAY: 'attendance.holiday',
  OVERTIME: 'attendance.overtime',
};

function formatTime(iso: string | null): string {
  if (!iso) return '--';
  const value = new Date(iso);
  if (Number.isNaN(value.getTime())) return '--';
  return value.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' });
}

// Duration between check-in and check-out, rendered as "8h 30m"-style text.
function formatHours(record: AttendanceApiRecord): string {
  if (record.overtimeHours && record.overtimeHours > 0) {
    return `+${record.overtimeHours}h`;
  }
  if (!record.checkInTime || !record.checkOutTime) return '—';
  const start = new Date(record.checkInTime).getTime();
  const end = new Date(record.checkOutTime).getTime();
  if (Number.isNaN(start) || Number.isNaN(end) || end < start) return '—';
  const minutes = Math.round((end - start) / 60_000);
  return `${Math.floor(minutes / 60)}h ${minutes % 60}m`;
}

export function AttendancePage({ session }: { session: AuthSession }) {
  const { t } = useI18n();
  const { activeOrgId } = useActiveCompany();
  const [statusFilter, setStatusFilter] = useState<'' | (typeof STATUS_FILTERS)[number]>('');

  const attendanceQuery = useQuery({
    queryKey: ['attendance', activeOrgId, statusFilter],
    queryFn: () => {
      const search = statusFilter ? `?status=${statusFilter}` : '';
      return authenticatedGetJson<AttendanceEnvelope>(
        `/api/v1/attendance${search}`,
        session.accessToken,
        { 'x-company-id': activeOrgId },
      );
    },
    enabled: Boolean(activeOrgId),
  });

  const attendance = useMemo(() => attendanceQuery.data?.data ?? [], [attendanceQuery.data]);

  // Tallies come from the real response — no fabricated counts.
  const presentCount = attendance.filter((a) => a.status === 'PRESENT').length;
  const absentCount = attendance.filter((a) => a.status === 'ABSENT').length;
  const halfDayCount = attendance.filter((a) => a.status === 'HALF_DAY').length;

  return (
    <div className="space-y-pm-4">
      <GlassPanel>
        <p className="text-[11px] uppercase tracking-[0.34em] text-pm-brand">{t('dashboard.attendance')}</p>
        <h2 className="mt-pm-2 text-2xl font-semibold tracking-tight text-pm-text-primary">{t('admin.attendanceRecords')}</h2>
        <p className="mt-pm-3 text-sm text-pm-text-secondary">{t('admin.attendanceDescription')}</p>
      </GlassPanel>

      <section className="grid gap-pm-4 md:grid-cols-3">
        <GlassPanel>
          <p className="text-sm text-pm-text-secondary">{t('admin.present')}</p>
          <p className="mt-pm-2 text-2xl font-semibold text-pm-success">{presentCount}</p>
        </GlassPanel>
        <GlassPanel>
          <p className="text-sm text-pm-text-secondary">{t('attendance.halfDay')}</p>
          <p className="mt-pm-2 text-2xl font-semibold text-pm-warning">{halfDayCount}</p>
        </GlassPanel>
        <GlassPanel>
          <p className="text-sm text-pm-text-secondary">{t('admin.absent')}</p>
          <p className="mt-pm-2 text-2xl font-semibold text-pm-danger">{absentCount}</p>
        </GlassPanel>
      </section>

      {attendanceQuery.isPending ? (
        <LoadingState />
      ) : attendanceQuery.isError ? (
        <GlassPanel>
          <p className="text-sm font-semibold text-pm-text-primary">{t('attendance.loadError')}</p>
          <div className="mt-pm-4">
            <BrandButton tone="secondary" onClick={() => void attendanceQuery.refetch()}>
              {t('common.retry')}
            </BrandButton>
          </div>
        </GlassPanel>
      ) : attendance.length === 0 ? (
        <GlassPanel>
          <div className="rounded-pm-lg border border-dashed border-pm-border bg-pm-raised p-pm-5 text-center">
            <p className="text-sm text-pm-text-secondary">{t('attendance.empty')}</p>
          </div>
        </GlassPanel>
      ) : (
        <GlassPanel>
          <div className="flex flex-wrap items-center justify-between gap-pm-3">
            <div>
              <p className="text-sm font-semibold text-pm-text-primary">{t('admin.attendanceList')}</p>
              <p className="text-sm text-pm-text-secondary">
                {t('staff.onRecord')}: {attendance.length}
              </p>
            </div>
            <label className="flex items-center gap-pm-2 text-sm text-pm-text-secondary">
              {t('attendance.status')}
              <select
                value={statusFilter}
                onChange={(event) => setStatusFilter(event.target.value as '' | (typeof STATUS_FILTERS)[number])}
                className="rounded-pm-md border border-pm-border bg-pm-raised px-3 py-1.5 text-sm text-pm-text-primary"
              >
                <option value="">{t('attendance.allStatuses')}</option>
                {STATUS_FILTERS.map((status) => (
                  <option key={status} value={status}>
                    {t(STATUS_LABEL_KEYS[status])}
                  </option>
                ))}
              </select>
            </label>
          </div>
          <div className="mt-pm-4">
            <DataTable
              rows={attendance.map((record) => ({
                id: record.id,
                name: record.staff
                  ? `${record.staff.firstName} ${record.staff.lastName}`.trim()
                  : t('attendance.unassigned'),
                status: record.status,
                statusLabel: t(STATUS_LABEL_KEYS[record.status]),
                value: `${formatTime(record.checkInTime)}–${formatTime(record.checkOutTime)} · ${formatHours(record)}${
                  record.site ? ` · ${record.site.name}` : ''
                }`,
              }))}
            />
          </div>
        </GlassPanel>
      )}
    </div>
  );
}
