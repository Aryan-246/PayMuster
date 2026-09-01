import { useEffect, useRef } from 'react';

interface ConfirmDialogProps {
  open: boolean;
  title: string;
  description: string;
  confirmLabel: string;
  cancelLabel: string;
  destructive?: boolean;
  busy?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

/**
 * Accessible destructive-action confirmation. Focus starts on Cancel (the
 * safe outcome), Escape cancels, the backdrop cancels, and the modal scale-in
 * is collapsed by the global prefers-reduced-motion rule.
 */
export function ConfirmDialog({
  open,
  title,
  description,
  confirmLabel,
  cancelLabel,
  destructive = false,
  busy = false,
  onConfirm,
  onCancel,
}: ConfirmDialogProps) {
  const cancelRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (open) {
      cancelRef.current?.focus();
    }
  }, [open]);

  useEffect(() => {
    if (!open) {
      return;
    }
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        onCancel();
      }
    };
    document.addEventListener('keydown', onKeyDown);
    return () => document.removeEventListener('keydown', onKeyDown);
  }, [open, onCancel]);

  if (!open) {
    return null;
  }

  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center p-pm-4">
      <button
        type="button"
        aria-label={cancelLabel}
        onClick={onCancel}
        className="absolute inset-0 h-full w-full bg-black/50 motion-reduce:transition-none"
        style={{ animation: 'pm-fade-in 150ms ease-out' }}
      />
      <div
        role="alertdialog"
        aria-modal="true"
        aria-labelledby="pm-confirm-title"
        aria-describedby="pm-confirm-description"
        className="relative w-full max-w-md rounded-pm-xl border border-pm-border bg-pm-surface p-pm-5 shadow-pm-5 motion-reduce:transform-none"
        style={{ animation: 'pm-dialog-in 200ms ease-out' }}
      >
        <h3 id="pm-confirm-title" className="text-lg font-semibold text-pm-text-primary">{title}</h3>
        <p id="pm-confirm-description" className="mt-pm-3 text-sm leading-6 text-pm-text-secondary">{description}</p>
        <div className="mt-pm-5 flex flex-wrap justify-end gap-pm-3">
          <button
            ref={cancelRef}
            type="button"
            onClick={onCancel}
            disabled={busy}
            className="min-h-10 rounded-pm-md border border-pm-border bg-pm-raised px-pm-4 py-pm-3 text-sm font-semibold text-pm-text-primary transition-all duration-pm-standard hover:bg-pm-card focus:outline-none focus-visible:ring-2 focus-visible:ring-pm-brand disabled:opacity-50"
          >
            {cancelLabel}
          </button>
          <button
            type="button"
            onClick={onConfirm}
            disabled={busy}
            className={`min-h-10 rounded-pm-md px-pm-4 py-pm-3 text-sm font-semibold transition-all duration-pm-standard focus:outline-none focus-visible:ring-2 focus-visible:ring-pm-brand disabled:opacity-50 disabled:cursor-not-allowed ${
              destructive
                ? 'bg-pm-danger text-white hover:brightness-105'
                : 'bg-pm-brand text-pm-background shadow-pm-3 hover:brightness-105'
            }`}
          >
            {busy ? '…' : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
