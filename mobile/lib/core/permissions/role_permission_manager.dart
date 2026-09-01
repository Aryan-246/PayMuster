import '../../features/auth/domain/user.dart';

/// Client-side mirror of the backend `RolePermissions` map
/// (backend/src/lib/permissions.ts). COSMETIC ONLY: this decides what the UI
/// renders — the backend re-enforces every gate via requirePermission +
/// requireTenant. Never treat a grant here as access control.
enum AppPermission {
  // Dashboards
  viewSuperAdminDashboard,
  viewOwnerDashboard,
  viewSiteManagerDashboard,
  viewSupervisorDashboard,
  viewWorkerDashboard,

  // Organization
  manageOrganization,

  // Sites & Projects
  manageSites,
  viewSites,

  // Users & Staff
  manageUsers,
  viewUsers,

  // Attendance
  manageAttendance,
  viewAttendance,
  logOwnAttendance,

  // Payroll
  managePayroll,
  viewPayroll,
  viewOwnPayroll,

  // Documents
  viewDocuments,
  manageDocuments,

  // Reports / AI
  viewReports,
  useAi,

  // Announcements
  manageAnnouncements,

  // Mail Supply
  manageMail,

  // Billing / Subscription
  manageBilling,
  manageSettings,

  // Chat / video
  useRealtime,
}

class RolePermissionManager {
  /// Mirrors backend RolePermissions — keep in sync with
  /// backend/src/lib/permissions.ts (the authoritative map).
  static const Map<UserRole, Set<AppPermission>> _rolePermissions = {
    UserRole.superAdmin: {
      AppPermission.viewSuperAdminDashboard,
      AppPermission.manageOrganization,
      AppPermission.manageSites,
      AppPermission.viewSites,
      AppPermission.manageUsers,
      AppPermission.viewUsers,
      AppPermission.manageAttendance,
      AppPermission.viewAttendance,
      AppPermission.managePayroll,
      AppPermission.viewPayroll,
      AppPermission.viewDocuments,
      AppPermission.manageDocuments,
      AppPermission.viewReports,
      AppPermission.useAi,
      AppPermission.manageAnnouncements,
      AppPermission.manageMail,
      AppPermission.manageBilling,
      AppPermission.manageSettings,
      AppPermission.useRealtime,
    },
    UserRole.owner: {
      AppPermission.viewOwnerDashboard,
      AppPermission.manageSites,
      AppPermission.viewSites,
      AppPermission.manageUsers,
      AppPermission.viewUsers,
      AppPermission.manageAttendance,
      AppPermission.viewAttendance,
      AppPermission.managePayroll,
      AppPermission.viewPayroll,
      AppPermission.viewDocuments,
      AppPermission.manageDocuments,
      AppPermission.viewReports,
      AppPermission.useAi,
      AppPermission.manageAnnouncements,
      AppPermission.manageMail,
      AppPermission.manageBilling,
      AppPermission.manageSettings,
      AppPermission.useRealtime,
    },
    UserRole.admin: {
      AppPermission.viewSiteManagerDashboard,
      AppPermission.manageSites,
      AppPermission.viewSites,
      AppPermission.manageUsers,
      AppPermission.viewUsers,
      AppPermission.manageAttendance,
      AppPermission.viewAttendance,
      AppPermission.managePayroll,
      AppPermission.viewPayroll,
      AppPermission.viewDocuments,
      AppPermission.manageDocuments,
      AppPermission.viewReports,
      AppPermission.useAi,
      AppPermission.manageAnnouncements,
      AppPermission.manageMail,
      AppPermission.useRealtime,
    },
    UserRole.supervisor: {
      AppPermission.viewSupervisorDashboard,
      AppPermission.viewSites,
      AppPermission.viewUsers,
      AppPermission.manageAttendance,
      AppPermission.viewAttendance,
      AppPermission.viewDocuments,
      AppPermission.viewReports,
      AppPermission.useRealtime,
    },
    UserRole.accountant: {
      AppPermission.managePayroll,
      AppPermission.viewPayroll,
      AppPermission.viewReports,
      AppPermission.useAi,
      AppPermission.useRealtime,
    },
    UserRole.staff: {
      AppPermission.viewWorkerDashboard,
      AppPermission.logOwnAttendance,
      AppPermission.viewOwnPayroll,
      AppPermission.viewDocuments,
      AppPermission.useRealtime,
    },
    UserRole.viewer: {
      AppPermission.viewSites,
      AppPermission.viewUsers,
      AppPermission.viewAttendance,
      AppPermission.viewPayroll,
      AppPermission.viewDocuments,
      AppPermission.viewReports,
      AppPermission.useAi,
    },
  };

  static bool hasPermission(User user, AppPermission permission) {
    return roleHasPermission(user.role, permission);
  }

  static bool roleHasPermission(UserRole role, AppPermission permission) {
    final permissions = _rolePermissions[role];
    if (permissions == null) return false;
    return permissions.contains(permission);
  }

  static bool hasAnyPermission(User user, List<AppPermission> permissions) {
    for (final p in permissions) {
      if (hasPermission(user, p)) return true;
    }
    return false;
  }
}
