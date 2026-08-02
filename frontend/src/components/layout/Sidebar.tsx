interface SidebarProps {
  active?: string;
}

const items = [
  { id: 'overview', label: 'Overview', icon: '◉' },
  { id: 'staff', label: 'Staff', icon: '◌' },
  { id: 'attendance', label: 'Attendance', icon: '◎' },
  { id: 'payroll', label: 'Payroll', icon: '◍' },
  { id: 'settings', label: 'Settings', icon: '◐' },
];

export function Sidebar({ active = 'overview' }: SidebarProps) {
  return (
    <aside className="hidden w-72 shrink-0 flex-col rounded-[24px] border border-white/10 bg-[#121a1f]/95 p-5 shadow-[0_24px_60px_rgba(0,0,0,0.35)] lg:flex">
      <div className="flex items-center gap-3">
        <img src="/paymuster_logo.png" alt="PayMuster logo" className="h-10 w-10 rounded-2xl object-cover" />
        <div>
          <p className="text-[11px] uppercase tracking-[0.32em] text-[#f4b400]">PayMuster</p>
          <p className="text-sm font-semibold text-white">Admin Console</p>
        </div>
      </div>

      <nav className="mt-8 space-y-2">
        {items.map((item) => {
          const isActive = item.id === active;
          return (
            <button
              key={item.id}
              className={`flex w-full items-center justify-between rounded-2xl px-3 py-3 text-left text-sm transition ${
                isActive
                  ? 'bg-[#182126] text-white shadow-[inset_3px_0_0_#f4b400]'
                  : 'text-slate-400 hover:bg-white/5 hover:text-white'
              }`}
            >
              <span className="flex items-center gap-3">
                <span className="text-base">{item.icon}</span>
                {item.label}
              </span>
              {isActive ? <span className="text-xs text-[#f4b400]">●</span> : null}
            </button>
          );
        })}
      </nav>

      <div className="mt-auto rounded-2xl border border-white/10 bg-[#182126] p-4">
        <p className="text-sm font-semibold text-white">Operations pulse</p>
        <p className="mt-2 text-sm text-slate-400">Every workflow is now framed in a premium, accessible shell.</p>
      </div>
    </aside>
  );
}
