import { NavLink } from 'react-router-dom';
import { useI18n } from '../../i18n/I18nProvider';
import { hasPermission, type PermissionAction } from '../../lib/permissions';
import type { AuthSession } from '../../lib/auth-session';

interface NavItem {
  key: string;
  icon: string;
  to: string;
  permission: PermissionAction;
}

// Only real routes are listed — no decorative links to pages that don't exist.
// Shared by the desktop sidebar and the mobile/tablet drawer so both surfaces
// show exactly the same permission-filtered navigation.
const items: NavItem[] = [
  { key: 'nav.overview', icon: '◉', to: '/', permission: 'view_reports' },
  { key: 'nav.workforce', icon: '◌', to: '/dashboard/staff', permission: 'view_staff' },
  { key: 'nav.attendance', icon: '◎', to: '/dashboard/attendance', permission: 'view_attendance' },
  { key: 'nav.payroll', icon: '◈', to: '/dashboard/payroll', permission: 'view_payroll' },
  { key: 'nav.announcements', icon: '◆', to: '/dashboard/announcements', permission: 'manage_announcements' },
  { key: 'nav.mailSupply', icon: '▤', to: '/dashboard/mail', permission: 'manage_mail' },
  { key: 'nav.subscription', icon: '▢', to: '/dashboard/subscription', permission: 'view_reports' },
  { key: 'nav.ownerRequests', icon: '◇', to: '/admin/owner-requests', permission: 'manage_system' },
];

export function visibleNavItems(session: AuthSession): NavItem[] {
  // Cosmetic role filtering only (blueprint §X): the backend re-enforces every
  // gate via requirePermission + requireTenant.
  return items.filter((item) => hasPermission(session.user.role, item.permission));
}

export type { NavItem };

export function SidebarBrand() {
  const { t } = useI18n();
  return (
    <div className="flex items-center gap-pm-3">
      <div className="flex h-10 w-10 items-center justify-center rounded-pm-lg bg-pm-brand/10">
        <img src="/paymuster_logo.png" alt="PayMuster logo" className="h-6 w-6 object-contain" />
      </div>
      <div>
        <p className="text-[10px] uppercase tracking-[0.36em] text-pm-brand">PayMuster</p>
        <p className="text-sm font-semibold text-pm-text-primary">{t('nav.workforceOs')}</p>
      </div>
    </div>
  );
}

export function SidebarUserCard({ session }: { session: AuthSession }) {
  return (
    <div className="rounded-pm-xl border border-pm-border bg-pm-card p-pm-4">
      <p className="text-sm font-semibold text-pm-text-primary">{session.user.name || session.user.email || session.user.publicId}</p>
      <p className="mt-1 text-xs uppercase tracking-[0.22em] text-pm-text-secondary">{session.user.role.replace('_', ' ')}</p>
    </div>
  );
}

export function PayMusterSidebar({ session }: { session: AuthSession }) {
  const { t } = useI18n();
  const visibleItems = visibleNavItems(session);

  return (
    <aside className="hidden w-[280px] shrink-0 flex-col rounded-pm-xl border border-pm-border bg-pm-surface p-pm-5 shadow-pm-5 xl:flex">
      <SidebarBrand />
      <nav className="mt-pm-6 space-y-pm-2">
        {visibleItems.map((item) => (
          <NavLink
            key={item.key}
            to={item.to}
            end={item.to === '/'}
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
    </aside>
  );
}
