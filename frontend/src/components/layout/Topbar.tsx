interface TopbarProps {
  title: string;
  subtitle: string;
}

export function Topbar({ title, subtitle }: TopbarProps) {
  return (
    <header className="flex flex-wrap items-center justify-between gap-4 rounded-[24px] border border-white/10 bg-[#121a1f]/80 p-4 shadow-[0_18px_36px_rgba(0,0,0,0.2)] backdrop-blur">
      <div>
        <p className="text-sm font-medium text-[#f4b400]">{title}</p>
        <h1 className="text-xl font-semibold text-white">{subtitle}</h1>
      </div>
      <div className="flex items-center gap-3">
        <label className="flex items-center gap-2 rounded-2xl border border-white/10 bg-[#0b1114] px-3 py-2 text-sm text-slate-400">
          <span>⌕</span>
          <input
            aria-label="Search dashboard"
            className="w-40 bg-transparent outline-none placeholder:text-slate-500"
            placeholder="Search"
          />
        </label>
        <button className="rounded-2xl border border-white/10 bg-[#182126] px-4 py-2 text-sm font-medium text-white transition hover:border-[#f4b400]/50">
          Export
        </button>
      </div>
    </header>
  );
}
