import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';
import { eventBus } from '../lib/events.js';
import { AuditAction, UserRole } from '../../generated/prisma/index.js';

export class StaffService {
  async changeRole(orgId: string, targetUserId: string, newRole: UserRole, actionBy: string) {
    const user = await prisma.user.findFirst({ where: { id: targetUserId, orgId } });
    if (!user) throw new AppError('NOT_FOUND', 'Staff not found', 404);

    if (user.role === 'SUPER_ADMIN') throw new AppError('FORBIDDEN', 'Cannot modify super admin', 403);
    
    const updated = await prisma.user.update({
      where: { id: targetUserId },
      data: { role: newRole }
    });

    const isPromotion = this.getRoleRank(newRole) > this.getRoleRank(user.role);
    const action = isPromotion ? AuditAction.PROMOTE : AuditAction.DEMOTE;

    eventBus.emitEvent('AuditLog', {
      orgId, userId: actionBy, action, entityType: 'User', entityId: targetUserId, targetId: targetUserId, changes: { oldRole: user.role, newRole }
    });

    eventBus.emitEvent('Notification', {
      orgId,
      userId: targetUserId,
      title: isPromotion ? 'Promoted' : 'Role Changed',
      body: `Your role has been updated to ${newRole}.`,
      type: 'ROLE_CHANGE'
    });

    return updated;
  }

  async suspendStaff(orgId: string, targetUserId: string, actionBy: string) {
    const user = await prisma.user.findFirst({ where: { id: targetUserId, orgId } });
    if (!user) throw new AppError('NOT_FOUND', 'Staff not found', 404);
    if (user.role === 'SUPER_ADMIN') throw new AppError('FORBIDDEN', 'Cannot modify super admin', 403);

    const updated = await prisma.user.update({
      where: { id: targetUserId },
      data: { isDisabled: true }
    });

    eventBus.emitEvent('AuditLog', {
      orgId, userId: actionBy, action: AuditAction.SUSPEND, entityType: 'User', entityId: targetUserId, targetId: targetUserId, changes: { isDisabled: true }
    });

    eventBus.emitEvent('Notification', {
      orgId,
      userId: targetUserId,
      title: 'Account Suspended',
      body: `Your account has been suspended by the company owner.`,
      type: 'ACCOUNT_SUSPENDED'
    });

    return updated;
  }

  async restoreStaff(orgId: string, targetUserId: string, actionBy: string) {
    const updated = await prisma.user.update({
      where: { id: targetUserId },
      data: { isDisabled: false }
    });

    eventBus.emitEvent('AuditLog', {
      orgId, userId: actionBy, action: AuditAction.RESTORE, entityType: 'User', entityId: targetUserId, targetId: targetUserId, changes: { isDisabled: false }
    });

    eventBus.emitEvent('Notification', {
      orgId,
      userId: targetUserId,
      title: 'Account Restored',
      body: `Your account has been restored.`,
      type: 'ACCOUNT_RESTORED'
    });

    return updated;
  }

  async terminateStaff(orgId: string, targetUserId: string, actionBy: string) {
    const user = await prisma.user.findFirst({ where: { id: targetUserId, orgId } });
    if (!user) throw new AppError('NOT_FOUND', 'Staff not found', 404);
    if (user.role === 'SUPER_ADMIN') throw new AppError('FORBIDDEN', 'Cannot modify super admin', 403);

    const updated = await prisma.$transaction(async (tx: any) => {
      // Remove from all sites
      await tx.siteMember.deleteMany({ where: { userId: targetUserId, orgId } });
      
      // Remove from org entirely
      return tx.user.update({
        where: { id: targetUserId },
        data: { orgId: null, role: 'STAFF', isDisabled: false } // becomes unassigned staff
      });
    });

    eventBus.emitEvent('AuditLog', {
      orgId, userId: actionBy, action: AuditAction.TERMINATE, entityType: 'User', entityId: targetUserId, targetId: targetUserId, changes: { terminated: true }
    });

    eventBus.emitEvent('Notification', {
      orgId,
      userId: targetUserId,
      title: 'Terminated',
      body: `You have been terminated from the company.`,
      type: 'TERMINATED'
    });

    return updated;
  }

  private getRoleRank(role: UserRole) {
    const ranks = {
      VIEWER: 1,
      STAFF: 2,
      SUPERVISOR: 3,
      ACCOUNTANT: 4,
      ADMIN: 5,
      OWNER: 6,
      SUPER_ADMIN: 7
    };
    return ranks[role] || 0;
  }
}

export const staffService = new StaffService();
