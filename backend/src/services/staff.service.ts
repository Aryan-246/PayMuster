import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';
import { eventBus } from '../lib/events.js';
import { AuditAction, UserRole } from '../../generated/prisma/index.js';

export class StaffService {
  async changeRole(orgId: string, targetUserId: string, newRole: UserRole, actionBy: string) {
    if (newRole === UserRole.SUPER_ADMIN) {
      throw new AppError('FORBIDDEN', 'The Super Admin role cannot be assigned through company staff management.', 403);
    }

    const updated = await prisma.$transaction(async (tx: any) => {
      const user = await tx.user.findFirst({ where: { id: targetUserId, orgId } });
      if (!user) throw new AppError('NOT_FOUND', 'Staff not found', 404);
      if (user.role === UserRole.SUPER_ADMIN) throw new AppError('FORBIDDEN', 'Cannot modify super admin', 403);

      const result = await tx.user.updateMany({
        where: { id: targetUserId, orgId },
        data: { role: newRole },
      });
      if (result.count !== 1) throw new AppError('NOT_FOUND', 'Staff not found', 404);

      await tx.session.updateMany({
        where: { userId: targetUserId, revokedAt: null },
        data: { revokedAt: new Date() },
      });

      const current = await tx.user.findUnique({ where: { id: targetUserId } });
      return { user, updated: current };
    });

    const isPromotion = this.getRoleRank(newRole) > this.getRoleRank(updated.user.role);
    const action = isPromotion ? AuditAction.PROMOTE : AuditAction.DEMOTE;
    eventBus.emitEvent('AuditLog', {
      orgId, userId: actionBy, action, entityType: 'User', entityId: targetUserId, targetId: targetUserId, changes: { oldRole: updated.user.role, newRole },
    });
    eventBus.emitEvent('Notification', {
      orgId, userId: targetUserId, title: isPromotion ? 'Promoted' : 'Role Changed', body: `Your role has been updated to ${newRole}.`, type: 'ROLE_CHANGE',
    });

    return updated.updated;
  }

  async suspendStaff(orgId: string, targetUserId: string, actionBy: string) {
    const updated = await prisma.$transaction(async (tx: any) => {
      const user = await tx.user.findFirst({ where: { id: targetUserId, orgId } });
      if (!user) throw new AppError('NOT_FOUND', 'Staff not found', 404);
      if (user.role === UserRole.SUPER_ADMIN) throw new AppError('FORBIDDEN', 'Cannot modify super admin', 403);

      const result = await tx.user.updateMany({
        where: { id: targetUserId, orgId },
        data: { isDisabled: true },
      });
      if (result.count !== 1) throw new AppError('NOT_FOUND', 'Staff not found', 404);

      await tx.session.updateMany({
        where: { userId: targetUserId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      return tx.user.findUnique({ where: { id: targetUserId } });
    });

    eventBus.emitEvent('AuditLog', {
      orgId, userId: actionBy, action: AuditAction.SUSPEND, entityType: 'User', entityId: targetUserId, targetId: targetUserId, changes: { isDisabled: true },
    });
    eventBus.emitEvent('Notification', {
      orgId, userId: targetUserId, title: 'Account Suspended', body: 'Your account has been suspended by the company owner.', type: 'ACCOUNT_SUSPENDED',
    });

    return updated;
  }

  async restoreStaff(orgId: string, targetUserId: string, actionBy: string) {
    const updated = await prisma.$transaction(async (tx: any) => {
      const user = await tx.user.findFirst({ where: { id: targetUserId, orgId } });
      if (!user) throw new AppError('NOT_FOUND', 'Staff not found', 404);
      if (user.role === UserRole.SUPER_ADMIN) throw new AppError('FORBIDDEN', 'Cannot modify super admin', 403);

      const result = await tx.user.updateMany({
        where: { id: targetUserId, orgId },
        data: { isDisabled: false },
      });
      if (result.count !== 1) throw new AppError('NOT_FOUND', 'Staff not found', 404);

      await tx.session.updateMany({
        where: { userId: targetUserId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      return tx.user.findUnique({ where: { id: targetUserId } });
    });

    eventBus.emitEvent('AuditLog', {
      orgId, userId: actionBy, action: AuditAction.RESTORE, entityType: 'User', entityId: targetUserId, targetId: targetUserId, changes: { isDisabled: false },
    });
    eventBus.emitEvent('Notification', {
      orgId, userId: targetUserId, title: 'Account Restored', body: 'Your account has been restored.', type: 'ACCOUNT_RESTORED',
    });

    return updated;
  }

  async terminateStaff(orgId: string, targetUserId: string, actionBy: string) {
    const updated = await prisma.$transaction(async (tx: any) => {
      const user = await tx.user.findFirst({ where: { id: targetUserId, orgId } });
      if (!user) throw new AppError('NOT_FOUND', 'Staff not found', 404);
      if (user.role === UserRole.SUPER_ADMIN) throw new AppError('FORBIDDEN', 'Cannot modify super admin', 403);

      await tx.siteMember.deleteMany({ where: { userId: targetUserId, orgId } });
      const result = await tx.user.updateMany({
        where: { id: targetUserId, orgId },
        data: { orgId: null, role: UserRole.STAFF, isDisabled: false },
      });
      if (result.count !== 1) throw new AppError('NOT_FOUND', 'Staff not found', 404);

      await tx.session.updateMany({
        where: { userId: targetUserId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      return tx.user.findUnique({ where: { id: targetUserId } });
    });

    eventBus.emitEvent('AuditLog', {
      orgId, userId: actionBy, action: AuditAction.TERMINATE, entityType: 'User', entityId: targetUserId, targetId: targetUserId, changes: { terminated: true },
    });
    eventBus.emitEvent('Notification', {
      orgId, userId: targetUserId, title: 'Terminated', body: 'You have been terminated from the company.', type: 'TERMINATED',
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
