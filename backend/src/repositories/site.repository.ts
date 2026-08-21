import { prisma } from '../lib/prisma.js';
import { ExpenseStatus, SiteRole, SiteStatus } from '../../generated/prisma/index.js';
import { AppError } from '../lib/app-error.js';

const siteSummaryInclude = {
  siteMembers: {
    where: { removedAt: null, deletedAt: null },
    select: {
      role: true,
      user: { select: { id: true, firstName: true, lastName: true } },
    },
  },
  siteAssignments: {
    where: {
      removedAt: null,
      deletedAt: null,
      staff: { deletedAt: null, status: 'ACTIVE' as const },
    },
    select: {
      staff: {
        select: {
          id: true,
          publicId: true,
          firstName: true,
          lastName: true,
          workerType: true,
          status: true,
        },
      },
    },
  },
  expenses: {
    where: {
      deletedAt: null,
      status: { in: [ExpenseStatus.APPROVED, ExpenseStatus.REIMBURSED] },
    },
    select: { amount: true },
  },
};

export class SiteRepository {
  async createSiteWithManager(
    orgId: string,
    userId: string,
    data: { name: string; address?: string; status: SiteStatus },
  ) {
    return prisma.$transaction(async (tx) => {
      const creator = await tx.user.findFirst({
        where: {
          id: userId,
          orgId,
          deletedAt: null,
          isActive: true,
          isDisabled: false,
        },
        select: { id: true },
      });
      if (!creator) {
        throw new AppError('SITE_CREATOR_NOT_ELIGIBLE', 'The site creator is not an active company user.', 403);
      }

      const site = await tx.site.create({ data: { ...data, orgId } });
      await tx.siteMember.create({
        data: { siteId: site.id, orgId, userId, role: SiteRole.MANAGER },
      });
      return site;
    });
  }

  async getSites(orgId: string, filters?: { status?: SiteStatus }) {
    return prisma.site.findMany({
      where: {
        orgId,
        deletedAt: null,
        ...(filters?.status && { status: filters.status }),
      },
      include: siteSummaryInclude,
      orderBy: [{ status: 'asc' }, { name: 'asc' }],
    });
  }

  async getSiteById(orgId: string, siteId: string) {
    return prisma.site.findFirst({
      where: { id: siteId, orgId, deletedAt: null },
      include: siteSummaryInclude,
    });
  }

  async updateSiteStatus(
    orgId: string,
    siteId: string,
    oldStatus: SiteStatus,
    newStatus: SiteStatus,
    changedById: string,
    reason?: string,
  ) {
    return prisma.$transaction(async (tx) => {
      const transition = await tx.site.updateMany({
        where: { id: siteId, orgId, deletedAt: null, status: oldStatus },
        data: { status: newStatus },
      });
      if (transition.count !== 1) return null;

      await tx.siteHistory.create({
        data: { siteId, oldStatus, newStatus, reason, changedById },
      });
      return tx.site.findUniqueOrThrow({ where: { id: siteId } });
    });
  }

  async addMember(siteId: string, orgId: string, userId: string, role: SiteRole) {
    return prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`${siteId}:${userId}`}, 0))`;

      const [site, user, activeMembership] = await Promise.all([
        tx.site.findFirst({
          where: { id: siteId, orgId, deletedAt: null, status: { not: SiteStatus.DELETED } },
          select: { id: true },
        }),
        tx.user.findFirst({
          where: { id: userId, orgId, deletedAt: null, isActive: true, isDisabled: false },
          select: { id: true },
        }),
        tx.siteMember.findFirst({
          where: { siteId, orgId, userId, removedAt: null, deletedAt: null },
          select: { id: true },
        }),
      ]);

      if (!site) throw new AppError('SITE_NOT_FOUND', 'Site not found.', 404);
      if (!user) throw new AppError('SITE_MEMBER_NOT_ELIGIBLE', 'The selected user is not an active company user.', 400);
      if (activeMembership) throw new AppError('SITE_MEMBER_EXISTS', 'The user is already an active site member.', 409);

      return tx.siteMember.create({ data: { siteId, orgId, userId, role } });
    });
  }
}

export const siteRepository = new SiteRepository();
