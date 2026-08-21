import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';
import { eventBus } from '../lib/events.js';
import { AuditAction, RequestStatus, UserRole } from '../../generated/prisma/index.js';

export class PromotionService {
  async requestPromotion(orgId: string, userId: string, requestedRole: UserRole, reason?: string) {
    const request = await prisma.$transaction(async (tx: any) => {
      const user = await tx.user.findUnique({ where: { id: userId } });
      if (!user || user.orgId !== orgId) {
        throw new AppError('NOT_FOUND', 'Staff not found in this company', 404);
      }

      const existing = await tx.promotionRequest.findFirst({
        where: { orgId, userId, status: RequestStatus.PENDING },
      });
      if (existing) {
        throw new AppError('DUPLICATE_REQUEST', 'You already have a pending promotion request', 400);
      }

      return tx.promotionRequest.create({
        data: { orgId, userId, requestedRole, reason, status: RequestStatus.PENDING },
      });
    });

    eventBus.emitEvent('AuditLog', {
      orgId, userId, action: AuditAction.CREATE, entityType: 'PromotionRequest', entityId: request.id, changes: { requestedRole, reason },
    });

    return request;
  }

  async approveRequest(orgId: string, requestId: string, approvedBy: string) {
    const result = await prisma.$transaction(async (tx: any) => {
      const request = await tx.promotionRequest.findFirst({
        where: { id: requestId, orgId, status: RequestStatus.PENDING },
      });
      if (!request) {
        throw new AppError('INVALID_REQUEST', 'Request not found or already processed', 400);
      }

      const user = await tx.user.findUnique({ where: { id: request.userId } });
      if (!user || user.orgId !== orgId) {
        throw new AppError('AFFILIATION_CONFLICT', 'The staff member no longer belongs to this company.', 409);
      }
      if (user.role === UserRole.SUPER_ADMIN) {
        throw new AppError('FORBIDDEN', 'Cannot modify super admin', 403);
      }

      const updatedRequest = await tx.promotionRequest.updateMany({
        where: { id: requestId, orgId, status: RequestStatus.PENDING },
        data: { status: RequestStatus.APPROVED, resolvedById: approvedBy, resolvedAt: new Date() },
      });
      if (updatedRequest.count !== 1) {
        throw new AppError('INVALID_REQUEST', 'Request not found or already processed', 400);
      }

      const updatedUser = await tx.user.updateMany({
        where: { id: request.userId, orgId },
        data: { role: request.requestedRole },
      });
      if (updatedUser.count !== 1) {
        throw new AppError('AFFILIATION_CONFLICT', 'The staff member affiliation changed during approval.', 409);
      }

      await tx.session.updateMany({
        where: { userId: request.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });

      return { request: { ...request, status: RequestStatus.APPROVED }, userId: request.userId, newRole: request.requestedRole };
    });

    eventBus.emitEvent('AuditLog', {
      orgId,
      userId: approvedBy,
      action: AuditAction.APPROVE,
      entityType: 'PromotionRequest',
      entityId: requestId,
      targetId: result.userId,
      changes: { status: RequestStatus.APPROVED, newRole: result.newRole },
    });

    return result.request;
  }
}

export const promotionService = new PromotionService();
