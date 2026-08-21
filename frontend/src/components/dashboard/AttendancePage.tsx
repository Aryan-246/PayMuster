import { useState } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import { GlassPanel } from '../ui/GlassPanel';
import { DataTable } from '../ui/DataTable';

interface AttendanceRecord {
  id: string;
  publicId: string;
  name: string;
  date: string;
  checkIn: string;
  checkOut: string | null;
  status: 'present' | 'absent' | 'late' | 'half-day';
  hours: string;
}

const mockAttendance: AttendanceRecord[] = [
  { id: '1', publicId: 'USR-001', name: 'Aisha Patel', date: '2026-08-06', checkIn: '08:15', checkOut: '17:30', status: 'present', hours: '9h 15m' },
  { id: '2', publicId: 'USR-002', name: 'Raj Singh', date: '2026-08-06', checkIn: '09:45', checkOut: '17:00', status: 'late', hours: '7h 15m' },
  { id: '3', publicId: 'USR-003', name: 'Priya Sharma', date: '2026-08-06', checkIn: '08:00', checkOut: '16:30', status: 'present', hours: '8h 30m' },
  { id: '4', publicId: 'USR-004', name: 'Karan Mehta', date: '2026-08-06', checkIn: '--', checkOut: '--', status: 'absent', hours: '0h' },
  { id: '5', publicId: 'USR-005', name: 'Sana Ali', date: '2026-08-06', checkIn: '08:30', checkOut: '13:00', status: 'half-day', hours: '4h 30m' },
];

export function AttendancePage() {
  const { t } = useI18n();
  const [attendance] = useState<AttendanceRecord[]>(mockAttendance);

  const presentCount = attendance.filter((a) => a.status === 'present').length;
  const lateCount = attendance.filter((a) => a.status === 'late').length;
  const absentCount = attendance.filter((a) => a.status === 'absent').length;

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
          <p className="text-sm text-pm-text-secondary">{t('admin.late')}</p>
          <p className="mt-pm-2 text-2xl font-semibold text-pm-warning">{lateCount}</p>
        </GlassPanel>
        <GlassPanel>
          <p className="text-sm text-pm-text-secondary">{t('admin.absent')}</p>
          <p className="mt-pm-2 text-2xl font-semibold text-pm-error">{absentCount}</p>
        </GlassPanel>
      </section>

      <GlassPanel>
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm font-semibold text-pm-text-primary">{t('admin.attendanceList')}</p>
            <p className="text-sm text-pm-text-secondary">{t('admin.attendanceListDescription')}</p>
          </div>
        </div>
        <div className="mt-pm-4">
          <DataTable
            rows={attendance.map((a) => ({
              id: a.id,
              name: a.name,
              status: a.status,
              value: a.publicId,
            }))}
          />
        </div>
      </GlassPanel>
    </div>
  );
}