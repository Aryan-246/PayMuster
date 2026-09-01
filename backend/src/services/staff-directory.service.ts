import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';
import { eventBus } from '../lib/events.js';
import { Prisma } from '../../generated/prisma/index.js';

type DatabaseClient = typeof prisma;

export interface CreateStaffInput {
  firstName: string;
  lastName: string;
  phone: string;
  email?: string;
  workerType: string;
  joinDate?: Date;
  bankAccountNumber?: string;
  ifscCode?: string;
  upiId?: string;
  preferredPaymentMethod?: string;
}

export interface ReviewDocumentInput {
  action: 'APPROVED' | 'REJECTED' | 'VERIFIED';
  reason?: string;
}

// Fields returned under the broadly-held `view_staff` permission (SUPER_ADMIN,
// OWNER, ADMIN, SUPERVISOR, VIEWER). This deliberately EXCLUDES bankAccountNumber,
// ifscCode, upiId, preferredPaymentMethod, salaryRules and advances — sensitive
// financial PII that belongs to a tighter-scoped slice, not the roster read a
// VIEWER can call. `satisfies` validates the field names against the schema at
// compile time, so a renamed column fails the build rather than leaking silently.
const STAFF_SUMMARY_SELECT = {
  id: true,
  publicId: true,
  firstName: true,
  lastName: true,
  phone: true,
  email: true,
  workerType: true,
  status: true,
  joinDate: true,
  createdAt: true,
  updatedAt: true,
} satisfies Prisma.StaffSelect;

export interface ListStaffOptions {
  search?: string;
  status?: string;
  workerType?: string;
  page: number;
  limit: number;
}

export class StaffDirectoryService {
  constructor(private readonly db: DatabaseClient = prisma) {}

  async listStaff(orgId: string, options: ListStaffOptions) {
    const { search, status, workerType, page, limit } = options;
    const skip = (page - 1) * limit;

    // orgId is server-authoritative (from tenant context) — the roster is always
    // scoped to the caller's organization and can never be widened by the client.
    const where: any = { orgId, deletedAt: null };
    if (status && status.trim().length > 0) where.status = status.trim();
    if (workerType && workerType.trim().length > 0) where.workerType = workerType.trim();
    if (search && search.trim().length > 0) {
      const q = search.trim();
      where.OR = [
        { firstName: { contains: q, mode: 'insensitive' } },
        { lastName: { contains: q, mode: 'insensitive' } },
        { phone: { contains: q, mode: 'insensitive' } },
        { email: { contains: q, mode: 'insensitive' } },
        { publicId: { contains: q, mode: 'insensitive' } },
      ];
    }

    const [staff, total] = await Promise.all([
      this.db.staff.findMany({
        where,
        select: STAFF_SUMMARY_SELECT,
        orderBy: { firstName: 'asc' },
        skip,
        take: limit,
      }),
      this.db.staff.count({ where }),
    ]);

    return { staff, total, page, totalPages: Math.ceil(total / limit) };
  }

  async getStaffById(orgId: string, staffId: string) {
    // Both id AND orgId gate the lookup, so one tenant can never read another
    // tenant's worker by guessing an id.
    const staff = await this.db.staff.findFirst({
      where: { id: staffId, orgId, deletedAt: null },
      select: {
        ...STAFF_SUMMARY_SELECT,
        _count: {
          select: {
            documents: { where: { deletedAt: null } },
            siteAssignments: true,
          },
        },
      },
    });

    if (!staff) throw new AppError('NOT_FOUND', 'Staff member not found', 404);
    return staff;
  }

  /**
   * The Owner/ADMIN staff profile read (manage_staff-gated at the route). Unlike
   * the roster/detail reads above, this returns the financial PII slice —
   * salary rules, payment history, bank readiness — because owner.txt's staff
   * dashboard requires it and the route is restricted to manage_staff holders
   * (SUPER_ADMIN, OWNER, ADMIN), never the VIEWER roster audience.
   */
  async getStaffProfile(orgId: string, staffId: string) {
    const staff = await this.db.staff.findFirst({
      where: { id: staffId, orgId, deletedAt: null },
      select: {
        ...STAFF_SUMMARY_SELECT,
        bankAccountNumber: true,
        ifscCode: true,
        upiId: true,
        preferredPaymentMethod: true,
        salaryRules: {
          where: { deletedAt: null, isActive: true },
          select: { id: true, rateType: true, amount: true, effectiveDate: true },
          orderBy: { effectiveDate: 'desc' },
        },
        documents: {
          where: { deletedAt: null },
          select: {
            id: true,
            type: true,
            status: true,
            expiryDate: true,
            reviewedAt: true,
            rejectionReason: true,
            createdAt: true,
          },
          orderBy: { createdAt: 'desc' },
        },
        siteAssignments: {
          where: { removedAt: null, deletedAt: null },
          select: { id: true, assignedAt: true, site: { select: { id: true, publicId: true, name: true } } },
          orderBy: { assignedAt: 'desc' },
        },
        payments: {
          where: { deletedAt: null },
          select: { id: true, amount: true, mode: true, status: true, referenceId: true, approvedAt: true, createdAt: true },
          orderBy: { createdAt: 'desc' },
          take: 20,
        },
        _count: {
          select: {
            documents: { where: { deletedAt: null } },
            siteAssignments: true,
          },
        },
      },
    });

    if (!staff) throw new AppError('NOT_FOUND', 'Staff member not found', 404);

    // Blue-tick readiness (owner.txt): a worker is payment-verified when the
    // bank/UPI details are complete AND at least one document has been
    // APPROVED/VERIFIED by the company.
    const hasBankDetails = Boolean(
      (staff.bankAccountNumber && staff.ifscCode) || staff.upiId,
    );
    const hasApprovedDocument = staff.documents.some(
      (document) => document.status === 'APPROVED' || document.status === 'VERIFIED',
    );

    return {
      ...staff,
      verification: {
        bankDetailsComplete: hasBankDetails,
        documentApproved: hasApprovedDocument,
        verified: hasBankDetails && hasApprovedDocument,
      },
    };
  }

  /**
   * Manual worker add (owner.txt staff section). The publicId follows the
   * existing PM-* convention. Duplicate phone within the same org is
   * rejected — a roster is one row per real worker.
   */
  async createStaff(orgId: string, actorUserId: string, input: CreateStaffInput) {
    const duplicate = await this.db.staff.findFirst({
      where: { orgId, phone: input.phone, deletedAt: null },
      select: { id: true },
    });
    if (duplicate) {
      throw new AppError('STAFF_PHONE_EXISTS', 'A worker with this phone number already exists in this company.', 409);
    }

    const publicId = `PM-STF-${Math.floor(100000 + Math.random() * 900000)}`;
    const staff = await this.db.staff.create({
      data: {
        orgId,
        publicId,
        firstName: input.firstName,
        lastName: input.lastName,
        phone: input.phone,
        email: input.email,
        workerType: input.workerType as any,
        status: 'ACTIVE',
        joinDate: input.joinDate ?? new Date(),
        bankAccountNumber: input.bankAccountNumber,
        ifscCode: input.ifscCode,
        upiId: input.upiId,
        preferredPaymentMethod: input.preferredPaymentMethod as any,
      },
      select: STAFF_SUMMARY_SELECT,
    });

    eventBus.emitEvent('AuditLog', {
      orgId,
      userId: actorUserId,
      action: 'CREATE',
      entityType: 'Staff',
      entityId: staff.id,
      targetId: staff.id,
      changes: { firstName: input.firstName, lastName: input.lastName, workerType: input.workerType },
    });

    return staff;
  }

  /**
   * List a worker's documents for the company review queue (manage_documents
   * audience). Never returns the file bytes — only metadata; viewing goes
   * through the existing signed-URL flow.
   */
  async listStaffDocuments(orgId: string, staffId: string, status?: string) {
    const staff = await this.db.staff.findFirst({
      where: { id: staffId, orgId, deletedAt: null },
      select: { id: true },
    });
    if (!staff) throw new AppError('NOT_FOUND', 'Staff member not found', 404);

    return this.db.staffDocument.findMany({
      where: {
        staffId,
        orgId,
        deletedAt: null,
        ...(status && { status: status as any }),
      },
      select: {
        id: true,
        type: true,
        status: true,
        expiryDate: true,
        version: true,
        resubmissionCount: true,
        reviewedAt: true,
        rejectionReason: true,
        originalFilename: true,
        createdAt: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Approve / reject / verify a staff document (owner.txt: the owner checks
   * documents and gives the blue tick). Rejection requires a reason, which the
   * worker sees to resubmit.
   */
  async reviewStaffDocument(
    orgId: string,
    staffId: string,
    documentId: string,
    reviewerId: string,
    input: ReviewDocumentInput,
  ) {
    return this.db.$transaction(async (tx) => {
      const staff = await tx.staff.findFirst({
        where: { id: staffId, orgId, deletedAt: null },
        select: { id: true, email: true },
      });
      if (!staff) throw new AppError('NOT_FOUND', 'Staff member not found', 404);

      const document = await tx.staffDocument.findFirst({
        where: { id: documentId, staffId, orgId, deletedAt: null },
        select: { id: true, status: true },
      });
      if (!document) throw new AppError('NOT_FOUND', 'Document not found', 404);

      const updated = await tx.staffDocument.update({
        where: { id: documentId },
        data: {
          status: input.action,
          reviewerId,
          reviewedAt: new Date(),
          rejectionReason: input.action === 'REJECTED' ? input.reason : null,
        },
        select: { id: true, type: true, status: true, rejectionReason: true, reviewedAt: true },
      });

      await tx.auditLog.create({
        data: {
          action: input.action === 'REJECTED' ? 'REJECT' : 'APPROVE',
          entityType: 'StaffDocument',
          entityId: documentId,
          changes: { action: input.action, reason: input.reason ?? null },
          userId: reviewerId,
          orgId,
          targetId: staffId,
        },
      });

      // Target the staff member's app account (matched by email in the same
      // org) when one exists, so the review result lands in their notification
      // center. Manually-added workers without an account are simply not
      // notified — no fabricated recipients.
      let notifyUserId: string | undefined;
      if (staff.email) {
        const linkedUser = await tx.user.findFirst({
          where: { orgId, email: { equals: staff.email, mode: 'insensitive' }, deletedAt: null },
          select: { id: true },
        });
        notifyUserId = linkedUser?.id;
      }

      eventBus.emitEvent('Notification', {
        orgId,
        ...(notifyUserId && { userId: notifyUserId }),
        title: input.action === 'REJECTED' ? 'Document rejected' : 'Document approved',
        body:
          input.action === 'REJECTED'
            ? `Your document was rejected: ${input.reason ?? 'please contact your company.'}`
            : 'Your document has been approved.',
        type: 'DOCUMENT_REVIEW',
      });

      return updated;
    });
  }
}

export const staffDirectoryService = new StaffDirectoryService();
