import { prisma } from '../lib/prisma.js';
import { UserRole } from '../../generated/prisma/index.js';
import { AppError } from '../lib/app-error.js';
import { eventBus } from '../lib/events.js';
import { AuditAction, InvitationStatus } from '../../generated/prisma/index.js';

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

export class InvitationService {
  async inviteUser(orgId: string, email: string, role: UserRole, invitedById: string) {
    const normalizedEmail = normalizeEmail(email);
    const existing = await prisma.invitation.findFirst({
      where: { orgId, email: { equals: normalizedEmail, mode: 'insensitive' }, status: InvitationStatus.PENDING },
    });
    if (existing) throw new AppError('DUPLICATE_INVITATION', 'User already has a pending invitation', 400);

    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    const invitation = await prisma.invitation.create({
      data: { orgId, email: normalizedEmail, role, expiresAt, status: InvitationStatus.PENDING, invitedById },
    });

    eventBus.emitEvent('AuditLog', {
      orgId, userId: invitedById, action: AuditAction.CREATE, entityType: 'Invitation', entityId: invitation.id, changes: { email: normalizedEmail, role },
    });

    return invitation;
  }

  async acceptInvitation(invitationId: string, userId: string) {
    const result = await prisma.$transaction(async (tx: any) => {
      const invitation = await tx.invitation.findUnique({ where: { id: invitationId } });
      if (!invitation || invitation.status !== InvitationStatus.PENDING) {
        throw new AppError('INVALID_INVITATION', 'Invalid or already processed invitation', 400);
      }
      if (invitation.expiresAt < new Date()) {
        throw new AppError('EXPIRED_INVITATION', 'Invitation expired', 400);
      }

      const user = await tx.user.findUnique({ where: { id: userId } });
      if (!user || !user.email || normalizeEmail(user.email) !== normalizeEmail(invitation.email)) {
        throw new AppError('INVITATION_EMAIL_MISMATCH', 'This invitation belongs to a different account.', 403);
      }
      if (user.orgId !== null) {
        throw new AppError('ALREADY_AFFILIATED', 'This account already belongs to a company.', 409);
      }

      const updatedInvitation = await tx.invitation.updateMany({
        where: { id: invitationId, status: InvitationStatus.PENDING, expiresAt: { gt: new Date() } },
        data: { status: InvitationStatus.ACCEPTED, acceptedAt: new Date() },
      });
      if (updatedInvitation.count !== 1) {
        throw new AppError('INVALID_INVITATION', 'Invalid or already processed invitation', 400);
      }

      const updatedUser = await tx.user.updateMany({
        where: { id: userId, orgId: null },
        data: { orgId: invitation.orgId, role: invitation.role },
      });
      if (updatedUser.count !== 1) {
        throw new AppError('ALREADY_AFFILIATED', 'This account already belongs to a company.', 409);
      }

      await tx.session.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });

      return { invitationId: invitation.id, orgId: invitation.orgId };
    });

    eventBus.emitEvent('AuditLog', {
      orgId: result.orgId,
      userId,
      action: AuditAction.UPDATE,
      entityType: 'Invitation',
      entityId: result.invitationId,
      changes: { status: InvitationStatus.ACCEPTED },
    });

    return result;
  }
}

export const invitationService = new InvitationService();
