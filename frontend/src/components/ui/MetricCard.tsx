interface MetricCardProps {
  label: string;
  value: string;
  change: string;
}

export function MetricCard({ label, value, change }: MetricCardProps) {
  return (
    <div className="rounded-pm-lg border border-pm-border bg-pm-card p-pm-4 shadow-pm-2">
      <p className="text-sm text-pm-text-secondary">{label}</p>
      <div className="mt-3 flex items-end justify-between">
        <p className="text-2xl font-semibold text-pm-text-primary">{value}</p>
        <span className="rounded-pm-max bg-pm-warning/10 px-2 py-1 text-xs font-medium text-pm-warning">{change}</span>
      </div>
    </div>
  );
}
