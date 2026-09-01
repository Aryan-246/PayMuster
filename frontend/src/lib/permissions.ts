// Client-side mirror of backend/src/lib/permissions.ts (blueprint §X).
// COSMETIC ONLY: this decides what the UI renders. Every gate is re-enforced
// server-side by requirePermission + requireTenant — frontend hiding is never
// security. Keep in sync with the backend map.
export type PermissionAction =
  | 'manage_system'
  | 'manage_company'
  | 'view_sites'
  | 'view_site_details'
  | 'manage_site'
  | 'manage_staff'
  | 'view_staff'
  | 'view_attendance'
  | 'manage_attendance'
  | 'view_own_attendance'
  | 'view_payroll'
  | 'run_payroll'
  | 'view_own_payroll'
  | 'view_documents'
  | 'manage_documents'
  | 'view_reports'
  | 'manage_settings'
  | 'manage_mail'
  | 'manage_announcements'
  | 'use_realtime'
  | 'use_ai'
  | 'manage_billing';

export const RolePermissions: Record<string, PermissionAction[]> = {
  SUPER_ADMIN: [
    'manage_system',
    'manage_company',
    'view_sites',
    'view_site_details',
    'manage_site',
    'manage_staff',
    'view_staff',
    'view_attendance',
    'manage_attendance',
    'view_own_attendance',
    'view_payroll',
    'run_payroll',
    'view_own_payroll',
    'view_documents',
    'manage_documents',
    'view_reports',
    'manage_settings',
    'manage_mail',
    'manage_announcements',
    'use_realtime',
    'use_ai',
    'manage_billing',
  ],
  OWNER: [
    'manage_company',
    'view_sites',
    'view_site_details',
    'manage_site',
    'manage_staff',
    'view_staff',
    'view_attendance',
    'manage_attendance',
    'view_payroll',
    'run_payroll',
    'view_documents',
    'manage_documents',
    'view_reports',
    'manage_settings',
    'manage_mail',
    'manage_announcements',
    'use_realtime',
    'use_ai',
    'manage_billing',
  ],
  ADMIN: [
    'view_sites',
    'view_site_details',
    'manage_site',
    'manage_staff',
    'view_staff',
    'view_attendance',
    'manage_attendance',
    'view_payroll',
    'run_payroll',
    'view_documents',
    'manage_documents',
    'view_reports',
    'manage_mail',
    'manage_announcements',
    'use_realtime',
    'use_ai',
  ],
  SUPERVISOR: [
    'view_sites',
    'view_site_details',
    'view_staff',
    'view_attendance',
    'manage_attendance',
    'view_documents',
    'view_reports',
    'use_realtime',
  ],
  ACCOUNTANT: [
    'view_payroll',
    'run_payroll',
    'view_reports',
    'use_realtime',
    'use_ai',
  ],
  STAFF: [
    'view_site_details',
    'view_own_attendance',
    'view_own_payroll',
    'view_documents',
    'use_realtime',
  ],
  VIEWER: [
    'view_sites',
    'view_site_details',
    'view_staff',
    'view_attendance',
    'view_payroll',
    'view_documents',
    'view_reports',
    'use_ai',
  ],
};

export function hasPermission(role: string | undefined, action: PermissionAction): boolean {
  if (!role) return false;
  return (RolePermissions[role] ?? []).includes(action);
}
