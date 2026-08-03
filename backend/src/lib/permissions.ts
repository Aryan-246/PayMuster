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
  | 'manage_settings';

export const RolePermissions: Record<string, PermissionAction[]> = {
  SUPER_ADMIN: ['manage_system'],
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
  ],
  MANAGER: [
    'view_sites',
    'view_site_details',
    'view_staff',
    'view_attendance',
    'manage_attendance',
    'view_documents',
    'view_reports',
  ],
  WORKER: [
    'view_site_details',
    'view_own_attendance',
    'view_own_payroll',
    'view_documents',
  ],
};
