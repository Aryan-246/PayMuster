import crypto from 'node:crypto';
import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';
import { AuditAction, CompanyStatus, Prisma, RequestStatus, UserRole } from '../../generated/prisma/index.js';
import { allocateNextPublicId } from '../lib/public-id.js';

const OWNER_REQUEST_TRANSACTION_ATTEMPTS = 3;

function isRetryableTransactionConflict(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { code?: unknown }).code === 'P2034'
  );
}

export class OwnerService {
  async getMyRequest(userId: string) {
    return prisma.ownerRequest.findFirst({
      where: { userId, deletedAt: null },
      orderBy: { createdAt: 'desc' },
    });
  }

  async requestOwnership(
    userId: string,
    companyName: string,
    gstin?: string,
    companyAddress?: string,
    businessRegistrationUrl?: string,
    identityProofUrl?: string,
  ) {
    const publicId = await allocateNextPublicId('PM-OWN', 'OwnerRequest');

    for (let attempt = 1; attempt <= OWNER_REQUEST_TRANSACTION_ATTEMPTS; attempt += 1) {
      try {
        return await prisma.$transaction(async (tx) => {
          await tx.$queryRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`owner-request:${userId}`}, 0))`;

          const user = await tx.user.findFirst({
            where: {
              id: userId,
              deletedAt: null,
              isActive: true,
              isDisabled: false,
            },
            select: { id: true, orgId: true, role: true },
          });
          if (!user) {
            throw new AppError('ACCOUNT_INELIGIBLE', 'This account cannot submit an owner request.', 403);
          }
          if (user.orgId !== null || user.role === UserRole.SUPER_ADMIN) {
            throw new AppError(
              'COMPANY_CONTEXT_CONFLICT',
              'Leave the current company context before requesting ownership of a new company.',
              409,
            );
          }

          const existing = await tx.ownerRequest.findFirst({
            where: { userId, status: RequestStatus.PENDING, deletedAt: null },
            select: { id: true },
          });
          if (existing) {
            throw new AppError('DUPLICATE_REQUEST', 'You already have a pending owner request.', 409);
          }

          const request = await tx.ownerRequest.create({
            data: {
              publicId,
              userId,
              companyName,
              companyAddress,
              gstin,
              businessRegistrationUrl,
              identityProofUrl,
              status: RequestStatus.PENDING,
            },
          });

          await tx.auditLog.create({
            data: {
              orgId: null,
              userId,
              action: AuditAction.CREATE,
              entityType: 'OwnerRequest',
              entityId: request.id,
              targetId: userId,
              changes: { companyName, gstin: gstin ?? null },
            },
          });

          return request;
        }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
      } catch (error) {
        if (!isRetryableTransactionConflict(error)) {
          throw error;
        }
        if (attempt === OWNER_REQUEST_TRANSACTION_ATTEMPTS) {
          throw new AppError(
            'OWNER_REQUEST_CONFLICT',
            'The owner request changed while it was being submitted. Please try again.',
            409,
          );
        }
      }
    }

    throw new AppError('OWNER_REQUEST_CONFLICT', 'Unable to submit the owner request.', 409);
  }

  async approveRequest(requestId: string, approvedBy: string) {
    const companyPublicId = await allocateNextPublicId('PM-CMP', 'Organization');
    const generatedUserPublicId = await allocateNextPublicId('PM-USR', 'User');
    const joinCode = `JOIN-${crypto.randomBytes(6).toString('hex').toUpperCase()}`;

    return prisma.$transaction(async (tx) => {
      const request = await tx.ownerRequest.findFirst({
        where: { id: requestId, deletedAt: null },
        include: { user: true },
      });
      if (!request) {
        throw new AppError('OWNER_REQUEST_NOT_FOUND', 'Owner request not found.', 404);
      }
      if (request.status !== RequestStatus.PENDING) {
        throw new AppError(
          'OWNER_REQUEST_INVALID_STATE',
          'This owner request was already processed or changed by another reviewer.',
          409,
        );
      }
      if (
        request.user.deletedAt !== null ||
        !request.user.isActive ||
        request.user.isDisabled ||
        request.user.orgId !== null ||
        request.user.role === UserRole.SUPER_ADMIN
      ) {
        throw new AppError(
          'OWNER_APPLICANT_INELIGIBLE',
          'The applicant is no longer eligible to create a company.',
          409,
        );
      }

      const transition = await tx.ownerRequest.updateMany({
        where: {
          id: requestId,
          status: RequestStatus.PENDING,
          deletedAt: null,
        },
        data: {
          status: RequestStatus.APPROVED,
          resolvedById: approvedBy,
          resolvedAt: new Date(),
          deleteReason: null,
        },
      });
      if (transition.count !== 1) {
        throw new AppError(
          'OWNER_REQUEST_INVALID_STATE',
          'This owner request was already processed or changed by another reviewer.',
          409,
        );
      }

      const organization = await tx.organization.create({
        data: {
          name: request.companyName,
          publicId: companyPublicId,
          joinCode,
          gstin: request.gstin || null,
          status: CompanyStatus.ACTIVE,
        },
      });

      const userTransition = await tx.user.updateMany({
        where: {
          id: request.userId,
          orgId: null,
          deletedAt: null,
          isActive: true,
          isDisabled: false,
          role: { not: UserRole.SUPER_ADMIN },
        },
        data: {
          role: UserRole.OWNER,
          orgId: organization.id,
          publicId: request.user.publicId || generatedUserPublicId,
        },
      });
      if (userTransition.count !== 1) {
        throw new AppError(
          'OWNER_APPLICANT_INELIGIBLE',
          'The applicant is no longer eligible to create a company.',
          409,
        );
      }

      await tx.notification.create({
        data: {
          orgId: organization.id,
          userId: request.userId,
          title: 'Owner Request Approved',
          body: `Your request to create "${organization.name}" was approved.`,
          type: 'OWNER_PROMOTION',
          deepLink: '/app/owner-dashboard',
        },
      });

      await tx.auditLog.create({
        data: {
          orgId: organization.id,
          userId: approvedBy,
          action: AuditAction.APPROVE,
          entityType: 'OwnerRequest',
          entityId: request.id,
          targetId: request.userId,
          changes: {
            previousStatus: request.status,
            status: RequestStatus.APPROVED,
            orgId: organization.id,
            companyName: organization.name,
          },
        },
      });

      const [updatedRequest, updatedUser] = await Promise.all([
        tx.ownerRequest.findUniqueOrThrow({ where: { id: requestId } }),
        tx.user.findUniqueOrThrow({ where: { id: request.userId } }),
      ]);

      return { request: updatedRequest, organization, user: updatedUser };
    });
  }

  async rejectRequest(requestId: string, rejectedBy: string, reason?: string) {
    const normalizedReason = reason?.trim() || 'Requirements not met';

    return prisma.$transaction(async (tx) => {
      const request = await tx.ownerRequest.findFirst({
        where: { id: requestId, deletedAt: null },
      });
      if (!request) {
        throw new AppError('OWNER_REQUEST_NOT_FOUND', 'Owner request not found.', 404);
      }

      const transition = await tx.ownerRequest.updateMany({
        where: {
          id: requestId,
          status: RequestStatus.PENDING,
          deletedAt: null,
        },
        data: {
          status: RequestStatus.REJECTED,
          resolvedById: rejectedBy,
          resolvedAt: new Date(),
          deleteReason: normalizedReason,
        },
      });
      if (transition.count !== 1) {
        throw new AppError(
          'OWNER_REQUEST_INVALID_STATE',
          'This owner request was already processed or changed by another reviewer.',
          409,
        );
      }

      await tx.notification.create({
        data: {
          orgId: null,
          userId: request.userId,
          title: 'Owner Request Status',
          body: `Your request to create "${request.companyName}" was not approved. Reason: ${normalizedReason}`,
          type: 'OWNER_PROMOTION',
          deepLink: '/app/promotion-status',
        },
      });

      await tx.auditLog.create({
        data: {
          orgId: null,
          userId: rejectedBy,
          action: AuditAction.REJECT,
          entityType: 'OwnerRequest',
          entityId: request.id,
          targetId: request.userId,
          changes: {
            previousStatus: request.status,
            status: RequestStatus.REJECTED,
            reason: normalizedReason,
          },
        },
      });

      return tx.ownerRequest.findUniqueOrThrow({ where: { id: requestId } });
    });
  }
}

export const ownerService = new OwnerService();
