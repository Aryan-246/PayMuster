interface Row {
  id: string;
  name: string;
  status: string;
  value: string;
}

interface DataTableProps {
  rows: Row[];
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
                <span className="rounded-pm-max bg-pm-success/10 px-2.5 py-1 text-xs font-medium text-pm-success">{row.status}</span>
              </td>
              <td className="px-4 py-3 text-pm-text-secondary">{row.value}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
