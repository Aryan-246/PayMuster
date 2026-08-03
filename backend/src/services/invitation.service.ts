import { prisma } from '../lib/prisma.js';
import { UserRole } from '../../generated/prisma/index.js';
import { AppError } from '../lib/app-error.js';
import { eventBus } from '../lib/events.js';
import { AuditAction, InvitationStatus } from '../../generated/prisma/index.js';

export class InvitationService {
  async inviteUser(orgId: string, email: string, role: UserRole, invitedById: string) {
    const existing = await prisma.invitation.findFirst({
      where: { orgId, email, status: InvitationStatus.PENDING }
    });
    if (existing) throw new AppError('DUPLICATE_INVITATION', 'User already has a pending invitation', 400);

    // const token = Math.random().toString(36).substring(2, 15);
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days

    const invitation = await prisma.invitation.create({
      data: { orgId, email, role,  expiresAt, status: InvitationStatus.PENDING, invitedById }
    });

    eventBus.emitEvent('AuditLog', {
      orgId, userId: invitedById, action: AuditAction.CREATE, entityType: 'Invitation', entityId: invitation.id, changes: { email, role }
    });

    return invitation;
  }

  async acceptInvitation(invitationId: string, userId: string) {
    const invitation = await prisma.invitation.findUnique({ where: { id: invitationId } });
    if (!invitation || invitation.status !== InvitationStatus.PENDING) {
      throw new AppError('INVALID_INVITATION', 'Invalid or expired invitation', 400);
    }
    if (invitation.expiresAt < new Date()) {
      throw new AppError('EXPIRED_INVITATION', 'Invitation expired', 400);
    }

    const updated = await prisma.$transaction(async (tx: any) => {
      const updatedInv = await tx.invitation.update({
        where: { id: invitation.id },
        data: { status: InvitationStatus.ACCEPTED }
      });

      await tx.user.update({
        where: { id: userId },
        data: { orgId: invitation.orgId, role: invitation.role }
      });

      return updatedInv;
    });

    eventBus.emitEvent('AuditLog', {
      orgId: invitation.orgId, userId, action: AuditAction.UPDATE, entityType: 'Invitation', entityId: invitation.id, changes: { status: InvitationStatus.ACCEPTED }
    });

    return updated;
  }
}

export const invitationService = new InvitationService();
