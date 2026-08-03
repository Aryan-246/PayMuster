import '../../features/auth/domain/user.dart';

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
}

class RolePermissionManager {
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
    },
    UserRole.admin: {
      AppPermission.viewSiteManagerDashboard,
      AppPermission.manageSites,
      AppPermission.viewSites,
      AppPermission.viewUsers,
      AppPermission.manageAttendance,
      AppPermission.viewAttendance,
      AppPermission.viewPayroll,
    },
    UserRole.supervisor: {
      AppPermission.viewSupervisorDashboard,
      AppPermission.viewSites,
      AppPermission.viewUsers,
      AppPermission.manageAttendance,
      AppPermission.viewAttendance,
    },
    UserRole.staff: {
      AppPermission.viewWorkerDashboard,
      AppPermission.logOwnAttendance,
      AppPermission.viewOwnPayroll,
    },
  };

  static bool hasPermission(User user, AppPermission permission) {
    final permissions = _rolePermissions[user.role];
    if (permissions == null) return false;
    
    // SuperAdmin bypass (optional, currently explicit in set)
    if (user.role == UserRole.superAdmin) return true;
    
    return permissions.contains(permission);
  }

  static bool hasAnyPermission(User user, List<AppPermission> permissions) {
    for (final p in permissions) {
      if (hasPermission(user, p)) return true;
    }
    return false;
  }
}
