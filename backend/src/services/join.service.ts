import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';
import { eventBus, Events } from '../lib/events.js';
import { AuditAction, RequestStatus } from '../../generated/prisma/index.js';

export class JoinService {
  async getJoinRequests(orgId: string) {
    return prisma.companyJoinRequest.findMany({
      where: { orgId, status: RequestStatus.PENDING },
      include: {
        user: { select: { id: true, firstName: true, email: true } }
      }
    });
  }

  async requestJoin(orgId: string, userId: string) {
    const existing = await prisma.companyJoinRequest.findFirst({
      where: { orgId, userId, status: RequestStatus.PENDING }
    });
    if (existing) throw new AppError('DUPLICATE_REQUEST', 'You already have a pending request', 400);

    const request = await prisma.companyJoinRequest.create({
      data: { orgId, userId, status: RequestStatus.PENDING }
    });

    eventBus.emitEvent('AuditLog', {
      orgId, userId, action: AuditAction.CREATE, entityType: 'CompanyJoinRequest', entityId: request.id, changes: { }
    });

    const user = await prisma.user.findUnique({ where: { id: userId } });
    
    eventBus.emitEvent('Notification', {
      orgId,
      title: 'New Join Request',
      body: `${user?.firstName || 'A user'} wants to join the company.`,
      type: 'JOIN_REQUEST'
    });

    return request;
  }

  async approveRequest(orgId: string, requestId: string, approvedBy: string) {
    const request = await prisma.companyJoinRequest.findFirst({ where: { id: requestId, orgId } });
    if (!request || request.status !== RequestStatus.PENDING) throw new AppError('INVALID_REQUEST', 'Request not found or already processed', 400);

    const updated = await prisma.$transaction(async (tx: any) => {
      const updatedReq = await tx.companyJoinRequest.update({
        where: { id: requestId },
        data: { status: RequestStatus.APPROVED, resolvedById: approvedBy, resolvedAt: new Date() }
      });

      // Update user to belong to this org with role WORKER
      await tx.user.update({
        where: { id: request.userId },
        data: { orgId, role: 'STAFF' }
      });

      return updatedReq;
    });

    eventBus.emitEvent('AuditLog', {
      orgId, userId: approvedBy, action: AuditAction.APPROVE, entityType: 'CompanyJoinRequest', entityId: request.id, targetId: request.userId, changes: { status: RequestStatus.APPROVED }
    });
    
    const org = await prisma.organization.findUnique({ where: { id: orgId } });

    eventBus.emitEvent('Notification', {
      orgId,
      userId: request.userId,
      title: 'Join Request Approved',
      body: `You are now a staff member of ${org?.name || 'the company'}.`,
      type: 'JOIN_APPROVED'
    });

    return updated;
  }

  async rejectRequest(orgId: string, requestId: string, rejectedBy: string, reason?: string) {
    const request = await prisma.companyJoinRequest.update({
      where: { id: requestId },
      data: { status: RequestStatus.REJECTED, resolvedById: rejectedBy, resolvedAt: new Date() }
    });

    eventBus.emitEvent('AuditLog', {
      orgId, userId: rejectedBy, action: AuditAction.REJECT, entityType: 'CompanyJoinRequest', entityId: request.id, targetId: request.userId, changes: { status: RequestStatus.REJECTED, reason }
    });
    
    const org = await prisma.organization.findUnique({ where: { id: orgId } });

    eventBus.emitEvent('Notification', {
      orgId,
      userId: request.userId,
      title: 'Join Request Rejected',
      body: `Your request to join ${org?.name || 'the company'} was rejected.`,
      type: 'JOIN_REJECTED'
    });

    return request;
  }
}

export const joinService = new JoinService();
