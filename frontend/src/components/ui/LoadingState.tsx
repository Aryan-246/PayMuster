export function LoadingState() {
  return (
    <div className="space-y-3 rounded-pm-xl border border-pm-border bg-pm-card p-pm-4">
      {[0, 1, 2].map((item) => (
        <div key={item} className="h-3 animate-pulse rounded-pm-max bg-pm-text-primary/10" />
      ))}
      <div className="h-10 animate-pulse rounded-pm-md bg-pm-brand/20" />
    </div>
  );
}
