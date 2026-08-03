import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';
import { eventBus } from '../lib/events.js';
import { AuditAction, RequestStatus } from '../../generated/prisma/index.js';

export class PromotionService {
  async requestPromotion(orgId: string, userId: string, requestedRole: any, reason?: string) {
    const existing = await prisma.promotionRequest.findFirst({
      where: { orgId, userId, status: RequestStatus.PENDING }
    });
    if (existing) throw new AppError('DUPLICATE_REQUEST', 'You already have a pending promotion request', 400);

    const request = await prisma.promotionRequest.create({
      data: { orgId, userId, requestedRole, reason, status: RequestStatus.PENDING }
    });

    eventBus.emitEvent('AuditLog', {
      orgId, userId, action: AuditAction.CREATE, entityType: 'PromotionRequest', entityId: request.id, changes: { requestedRole, reason }
    });

    return request;
  }

  async approveRequest(orgId: string, requestId: string, approvedBy: string) {
    const request = await prisma.promotionRequest.findFirst({ where: { id: requestId, orgId } });
    if (!request || request.status !== RequestStatus.PENDING) throw new AppError('INVALID_REQUEST', 'Request not found or already processed', 400);

    const updated = await prisma.$transaction(async (tx: any) => {
      const updatedReq = await tx.promotionRequest.update({
        where: { id: requestId },
        data: { status: RequestStatus.APPROVED, resolvedById: approvedBy, resolvedAt: new Date() }
      });

      await tx.user.update({
        where: { id: request.userId },
        data: { role: request.requestedRole } // Assumes requestedRole is a valid UserRole enum on DB side (prisma allows string if casted)
      });

      return updatedReq;
    });

    eventBus.emitEvent('AuditLog', {
      orgId, userId: approvedBy, action: AuditAction.APPROVE, entityType: 'PromotionRequest', entityId: request.id, targetId: request.userId, changes: { status: RequestStatus.APPROVED, newRole: request.requestedRole }
    });

    return updated;
  }
}

export const promotionService = new PromotionService();
