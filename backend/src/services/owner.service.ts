import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';
import { eventBus } from '../lib/events.js';
import { AuditAction, RequestStatus } from '../../generated/prisma/index.js';

export class OwnerService {
  async requestOwnership(userId: string, companyName: string, gstin?: string) {
    const existing = await prisma.ownerRequest.findFirst({
      where: { userId, status: RequestStatus.PENDING }
    });
    if (existing) throw new AppError('DUPLICATE_REQUEST', 'You already have a pending owner request', 400);

    const request = await prisma.ownerRequest.create({
      data: { userId, companyName, gstin, status: RequestStatus.PENDING }
    });

    eventBus.emitEvent('AuditLog', {
      orgId: 'SYSTEM', userId, action: AuditAction.CREATE, entityType: 'OwnerRequest', entityId: request.id, changes: { companyName, gstin }
    });

    return request;
  }

  async approveRequest(orgId: string, requestId: string, approvedBy: string) {
    const request = await prisma.ownerRequest.findFirst({ where: { id: requestId } });
    if (!request || request.status !== RequestStatus.PENDING) throw new AppError('INVALID_REQUEST', 'Request not found or already processed', 400);

    const updated = await prisma.$transaction(async (tx: any) => {
      const updatedReq = await tx.ownerRequest.update({
        where: { id: requestId },
        data: { status: RequestStatus.APPROVED, resolvedById: approvedBy, resolvedAt: new Date() }
      });

      await tx.user.update({
        where: { id: request.userId },
        data: { role: 'OWNER' }
      });

      return updatedReq;
    });

    eventBus.emitEvent('AuditLog', {
      orgId: 'SYSTEM', userId: approvedBy, action: AuditAction.APPROVE, entityType: 'OwnerRequest', entityId: request.id, targetId: request.userId, changes: { status: RequestStatus.APPROVED }
    });

    return updated;
  }
}

export const ownerService = new OwnerService();
