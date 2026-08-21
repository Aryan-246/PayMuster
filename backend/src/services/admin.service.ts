import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';
import { AuditAction, UserRole, type User } from '../../generated/prisma/index.js';
import { generateSecureToken, hashPassword } from '../lib/auth-utils.js';
import { documentService } from './document.service.js';
import { ownerService } from './owner.service.js';

interface AdminActionContext {
  reason?: string;
  requestId?: string;
  ipAddress?: string;
  userAgent?: string;
}

export class AdminService {
  async getDashboardCounts() {
    const [users, owners, companies, sites, attendance, payroll, pendingRequests, onlineUsers, blockedUsers, deletedUsers] = await Promise.all([
      prisma.user.count({ where: { deletedAt: null } }),
      prisma.user.count({ where: { role: 'OWNER', deletedAt: null } }),
      prisma.organization.count({ where: { deletedAt: null } }),
      prisma.site.count({ where: { deletedAt: null } }),
      prisma.attendanceRecord.count({ where: { deletedAt: null } }),
      prisma.payRun.count({ where: { deletedAt: null } }),
      prisma.ownerRequest.count({ where: { status: 'PENDING' } }),
      prisma.session.count({ where: { revokedAt: null } }),
      prisma.user.count({ where: { isDisabled: true, deletedAt: null } }),
      prisma.user.count({ where: { status: 'DELETED' } }),
    ]);

    const recentAuditLogs = await prisma.auditLog.findMany({
      take: 10,
      orderBy: { createdAt: 'desc' },
      include: {
        user: { select: { id: true, firstName: true, lastName: true, email: true, publicId: true } },
        org: { select: { id: true, name: true, publicId: true } },
      }
    });

    return {
      users, owners, companies, sites, attendance, payroll,
      pendingRequests, onlineUsers, blockedUsers, deletedUsers,
      recentAuditLogs
    };
  }

  async searchUsers(query?: string, role?: string, status?: string, page = 1, limit = 50) {
    const skip = (page - 1) * limit;
    const where: any = { deletedAt: null };

    if (query && query.trim().length > 0) {
      const q = query.trim();
      where.OR = [
        { email: { contains: q, mode: 'insensitive' } },
        { firstName: { contains: q, mode: 'insensitive' } },
        { lastName: { contains: q, mode: 'insensitive' } },
        { phone: { contains: q, mode: 'insensitive' } },
        { publicId: { contains: q, mode: 'insensitive' } }
      ];
    }

    if (role && role !== 'ALL') {
      where.role = role as UserRole;
    }

    if (status) {
      if (status === 'BLOCKED') {
        where.isDisabled = true;
      } else if (status === 'ACTIVE') {
        where.isDisabled = false;
        where.isActive = true;
      }
    }

    const [users, total] = await Promise.all([
      prisma.user.findMany({
        where,
        select: {
          id: true,
          publicId: true,
          email: true,
          phone: true,
          firstName: true,
          lastName: true,
          role: true,
          status: true,
          isDisabled: true,
          createdAt: true,
          lastLoginAt: true,
          org: { select: { id: true, name: true, publicId: true, joinCode: true } }
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      prisma.user.count({ where }),
    ]);

    return {
      users,
      total,
      page,
      totalPages: Math.ceil(total / limit)
    };
  }

  async getUserById(targetUserId: string) {
    const user = await prisma.user.findUnique({
      where: { id: targetUserId },
      include: {
        org: {
          select: {
            id: true, name: true, publicId: true, joinCode: true, status: true, gstin: true, createdAt: true
          }
        },
        promotionRequests: { orderBy: { createdAt: 'desc' }, take: 5 },
        joinRequests: { orderBy: { createdAt: 'desc' }, take: 5 },
        ownerRequests: { orderBy: { createdAt: 'desc' }, take: 5 },
      }
    });

    if (!user) throw new AppError('NOT_FOUND', 'User not found', 404);

    // Fetch related staff & documents if org exists
    let staffRecord = null;
    let documents: any[] = [];
    if (user.orgId && user.email) {
      staffRecord = await prisma.staff.findFirst({
        where: { orgId: user.orgId, email: user.email },
        include: { documents: true }
      });
      if (staffRecord) {
        documents = staffRecord.documents;
      }
    }

    const auditLogs = await prisma.auditLog.findMany({
      where: { OR: [{ userId: targetUserId }, { targetId: targetUserId }] },
      orderBy: { createdAt: 'desc' },
      take: 10,
    });

    return {
      user: {
        id: user.id,
        publicId: user.publicId,
        email: user.email,
        phone: user.phone,
        firstName: user.firstName,
        lastName: user.lastName,
        name: [user.firstName, user.lastName].filter(Boolean).join(' ') || user.email || 'User',
        role: user.role,
        status: user.status,
        isDisabled: user.isDisabled,
        emailVerified: user.emailVerified,
        createdAt: user.createdAt,
        lastLoginAt: user.lastLoginAt,
        org: user.org,
      },
      staffRecord,
      documents,
      ownerRequests: user.ownerRequests,
      promotionRequests: user.promotionRequests,
      joinRequests: user.joinRequests,
      auditLogs,
    };
  }

  async getOwnerRequests(status?: string) {
    const where: any = {};
    if (status && status !== 'ALL') {
      where.status = status;
    }

    const requests = await prisma.ownerRequest.findMany({
      where,
      include: {
        user: {
          select: {
            id: true,
            publicId: true,
            email: true,
            firstName: true,
            lastName: true,
            phone: true,
            role: true,
            status: true,
          }
        }
      },
      orderBy: { createdAt: 'desc' }
    });

    return requests;
  }

  async approveOwnerRequest(requestId: string, approvedBy: string) {
    return ownerService.approveRequest(requestId, approvedBy);
  }

  async rejectOwnerRequest(requestId: string, rejectedBy: string, reason?: string) {
    return ownerService.rejectRequest(requestId, rejectedBy, reason);
  }

  async getCompanies(search?: string, page = 1, limit = 50) {
    const skip = (page - 1) * limit;
    const where: any = { deletedAt: null };

    if (search && search.trim().length > 0) {
      const q = search.trim();
      where.OR = [
        { name: { contains: q, mode: 'insensitive' } },
        { publicId: { contains: q, mode: 'insensitive' } },
        { joinCode: { contains: q, mode: 'insensitive' } },
        { gstin: { contains: q, mode: 'insensitive' } }
      ];
    }

    const [companies, total] = await Promise.all([
      prisma.organization.findMany({
        where,
        include: {
          users: {
            where: { role: 'OWNER', deletedAt: null },
            select: { id: true, publicId: true, firstName: true, lastName: true, email: true, phone: true }
          },
          _count: {
            select: {
              users: { where: { deletedAt: null } },
              sites: { where: { deletedAt: null } },
              staff: { where: { deletedAt: null } },
              attendanceRecords: { where: { deletedAt: null } },
            }
          }
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      prisma.organization.count({ where })
    ]);

    return {
      companies,
      total,
      page,
      totalPages: Math.ceil(total / limit)
    };
  }

  async getCompanyDetail(orgId: string) {
    const company = await prisma.organization.findFirst({
      where: { id: orgId, deletedAt: null },
      include: {
        users: {
          where: { deletedAt: null },
          select: {
            id: true, publicId: true, email: true, firstName: true, lastName: true, role: true, isDisabled: true, status: true
          }
        },
        sites: {
          where: { deletedAt: null },
          select: {
            id: true, publicId: true, name: true, address: true, status: true, createdAt: true
          }
        },
        settings: true,
        _count: {
          select: {
            users: { where: { deletedAt: null } },
            sites: { where: { deletedAt: null } },
            staff: { where: { deletedAt: null } },
            attendanceRecords: { where: { deletedAt: null } },
            payRuns: { where: { deletedAt: null } },
          }
        }
      }
    });

    if (!company) throw new AppError('NOT_FOUND', 'Company not found', 404);

    const auditLogs = await prisma.auditLog.findMany({
      where: { orgId },
      orderBy: { createdAt: 'desc' },
      take: 20
    });

    return {
      company,
      auditLogs
    };
  }

  async getSites(search?: string, orgId?: string, page = 1, limit = 50) {
    const skip = (page - 1) * limit;
    const where: any = { deletedAt: null };

    if (orgId) where.orgId = orgId;
    if (search && search.trim().length > 0) {
      const q = search.trim();
      where.OR = [
        { name: { contains: q, mode: 'insensitive' } },
        { address: { contains: q, mode: 'insensitive' } },
        { publicId: { contains: q, mode: 'insensitive' } }
      ];
    }

    const [sites, total] = await Promise.all([
      prisma.site.findMany({
        where: {
          ...where,
          org: { deletedAt: null },
        },
        include: {
          org: { select: { id: true, name: true, publicId: true } },
          _count: {
            select: {
              siteAssignments: { where: { deletedAt: null } },
              attendanceRecords: { where: { deletedAt: null } },
              siteMembers: { where: { deletedAt: null } },
            }
          }
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      prisma.site.count({
        where: {
          ...where,
          org: { deletedAt: null },
        },
      })
    ]);

    return { sites, total, page, totalPages: Math.ceil(total / limit) };
  }

  async getAttendanceRecords(search?: string, orgId?: string, siteId?: string, status?: string, page = 1, limit = 50) {
    const skip = (page - 1) * limit;
    const where: any = { deletedAt: null };

    if (orgId) where.orgId = orgId;
    if (siteId) where.siteId = siteId;
    if (status && status !== 'ALL') where.status = status;
    if (search && search.trim().length > 0) {
      const q = search.trim();
      where.OR = [
        { publicId: { contains: q, mode: 'insensitive' } },
        { staff: { firstName: { contains: q, mode: 'insensitive' } } },
        { staff: { lastName: { contains: q, mode: 'insensitive' } } },
        { staff: { email: { contains: q, mode: 'insensitive' } } },
        { site: { name: { contains: q, mode: 'insensitive' } } },
        { org: { name: { contains: q, mode: 'insensitive' } } },
      ];
    }

    const [records, total, groupedStatuses] = await Promise.all([
      prisma.attendanceRecord.findMany({
        where,
        include: {
          org: { select: { id: true, name: true, publicId: true } },
          site: { select: { id: true, name: true, publicId: true } },
          staff: { select: { id: true, firstName: true, lastName: true, email: true, phone: true, publicId: true } },
        },
        orderBy: { date: 'desc' },
        skip,
        take: limit
      }),
      prisma.attendanceRecord.count({ where }),
      prisma.attendanceRecord.groupBy({
        by: ['status'],
        where,
        _count: { _all: true },
      }),
    ]);

    const byStatus = groupedStatuses.reduce<Record<string, number>>((counts, group) => {
      counts[group.status] = group._count._all;
      return counts;
    }, {});

    return {
      records,
      total,
      page,
      totalPages: Math.ceil(total / limit),
      summary: { total, byStatus },
    };
  }

  async getAttendanceDetail(id: string, orgId?: string, siteId?: string) {
    const where: any = { id, deletedAt: null };
    if (orgId) where.orgId = orgId;
    if (siteId) where.siteId = siteId;

    const record = await prisma.attendanceRecord.findFirst({
      where,
      include: {
        org: { select: { id: true, name: true, publicId: true } },
        site: { select: { id: true, name: true, publicId: true } },
        staff: { select: { id: true, firstName: true, lastName: true, email: true, phone: true, publicId: true } },
        markedBy: { select: { id: true, firstName: true, lastName: true, email: true, publicId: true } },
        correctionRequests: true,
      },
    });

    if (!record) throw new AppError('NOT_FOUND', 'Attendance record not found', 404);
    return record;
  }

  async getPayrollRecords(orgId?: string, status?: string, page = 1, limit = 50) {
    const skip = (page - 1) * limit;
    const baseWhere: any = { deletedAt: null };
    const selectedStatus = status && status !== 'ALL' ? status : undefined;
    const where: any = { ...baseWhere };

    if (orgId) {
      baseWhere.orgId = orgId;
      where.orgId = orgId;
    }
    if (selectedStatus) where.payCycle = { status: selectedStatus };

    const statusWhere = (payCycleStatus: string) => ({
      ...baseWhere,
      ...(orgId && { orgId }),
      payCycle: { status: selectedStatus ?? payCycleStatus },
    });

    const [payRuns, aggregate, statusCounts] = await Promise.all([
      prisma.payRun.findMany({
        where,
        include: {
          org: { select: { id: true, name: true, publicId: true } },
          payCycle: { select: { id: true, startDate: true, endDate: true, status: true } },
          _count: { select: { payRunItems: { where: { deletedAt: null } } } }
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit
      }),
      prisma.payRun.aggregate({
        where,
        _count: { _all: true },
        _sum: { totalAmount: true },
      }),
      selectedStatus
        ? prisma.payRun.count({ where: statusWhere(selectedStatus) }).then((count) => ({
          DRAFT: selectedStatus === 'DRAFT' ? count : 0,
          CALCULATED: selectedStatus === 'CALCULATED' ? count : 0,
          APPROVED: selectedStatus === 'APPROVED' ? count : 0,
          PAID: selectedStatus === 'PAID' ? count : 0,
        }))
        : Promise.all([
          prisma.payRun.count({ where: statusWhere('DRAFT') }),
          prisma.payRun.count({ where: statusWhere('CALCULATED') }),
          prisma.payRun.count({ where: statusWhere('APPROVED') }),
          prisma.payRun.count({ where: statusWhere('PAID') }),
        ]).then(([draft, calculated, approved, paid]) => ({
          DRAFT: draft,
          CALCULATED: calculated,
          APPROVED: approved,
          PAID: paid,
        })),
    ]);

    const total = aggregate._count._all;
    return {
      payRuns,
      total,
      page,
      totalPages: Math.ceil(total / limit),
      summary: {
        total,
        totalAmount: aggregate._sum.totalAmount,
        byStatus: statusCounts,
      },
    };
  }

  async getPayrollDetail(id: string, orgId?: string) {
    const where: any = { id, deletedAt: null };
    if (orgId) where.orgId = orgId;

    const record = await prisma.payRun.findFirst({
      where,
      include: {
        org: { select: { id: true, name: true, publicId: true } },
        payCycle: { select: { id: true, startDate: true, endDate: true, status: true } },
        approvedBy: { select: { id: true, firstName: true, lastName: true, email: true, publicId: true } },
        payRunItems: {
          where: {
            deletedAt: null,
            ...(orgId && { orgId }),
          },
          select: {
            id: true,
            orgId: true,
            staffId: true,
            grossPay: true,
            deductions: true,
            additions: true,
            arrears: true,
            netPay: true,
            staff: {
              select: {
                id: true,
                publicId: true,
                firstName: true,
                lastName: true,
                email: true,
                workerType: true,
                status: true,
              },
            },
          },
        },
      },
    });

    if (!record) throw new AppError('NOT_FOUND', 'Payroll run not found', 404);
    return record;
  }

  async getAuditLogs(entityType?: string, action?: string, page = 1, limit = 50) {
    const skip = (page - 1) * limit;
    const where: any = {};

    if (entityType && entityType !== 'ALL') where.entityType = entityType;
    if (action && action !== 'ALL') where.action = action;

    const [auditLogs, total] = await Promise.all([
      prisma.auditLog.findMany({
        where,
        include: {
          user: { select: { id: true, publicId: true, firstName: true, lastName: true, email: true } },
          org: { select: { id: true, publicId: true, name: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit
      }),
      prisma.auditLog.count({ where })
    ]);

    return { auditLogs, total, page, totalPages: Math.ceil(total / limit) };
  }

  async getNotifications(page = 1, limit = 50) {
    const skip = (page - 1) * limit;

    const [notifications, total] = await Promise.all([
      prisma.notification.findMany({
        include: {
          user: { select: { id: true, publicId: true, firstName: true, lastName: true, email: true } },
          org: { select: { id: true, publicId: true, name: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit
      }),
      prisma.notification.count()
    ]);

    return { notifications, total, page, totalPages: Math.ceil(total / limit) };
  }

  async executeAction(
    targetUserId: string,
    actionBy: string,
    action: string,
    role?: UserRole,
    context: AdminActionContext = {},
  ) {
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
        if (role === 'SUPER_ADMIN') {
          throw new AppError('FORBIDDEN', 'Super Admin role cannot be assigned through user actions', 403);
        }
        return this.updateUserRole(targetUserId, role, actionBy);

      case 'SUSPEND':
        return this.updateUserStatus(targetUserId, true, actionBy, 'SUSPENDED');

      case 'BLOCK':
        return this.updateUserStatus(targetUserId, true, actionBy, 'BLOCKED');

      case 'UNSUSPEND':
      case 'UNBLOCK':
      case 'RESTORE':
        return this.updateUserStatus(targetUserId, false, actionBy);

      case 'DELETE':
        return this.softDeleteUser(user, actionBy, context);

      default:
        throw new AppError('BAD_REQUEST', 'Invalid action', 400);
    }
  }

  private async softDeleteUser(
    user: User,
    actionBy: string,
    context: AdminActionContext,
  ) {
    const reason = context.reason?.trim();
    if (!reason) {
      throw new AppError('REASON_REQUIRED', 'Deletion reason is required', 400);
    }
    if (reason.length > 1000) {
      throw new AppError('BAD_REQUEST', 'Deletion reason must be 1000 characters or fewer', 400);
    }
    if (user.status === 'DELETED' || user.deletedAt) {
      throw new AppError('CONFLICT', 'User account has already been deleted', 409);
    }

    const deletedAt = new Date();
    const beforeValue = {
      role: user.role,
      orgId: user.orgId,
      status: user.status,
      isActive: user.isActive,
      isDisabled: user.isDisabled,
      deletedAt: null,
      deleteReason: user.deleteReason,
      deletedBy: user.deletedBy,
    };
    const afterValue = {
      ...beforeValue,
      status: 'DELETED',
      isActive: false,
      isDisabled: true,
      deletedAt: deletedAt.toISOString(),
      deleteReason: reason,
      deletedBy: actionBy,
    };

    await prisma.$transaction(async (tx) => {
      const deleted = await tx.user.updateMany({
        where: {
          id: user.id,
          status: { not: 'DELETED' },
          deletedAt: null,
        },
        data: {
          status: 'DELETED',
          isActive: false,
          isDisabled: true,
          deletedAt,
          deleteReason: reason,
          deletedBy: actionBy,
        },
      });
      if (deleted.count !== 1) {
        throw new AppError('CONFLICT', 'User account has already been deleted', 409);
      }
      await tx.session.updateMany({
        where: { userId: user.id, revokedAt: null },
        data: { revokedAt: deletedAt },
      });
      await tx.authOtp.updateMany({
        where: { userId: user.id, used: false },
        data: { used: true, usedAt: deletedAt },
      });
      await tx.notification.create({
        data: {
          orgId: user.orgId,
          userId: user.id,
          title: 'Account Deleted',
          body: 'Your PayMuster account has been deleted by an administrator.',
          type: 'USER_DELETION',
          deepLink: null,
        },
      });
      await tx.auditLog.create({
        data: {
          orgId: user.orgId,
          userId: actionBy,
          action: AuditAction.DELETE,
          entityType: 'User',
          entityId: user.id,
          targetId: user.id,
          changes: {
            reason,
            sessionsRevoked: true,
            authOtpsInvalidated: true,
            organizationPreserved: true,
            businessHistoryPreserved: true,
          },
          beforeValue,
          afterValue,
          requestId: context.requestId,
          ipAddress: context.ipAddress,
          userAgent: context.userAgent,
        },
      });
    });

    return { message: 'User account deleted', deletedAt: deletedAt.toISOString() };
  }

  async resetPassword(targetUserId: string, actionBy: string) {
    const tempPassword = `Pm-${generateSecureToken(18)}`;
    const passwordHash = await hashPassword(tempPassword);
    const revokedAt = new Date();

    await prisma.$transaction(async (tx) => {
      const current = await tx.user.findUnique({ where: { id: targetUserId } });
      if (!current) throw new AppError('NOT_FOUND', 'User not found', 404);
      if (current.role === UserRole.SUPER_ADMIN) {
        throw new AppError('FORBIDDEN', 'Super Admin accounts cannot be modified', 403);
      }
      this.assertMutableTarget(current, 'Password reset');
      if (current.isDisabled) {
        throw new AppError('CONFLICT', 'Disabled user accounts cannot be used for password reset', 409);
      }

      const updated = await tx.user.updateMany({
        where: {
          id: targetUserId,
          orgId: current.orgId,
          role: current.role,
          deletedAt: null,
          isActive: true,
          isDisabled: false,
          status: current.status,
        },
        data: { passwordHash },
      });
      if (updated.count !== 1) {
        throw new AppError('CONFLICT', 'User account changed state before the password reset completed', 409);
      }

      await tx.session.updateMany({
        where: { userId: targetUserId, revokedAt: null },
        data: { revokedAt },
      });
      await tx.notification.create({
        data: {
          orgId: current.orgId,
          userId: targetUserId,
          title: 'Password Reset',
          body: 'An administrator reset your password. Use the temporary password provided securely and change it after signing in.',
          type: 'PASSWORD_RESET',
          deepLink: null,
        },
      });
      await tx.auditLog.create({
        data: {
          orgId: current.orgId,
          userId: actionBy,
          action: AuditAction.UPDATE,
          entityType: 'User',
          entityId: targetUserId,
          targetId: targetUserId,
          changes: { passwordReset: true, sessionsRevoked: true },
        },
      });
    });

    return { message: 'Password reset successfully', tempPassword };
  }

  private async updateUserRole(targetUserId: string, newRole: UserRole, actionBy: string) {
    const revokedAt = new Date();
    return prisma.$transaction(async (tx) => {
      const current = await tx.user.findUnique({ where: { id: targetUserId } });
      if (!current) throw new AppError('NOT_FOUND', 'User not found', 404);
      if (current.role === UserRole.SUPER_ADMIN) {
        throw new AppError('FORBIDDEN', 'Super Admin accounts cannot be modified', 403);
      }
      this.assertMutableTarget(current, 'Role change');
      if (current.isDisabled) {
        throw new AppError('CONFLICT', 'Disabled user accounts cannot be used for role change', 409);
      }
      if (current.role === newRole) {
        throw new AppError('CONFLICT', 'User already has this role', 409);
      }

      const updated = await tx.user.updateMany({
        where: {
          id: targetUserId,
          orgId: current.orgId,
          role: current.role,
          deletedAt: null,
          isActive: true,
          isDisabled: false,
          status: current.status,
        },
        data: { role: newRole },
      });
      if (updated.count !== 1) {
        throw new AppError('CONFLICT', 'User account changed state before the role change completed', 409);
      }

      await tx.session.updateMany({
        where: { userId: targetUserId, revokedAt: null },
        data: { revokedAt },
      });
      await tx.notification.create({
        data: {
          orgId: current.orgId,
          userId: targetUserId,
          title: 'Account Role Updated',
          body: `Your account role has been changed from ${current.role} to ${newRole}.`,
          type: 'ACCOUNT_UPDATE',
          deepLink: null,
        },
      });
      await tx.auditLog.create({
        data: {
          orgId: current.orgId,
          userId: actionBy,
          action: AuditAction.UPDATE,
          entityType: 'User',
          entityId: targetUserId,
          targetId: targetUserId,
          changes: {
            role: newRole,
            oldRole: current.role,
            sessionsRevoked: true,
          },
        },
      });

      return tx.user.findUnique({ where: { id: targetUserId } });
    });
  }

  private async updateUserStatus(
    targetUserId: string,
    isDisabled: boolean,
    actionBy: string,
    disabledStatus?: 'SUSPENDED' | 'BLOCKED',
  ) {
    const revokedAt = new Date();
    return prisma.$transaction(async (tx) => {
      const current = await tx.user.findUnique({ where: { id: targetUserId } });
      if (!current) throw new AppError('NOT_FOUND', 'User not found', 404);
      if (current.role === UserRole.SUPER_ADMIN) {
        throw new AppError('FORBIDDEN', 'Super Admin accounts cannot be modified', 403);
      }
      if (current.deletedAt || current.status === 'DELETED') {
        throw new AppError('CONFLICT', 'Deleted user accounts cannot be restored or modified', 409);
      }
      if (!current.isActive || current.status === 'INACTIVE' || current.status === 'REJECTED') {
        throw new AppError('CONFLICT', 'Inactive user accounts cannot be restored or modified', 409);
      }
      if (current.isDisabled === isDisabled) {
        throw new AppError('CONFLICT', isDisabled ? 'User account is already disabled' : 'User account is already active', 409);
      }
      if (isDisabled && current.status !== 'VERIFIED') {
        throw new AppError('CONFLICT', 'Only verified user accounts can be suspended or blocked', 409);
      }
      if (!isDisabled && current.status !== 'SUSPENDED' && current.status !== 'BLOCKED') {
        throw new AppError('CONFLICT', 'Only suspended or blocked user accounts can be restored', 409);
      }

      const nextStatus = isDisabled ? disabledStatus ?? current.status : 'VERIFIED';
      const updated = await tx.user.updateMany({
        where: {
          id: targetUserId,
          orgId: current.orgId,
          role: current.role,
          isDisabled: !isDisabled,
          deletedAt: null,
          isActive: true,
          status: current.status,
        },
        data: { isDisabled, status: nextStatus },
      });
      if (updated.count !== 1) {
        throw new AppError('CONFLICT', 'User account changed state before the status change completed', 409);
      }

      if (isDisabled) {
        await tx.session.updateMany({
          where: { userId: targetUserId, revokedAt: null },
          data: { revokedAt },
        });
      }
      const disabledLabel = nextStatus === 'BLOCKED' ? 'blocked' : 'suspended';
      await tx.notification.create({
        data: {
          orgId: current.orgId,
          userId: targetUserId,
          title: isDisabled
            ? `Account ${disabledLabel[0].toUpperCase()}${disabledLabel.slice(1)}`
            : 'Account Restored',
          body: isDisabled
            ? `Your account has been ${disabledLabel}.`
            : 'Your account has been restored.',
          type: 'ACCOUNT_UPDATE',
          deepLink: null,
        },
      });
      await tx.auditLog.create({
        data: {
          orgId: current.orgId,
          userId: actionBy,
          action: isDisabled ? AuditAction.SUSPEND : AuditAction.RESTORE,
          entityType: 'User',
          entityId: targetUserId,
          targetId: targetUserId,
          changes: {
            isDisabled,
            oldStatus: current.status,
            status: nextStatus,
            sessionsRevoked: isDisabled,
          },
        },
      });

      return tx.user.findUnique({ where: { id: targetUserId } });
    });
  }

  private assertMutableTarget(
    user: Pick<User, 'deletedAt' | 'isActive' | 'status'>,
    operation: string,
  ): void {
    if (user.deletedAt || user.status === 'DELETED') {
      throw new AppError('CONFLICT', `Deleted user accounts cannot be used for ${operation.toLowerCase()}`, 409);
    }
    if (!user.isActive || user.status === 'INACTIVE' || user.status === 'REJECTED') {
      throw new AppError('CONFLICT', `Inactive user accounts cannot be used for ${operation.toLowerCase()}`, 409);
    }
  }

  async getPendingDocuments() {
    return prisma.staffDocument.findMany({
      where: {
        deletedAt: null,
        status: { in: ['UPLOADED', 'PENDING', 'PENDING_REVIEW', 'UNDER_REVIEW'] },
      },
      select: {
        id: true,
        orgId: true,
        staffId: true,
        type: true,
        status: true,
        expiryDate: true,
        createdAt: true,
        updatedAt: true,
        reviewerId: true,
        reviewedAt: true,
        rejectionReason: true,
        version: true,
        parentDocumentId: true,
        resubmissionCount: true,
        originalFilename: true,
        mimeType: true,
        byteSize: true,
        reviewer: { select: { id: true, email: true, firstName: true, lastName: true } },
        staff: {
          select: { id: true, firstName: true, lastName: true, email: true, publicId: true },
        },
        org: { select: { id: true, name: true, publicId: true } },
      },
      orderBy: { createdAt: 'asc' },
    });
  }

  async claimDocument(documentId: string, adminId: string) {
    return prisma.$transaction(async (tx) => {
      const current = await tx.staffDocument.findFirst({
        where: { id: documentId, deletedAt: null },
        select: { id: true, orgId: true, staffId: true, status: true },
      });
      if (!current) {
        throw new AppError('DOCUMENT_NOT_FOUND', 'Document not found', 404);
      }
      if (!['UPLOADED', 'PENDING', 'PENDING_REVIEW'].includes(current.status)) {
        throw new AppError(
          'DOCUMENT_INVALID_STATE',
          'Document is already being reviewed or completed.',
          409,
        );
      }

      const transition = await tx.staffDocument.updateMany({
        where: {
          id: documentId,
          deletedAt: null,
          status: current.status,
        },
        data: {
          status: 'UNDER_REVIEW',
          reviewerId: adminId,
          reviewedAt: null,
          rejectionReason: null,
        },
      });
      if (transition.count !== 1) {
        throw new AppError(
          'DOCUMENT_INVALID_STATE',
          'Document review state changed before it could be claimed.',
          409,
        );
      }

      await tx.auditLog.create({
        data: {
          action: 'UPDATE',
          entityType: 'StaffDocument',
          entityId: documentId,
          orgId: current.orgId,
          userId: adminId,
          targetId: current.staffId,
          changes: {
            previousStatus: current.status,
            status: 'UNDER_REVIEW',
            reviewerId: adminId,
          },
        },
      });
      return tx.staffDocument.findUniqueOrThrow({ where: { id: documentId } });
    });
  }

  async createDocumentViewUrl(documentId: string) {
    return documentService.createAdminViewUrl(documentId);
  }

  async verifyDocument(documentId: string, adminId: string) {
    return this.reviewDocument(documentId, adminId, 'VERIFIED');
  }

  async rejectDocument(documentId: string, adminId: string, reason?: string) {
    const normalizedReason = reason?.trim();
    if (!normalizedReason) {
      throw new AppError('REASON_REQUIRED', 'Rejection reason is required', 400);
    }
    return this.reviewDocument(documentId, adminId, 'REJECTED', normalizedReason);
  }

  private async reviewDocument(
    documentId: string,
    adminId: string,
    nextStatus: 'VERIFIED' | 'REJECTED',
    reason?: string,
  ) {
    return prisma.$transaction(async (tx) => {
      const document = await tx.staffDocument.findFirst({
        where: { id: documentId, deletedAt: null },
        select: {
          id: true,
          orgId: true,
          staffId: true,
          type: true,
          status: true,
          reviewerId: true,
          staff: { select: { email: true } },
        },
      });
      if (!document) {
        throw new AppError('DOCUMENT_NOT_FOUND', 'Document not found', 404);
      }
      if (document.status !== 'UNDER_REVIEW' || document.reviewerId !== adminId) {
        throw new AppError(
          'DOCUMENT_INVALID_STATE',
          document.status === 'UNDER_REVIEW'
            ? 'Document is claimed by another reviewer.'
            : 'Document must be claimed before review can be completed.',
          409,
        );
      }

      const reviewedAt = new Date();
      const transition = await tx.staffDocument.updateMany({
        where: {
          id: documentId,
          deletedAt: null,
          status: 'UNDER_REVIEW',
          reviewerId: adminId,
        },
        data: {
          status: nextStatus,
          reviewerId: adminId,
          reviewedAt,
          rejectionReason: nextStatus === 'REJECTED' ? reason ?? null : null,
        },
      });
      if (transition.count !== 1) {
        throw new AppError(
          'DOCUMENT_INVALID_STATE',
          'Document review was already completed or changed by another reviewer.',
          409,
        );
      }

      const recipients = document.staff.email
        ? await tx.user.findMany({
          where: {
            orgId: document.orgId,
            email: { equals: document.staff.email, mode: 'insensitive' },
            deletedAt: null,
          },
          select: { id: true },
          take: 2,
        })
        : [];
      const recipientId = recipients.length === 1 ? recipients[0].id : null;

      if (recipientId) {
        await tx.notification.create({
          data: {
            orgId: document.orgId,
            userId: recipientId,
            title: nextStatus === 'VERIFIED' ? 'Document Verified' : 'Document Rejected',
            body: nextStatus === 'VERIFIED'
              ? `Your ${document.type} document was verified.`
              : `Your ${document.type} document was rejected: ${reason}`,
            type: 'DOCUMENT_REVIEW',
            deepLink: '/documents',
          },
        });
      }

      await tx.auditLog.create({
        data: {
          action: nextStatus === 'VERIFIED' ? 'APPROVE' : 'REJECT',
          entityType: 'StaffDocument',
          entityId: documentId,
          changes: {
            previousStatus: document.status,
            status: nextStatus,
            reason: reason ?? null,
            reviewerId: adminId,
            reviewedAt: reviewedAt.toISOString(),
            notificationDelivered: Boolean(recipientId),
          },
          userId: adminId,
          orgId: document.orgId,
          targetId: document.staffId,
        },
      });

      return tx.staffDocument.findUniqueOrThrow({ where: { id: documentId } });
    });
  }
}

export const adminService = new AdminService();
