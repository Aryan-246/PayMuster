import { Sidebar } from './Sidebar';
import { Topbar } from './Topbar';
import { MetricCard } from '../ui/MetricCard';
import { PanelCard } from '../ui/PanelCard';
import { DataTable } from '../ui/DataTable';
import { EmptyState } from '../ui/EmptyState';
import { LoadingState } from '../ui/LoadingState';

export function DashboardShell() {
  return (
    <div className="min-h-screen bg-[radial-gradient(circle_at_top_left,_rgba(244,180,0,0.14),_transparent_24%),_#0b1114] px-4 py-4 text-slate-100 md:px-6 lg:px-8 lg:py-6">
      <div className="mx-auto flex max-w-7xl gap-4">
        <Sidebar />
        <main className="flex-1 space-y-4">
          <Topbar title="Operations dashboard" subtitle="Premium admin foundation" />

          <section className="grid gap-4 xl:grid-cols-4">
            <MetricCard label="Active staff" value="184" change="+12%" />
            <MetricCard label="Pending payroll" value="24" change="5 due" />
            <MetricCard label="Attendance rate" value="97.4%" change="Stable" />
            <MetricCard label="Revenue" value="$42.8K" change="+8.2%" />
          </section>

          <section className="grid gap-4 xl:grid-cols-[1.5fr_1fr]">
            <PanelCard title="Daily operations" subtitle="A polished shell for the next module work.">
              <div className="space-y-3">
                <div className="rounded-2xl border border-white/10 bg-[#182126] p-4">
                  <p className="text-sm text-slate-400">Workflow health</p>
                  <div className="mt-3 flex items-center justify-between">
                    <p className="text-3xl font-semibold text-white">92%</p>
                    <div className="h-2 w-32 rounded-full bg-white/10">
                      <div className="h-2 w-[92%] rounded-full bg-[#f4b400]" />
                    </div>
                  </div>
                </div>
                <LoadingState />
              </div>
            </PanelCard>
            <PanelCard title="Upcoming actions" subtitle="Shells ready for future modules.">
              <EmptyState title="No actions queued" description="The UI foundation is completed and ready to host the next screens." />
            </PanelCard>
          </section>

          <PanelCard title="Team overview" subtitle="Reusable table component with premium dark styling.">
            <DataTable rows={[
              { id: '1', name: 'Mina Yusuf', status: 'Present', value: '$3,420' },
              { id: '2', name: 'Liam Carter', status: 'Pending', value: '$2,980' },
              { id: '3', name: 'Sana Ali', status: 'Present', value: '$4,100' },
            ]} />
          </PanelCard>
        </main>
      </div>
    </div>
  );
}
