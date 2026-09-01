interface Row {
  id: string;
  name: string;
  // Raw status drives the semantic tone (lowercased lookup). Pass statusLabel
  // when the rendered text should differ (e.g. localized labels) — tone still
  // comes from this value.
  status: string;
  statusLabel?: string;
  value: string;
}

interface DataTableProps {
  rows: Row[];
}

// Status → semantic color tone. Unknown statuses fall back to a neutral style
// so new statuses never render in a misleading color (e.g. everything green).
const statusToneClasses: Record<string, string> = {
  // success
  present: 'bg-pm-success/10 text-pm-success',
  approved: 'bg-pm-success/10 text-pm-success',
  active: 'bg-pm-success/10 text-pm-success',
  paid: 'bg-pm-success/10 text-pm-success',
  verified: 'bg-pm-success/10 text-pm-success',
  // warning
  late: 'bg-pm-warning/10 text-pm-warning',
  pending: 'bg-pm-warning/10 text-pm-warning',
  'half-day': 'bg-pm-warning/10 text-pm-warning',
  inactive: 'bg-pm-warning/10 text-pm-warning',
  draft: 'bg-pm-warning/10 text-pm-warning',
  // Backend enum statuses arrive uppercase (HALF_DAY, PAST_DUE) and are
  // lowercased above — alias the underscore spellings to the same tones.
  half_day: 'bg-pm-warning/10 text-pm-warning',
  past_due: 'bg-pm-danger/10 text-pm-danger',
  leave: 'bg-pm-warning/10 text-pm-warning',
  holiday: 'bg-pm-info/10 text-pm-info',
  overtime: 'bg-pm-info/10 text-pm-info',
  trialing: 'bg-pm-warning/10 text-pm-warning',
  // danger
  absent: 'bg-pm-danger/10 text-pm-danger',
  rejected: 'bg-pm-danger/10 text-pm-danger',
  suspended: 'bg-pm-danger/10 text-pm-danger',
  blocked: 'bg-pm-danger/10 text-pm-danger',
  deleted: 'bg-pm-danger/10 text-pm-danger',
  expired: 'bg-pm-danger/10 text-pm-danger',
  failed: 'bg-pm-danger/10 text-pm-danger',
  'past-due': 'bg-pm-danger/10 text-pm-danger',
};

function statusClass(status: string): string {
  return statusToneClasses[status.toLowerCase()] ?? 'bg-pm-raised text-pm-text-secondary';
}

export function DataTable({ rows }: DataTableProps) {
  return (
    <div className="overflow-hidden rounded-pm-xl border border-pm-border bg-pm-background">
      <table className="min-w-full text-left text-sm">
        <thead className="bg-pm-surface text-pm-text-secondary">
          <tr>
            <th className="px-4 py-3 font-medium">Employee</th>
            <th className="px-4 py-3 font-medium">Status</th>
            <th className="px-4 py-3 font-medium">Value</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.id} className="border-t border-pm-border bg-pm-card transition duration-pm-fast hover:bg-pm-raised">
              <td className="px-4 py-3 font-medium text-pm-text-primary">{row.name}</td>
              <td className="px-4 py-3">
                <span className={`rounded-pm-max px-2.5 py-1 text-xs font-medium ${statusClass(row.status)}`}>{row.statusLabel ?? row.status}</span>
              </td>
              <td className="px-4 py-3 text-pm-text-secondary">{row.value}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
