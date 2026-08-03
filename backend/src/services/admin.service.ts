import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';
import { eventBus } from '../lib/events.js';
import { AuditAction, UserRole } from '../../generated/prisma/index.js';
import { authService } from '../lib/auth-service.js';

export class AdminService {
  async searchUsers(query: string) {
    if (!query) return [];
    
    return prisma.user.findMany({
      where: {
        OR: [
          { email: { contains: query, mode: 'insensitive' } },
          { name: { contains: query, mode: 'insensitive' } },
          { id: { equals: query } }
        ]
      },
      select: {
        id: true, email: true, name: true, role: true, isDisabled: true,
        org: { select: { id: true, name: true } }
      },
      take: 20
    });
  }

  async executeAction(targetUserId: string, actionBy: string, action: string, role?: UserRole) {
    const user = await prisma.user.findUnique({ where: { id: targetUserId } });
    if (!user) throw new AppError('NOT_FOUND', 'User not found', 404);

    if (user.role === 'SUPER_ADMIN') {
      throw new AppError('FORBIDDEN', 'Super Admin accounts cannot be modified or deleted', 403);
    }

    switch (action) {
      case 'PROMOTE':
      case 'DEMOTE':
      case 'CHANGE_ROLE':
        if (!role) throw new AppError('BAD_REQUEST', 'Role is required', 400);
        return this.updateUserRole(targetUserId, role, actionBy, user.role);
      
      case 'SUSPEND':
      case 'BLOCK':
        return this.updateUserStatus(targetUserId, true, actionBy);
      
      case 'UNSUSPEND':
      case 'UNBLOCK':
      case 'RESTORE':
        return this.updateUserStatus(targetUserId, false, actionBy);
      
      case 'DELETE':
        await authService.deleteAccount(targetUserId);
        eventBus.emitEvent('AuditLog', {
          orgId: user.orgId || '00000000-0000-0000-0000-000000000000',
          userId: actionBy, action: AuditAction.DELETE, entityType: 'User', entityId: targetUserId, targetId: targetUserId, changes: { deleted: true }
        });
        return { message: 'User permanently deleted' };
        
      default:
        throw new AppError('BAD_REQUEST', 'Invalid action', 400);
    }
  }

  private async updateUserRole(targetUserId: string, newRole: UserRole, actionBy: string, oldRole: UserRole) {
    const updated = await prisma.user.update({
      where: { id: targetUserId },
      data: { role: newRole }
    });

    eventBus.emitEvent('AuditLog', {
      orgId: updated.orgId || '00000000-0000-0000-0000-000000000000',
      userId: actionBy, action: AuditAction.UPDATE, entityType: 'User', entityId: targetUserId, targetId: targetUserId, changes: { role: newRole, oldRole }
    });

    return updated;
  }

  private async updateUserStatus(targetUserId: string, isDisabled: boolean, actionBy: string) {
    const updated = await prisma.user.update({
      where: { id: targetUserId },
      data: { isDisabled }
    });

    eventBus.emitEvent('AuditLog', {
      orgId: updated.orgId || '00000000-0000-0000-0000-000000000000',
      userId: actionBy, action: isDisabled ? AuditAction.SUSPEND : AuditAction.RESTORE, entityType: 'User', entityId: targetUserId, targetId: targetUserId, changes: { isDisabled }
    });

    return updated;
  }
}

export const adminService = new AdminService();
