interface BrandButtonProps {
  children: React.ReactNode;
  tone?: 'primary' | 'secondary';
  onClick?: () => void;
}

export function BrandButton({ children, tone = 'primary', onClick }: BrandButtonProps) {
  const base = 'min-h-10 rounded-pm-md px-pm-4 py-pm-3 text-sm font-semibold transition-all duration-pm-standard';
  const styles =
    tone === 'primary'
      ? `${base} bg-pm-brand text-pm-background shadow-pm-3 hover:brightness-105 hover:-translate-y-0.5 active:translate-y-0`
      : `${base} border border-pm-brand/30 bg-pm-brand/10 text-pm-brand hover:bg-pm-brand/20 hover:border-pm-brand/50`;

  return (
    <button type="button" onClick={onClick} className={styles}>
      {children}
    </button>
  );
}

