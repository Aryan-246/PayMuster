import { useEffect, useRef, useState } from 'react';
import { NavLink } from 'react-router-dom';
import { useI18n } from '../../i18n/I18nProvider';
import type { AuthSession } from '../../lib/auth-session';
import { visibleNavItems, SidebarBrand, SidebarUserCard } from './PayMusterSidebar';

/**
 * Mobile/tablet navigation (< xl). Opens as a slide-in drawer from the same
 * permission-filtered item list the desktop sidebar renders — one source of
 * truth, no separate nav surface to drift out of sync. The transition is
 * reduced-motion-safe and the overlay traps no focus: Escape closes, the panel
 * is labelled, and navigation closes the drawer.
 */
export function MobileNavDrawer({ session }: { session: AuthSession }) {
  const { t } = useI18n();
  const [open, setOpen] = useState(false);
  const toggleRef = useRef<HTMLButtonElement>(null);
  const items = visibleNavItems(session);

  useEffect(() => {
    if (!open) {
      return;
    }
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setOpen(false);
        toggleRef.current?.focus();
      }
    };
    document.addEventListener('keydown', onKeyDown);
    return () => document.removeEventListener('keydown', onKeyDown);
  }, [open]);

  return (
    <div className="xl:hidden">
      <button
        ref={toggleRef}
        type="button"
        onClick={() => setOpen(true)}
        aria-expanded={open}
        aria-label={t('nav.openMenu')}
        className="flex h-11 w-11 items-center justify-center rounded-pm-md border border-pm-border bg-pm-surface text-pm-text-primary transition duration-pm-fast hover:bg-pm-raised focus:outline-none focus-visible:ring-2 focus-visible:ring-pm-brand"
      >
        {/* Hamburger glyph */}
        <svg width="20" height="20" viewBox="0 0 20 20" fill="none" aria-hidden="true">
          <path d="M3 5h14M3 10h14M3 15h14" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" />
        </svg>
      </button>

      {open && (
        <div className="fixed inset-0 z-50" role="dialog" aria-modal="true" aria-label={t('nav.menu')}>
          {/* Backdrop */}
          <button
            type="button"
            aria-label={t('nav.closeMenu')}
            onClick={() => setOpen(false)}
            className="absolute inset-0 h-full w-full bg-black/50 motion-reduce:transition-none"
            style={{ animation: 'pm-fade-in 150ms ease-out' }}
          />
          {/* Panel */}
          <div
            className="absolute inset-y-0 left-0 flex w-[300px] max-w-[85vw] flex-col border-r border-pm-border bg-pm-surface p-pm-5 shadow-pm-5 motion-reduce:transform-none motion-reduce:transition-none"
            style={{ animation: 'pm-slide-in-left 200ms ease-out' }}
          >
            <div className="flex items-center justify-between">
              <SidebarBrand />
              <button
                type="button"
                onClick={() => setOpen(false)}
                aria-label={t('nav.closeMenu')}
                className="flex h-11 w-11 items-center justify-center rounded-pm-md text-pm-text-secondary transition duration-pm-fast hover:bg-pm-raised hover:text-pm-text-primary focus:outline-none focus-visible:ring-2 focus-visible:ring-pm-brand"
              >
                {/* Close glyph */}
                <svg width="20" height="20" viewBox="0 0 20 20" fill="none" aria-hidden="true">
                  <path d="M5 5l10 10M15 5L5 15" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" />
                </svg>
              </button>
            </div>
            <nav className="mt-pm-6 space-y-pm-2">
              {items.map((item) => (
                <NavLink
                  key={item.key}
                  to={item.to}
                  end={item.to === '/'}
                  onClick={() => setOpen(false)}
                  className={({ isActive }) =>
                    `flex min-h-12 w-full items-center justify-between rounded-pm-md px-pm-3 py-pm-3 text-left text-sm transition duration-pm-fast ${isActive ? 'bg-pm-raised text-pm-text-primary shadow-[inset_3px_0_0_var(--pm-color-primary)]' : 'text-pm-text-secondary hover:bg-pm-raised hover:text-pm-text-primary'}`
                  }
                >
                  <span className="flex items-center gap-pm-3"><span className="text-base">{item.icon}</span>{t(item.key)}</span>
                </NavLink>
              ))}
            </nav>
            <div className="mt-auto">
              <SidebarUserCard session={session} />
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
