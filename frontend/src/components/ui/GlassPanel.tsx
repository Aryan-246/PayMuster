interface GlassPanelProps {
  children: React.ReactNode;
  className?: string;
}

export function GlassPanel({ children, className = '' }: GlassPanelProps) {
  return (
    <div className={`rounded-pm-xl border border-pm-border bg-pm-surface p-pm-5 shadow-pm-4 ${className}`}>
      {children}
    </div>
  );
}
