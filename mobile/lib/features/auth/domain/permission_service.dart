import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user.dart';

enum AppAction {
  // Super Admin only
  createCompany,
  createCompanyOwner,
  assignOwner,
  suspendUser,
  deleteUser,
  sendNotice,
  sendMessage,
  managePenalties,
  accessAnalytics,
  accessAuditLogs,
  manageSubscription,
  viewEveryCompany,
  
  // Owner + Super Admin
  manageSites,
  approveLeave,
  assignWorkers,
  createSiteManager,
  
  // Manager + Owner + Super Admin
  createSupervisor,
  
  // Supervisor + Manager + Owner + Super Admin
  createWorker,
  managePayroll,
  manageAttendance,
  
  // Worker + All
  viewProfile,
  viewAttendance,
  viewSalary,
  raiseIssue,
  triggerSOS,
  viewDocuments,
  viewNotifications,
  useAIAssistant,
}

class PermissionService {
  bool canPerform(UserRole role, AppAction action) {
    switch (role) {
      case UserRole.superAdmin:
        // Super admin can do absolutely everything
        return true;
        
      case UserRole.companyOwner:
        return const [
          AppAction.createSiteManager,
          AppAction.createSupervisor,
          AppAction.createWorker,
          AppAction.managePayroll,
          AppAction.manageAttendance,
          AppAction.manageSites,
          AppAction.approveLeave,
          AppAction.assignWorkers,
          // Shared with workers
          AppAction.viewProfile,
          AppAction.viewAttendance,
          AppAction.viewSalary,
          AppAction.raiseIssue,
          AppAction.triggerSOS,
          AppAction.viewDocuments,
          AppAction.viewNotifications,
          AppAction.useAIAssistant,
        ].contains(action);
        
      case UserRole.siteManager:
        return const [
          AppAction.createSupervisor,
          AppAction.createWorker,
          AppAction.managePayroll,
          AppAction.manageAttendance,
          AppAction.viewProfile,
          AppAction.viewAttendance,
          AppAction.viewSalary,
          AppAction.raiseIssue,
          AppAction.triggerSOS,
          AppAction.viewDocuments,
          AppAction.viewNotifications,
          AppAction.useAIAssistant,
        ].contains(action);
        
      case UserRole.supervisor:
        return const [
          AppAction.createWorker,
          AppAction.managePayroll,
          AppAction.manageAttendance,
          AppAction.viewProfile,
          AppAction.viewAttendance,
          AppAction.viewSalary,
          AppAction.raiseIssue,
          AppAction.triggerSOS,
          AppAction.viewDocuments,
          AppAction.viewNotifications,
          AppAction.useAIAssistant,
        ].contains(action);
        
      case UserRole.worker:
        return const [
          AppAction.viewProfile,
          AppAction.viewAttendance,
          AppAction.viewSalary,
          AppAction.raiseIssue,
          AppAction.triggerSOS,
          AppAction.viewDocuments,
          AppAction.viewNotifications,
          AppAction.useAIAssistant,
        ].contains(action);
    }
  }
  
  bool canCreateRole(UserRole creator, UserRole target) {
    if (creator == UserRole.superAdmin) return true;
    if (creator == UserRole.companyOwner && target != UserRole.superAdmin && target != UserRole.companyOwner) return true;
    if (creator == UserRole.siteManager && (target == UserRole.supervisor || target == UserRole.worker)) return true;
    if (creator == UserRole.supervisor && target == UserRole.worker) return true;
    
    return false;
  }
}

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});
