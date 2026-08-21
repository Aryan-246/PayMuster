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
    const request = await prisma.$transaction(async (tx: any) => {
      const user = await tx.user.findUnique({ where: { id: userId } });
      if (!user || user.orgId !== null) {
        throw new AppError('ALREADY_AFFILIATED', 'You already belong to a company.', 409);
      }

      const existing = await tx.companyJoinRequest.findFirst({
        where: { orgId, userId, status: RequestStatus.PENDING },
      });
      if (existing) {
        throw new AppError('DUPLICATE_REQUEST', 'You already have a pending request', 400);
      }

      return tx.companyJoinRequest.create({
        data: { orgId, userId, status: RequestStatus.PENDING },
      });
    });

    eventBus.emitEvent('AuditLog', {
      orgId, userId, action: AuditAction.CREATE, entityType: 'CompanyJoinRequest', entityId: request.id, changes: {},
    });

    const user = await prisma.user.findUnique({ where: { id: userId } });
    eventBus.emitEvent('Notification', {
      orgId,
      title: 'New Join Request',
      body: `${user?.firstName || 'A user'} wants to join the company.`,
      type: 'JOIN_REQUEST',
    });

    return request;
  }

  async approveRequest(orgId: string, requestId: string, approvedBy: string) {
    const updated = await prisma.$transaction(async (tx: any) => {
      const request = await tx.companyJoinRequest.findFirst({
        where: { id: requestId, orgId, status: RequestStatus.PENDING },
      });
      if (!request) {
        throw new AppError('INVALID_REQUEST', 'Request not found or already processed', 400);
      }

      const applicant = await tx.user.findUnique({ where: { id: request.userId } });
      if (!applicant || applicant.orgId !== null) {
        throw new AppError('AFFILIATION_CONFLICT', 'The applicant already belongs to a company.', 409);
      }

      const updatedRequest = await tx.companyJoinRequest.updateMany({
        where: { id: requestId, orgId, status: RequestStatus.PENDING },
        data: { status: RequestStatus.APPROVED, resolvedById: approvedBy, resolvedAt: new Date() },
      });
      if (updatedRequest.count !== 1) {
        throw new AppError('INVALID_REQUEST', 'Request not found or already processed', 400);
      }

      const updatedUser = await tx.user.updateMany({
        where: { id: request.userId, orgId: null },
        data: { orgId, role: 'STAFF' },
      });
      if (updatedUser.count !== 1) {
        throw new AppError('AFFILIATION_CONFLICT', 'The applicant affiliation changed during approval.', 409);
      }

      await tx.session.updateMany({
        where: { userId: request.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });

      return { request: { ...request, status: RequestStatus.APPROVED }, userId: request.userId };
    });

    eventBus.emitEvent('AuditLog', {
      orgId, userId: approvedBy, action: AuditAction.APPROVE, entityType: 'CompanyJoinRequest', entityId: requestId, targetId: updated.userId, changes: { status: RequestStatus.APPROVED },
    });

    const org = await prisma.organization.findUnique({ where: { id: orgId } });
    eventBus.emitEvent('Notification', {
      orgId,
      userId: updated.userId,
      title: 'Join Request Approved',
      body: `You are now a staff member of ${org?.name || 'the company'}.`,
      type: 'JOIN_APPROVED',
    });

    return updated.request;
  }

  async rejectRequest(orgId: string, requestId: string, rejectedBy: string, reason?: string) {
    const request = await prisma.$transaction(async (tx: any) => {
      const result = await tx.companyJoinRequest.updateMany({
        where: { id: requestId, orgId, status: RequestStatus.PENDING },
        data: { status: RequestStatus.REJECTED, resolvedById: rejectedBy, resolvedAt: new Date() },
      });
      if (result.count !== 1) {
        throw new AppError('INVALID_REQUEST', 'Request not found or already processed', 400);
      }

      return tx.companyJoinRequest.findUnique({ where: { id: requestId } });
    });
    if (!request) {
      throw new AppError('INVALID_REQUEST', 'Request not found or already processed', 400);
    }

    eventBus.emitEvent('AuditLog', {
      orgId, userId: rejectedBy, action: AuditAction.REJECT, entityType: 'CompanyJoinRequest', entityId: request.id, targetId: request.userId, changes: { status: RequestStatus.REJECTED, reason },
    });

    const org = await prisma.organization.findUnique({ where: { id: orgId } });
    eventBus.emitEvent('Notification', {
      orgId,
      userId: request.userId,
      title: 'Join Request Rejected',
      body: `Your request to join ${org?.name || 'the company'} was rejected.`,
      type: 'JOIN_REJECTED',
    });

    return request;
  }
}

export const joinService = new JoinService();
