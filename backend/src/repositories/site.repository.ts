import { prisma } from '../lib/prisma.js';
import { SiteStatus, Prisma } from '../../generated/prisma/index.js';

export class SiteRepository {
  async createSite(orgId: string, data: { name: string; address?: string; status: SiteStatus }) {
    return prisma.site.create({
      data: {
        ...data,
        orgId,
      },
    });
  }

  async getSites(orgId: string, filters?: { status?: SiteStatus }) {
    return prisma.site.findMany({
      where: {
        orgId,
        deletedAt: null,
        ...(filters?.status && { status: filters.status }),
      },
    });
  }

  async getSiteById(orgId: string, siteId: string) {
    return prisma.site.findFirst({
      where: {
        id: siteId,
        orgId,
        deletedAt: null,
      },
      include: {
        siteMembers: {
          include: {
            user: { select: { id: true, email: true, firstName: true, lastName: true } }
          }
        },
      }
    });
  }

  async updateSiteStatus(siteId: string, oldStatus: SiteStatus | null, newStatus: SiteStatus, changedById: string, reason?: string) {
    return prisma.$transaction(async (tx: any) => {
      const site = await tx.site.update({
        where: { id: siteId },
        data: { status: newStatus },
      });

      await tx.siteHistory.create({
        data: {
          siteId,
          oldStatus,
          newStatus,
          reason,
          changedById,
        },
      });

      return site;
    });
  }

  async addMember(siteId: string, orgId: string, userId: string, role: any) {
    return prisma.siteMember.create({
      data: {
        siteId,
        orgId,
        userId,
        role,
      }
    });
  }
}

export const siteRepository = new SiteRepository();
