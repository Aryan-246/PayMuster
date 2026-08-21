import { siteRepository } from '../repositories/site.repository.js';
import { SiteStatus, SiteRole } from '../../generated/prisma/index.js';
import { eventBus, Events } from '../lib/events.js';
import { AppError } from '../lib/app-error.js';

export class SiteService {
  async createSite(orgId: string, userId: string, data: { name: string; address?: string }) {
    const site = await siteRepository.createSiteWithManager(orgId, userId, {
      ...data,
      status: SiteStatus.DRAFT,
    });

    eventBus.emitEvent(Events.SITE_CREATED, { siteId: site.id, orgId });
    eventBus.emitEvent(Events.WORKER_JOINED_SITE, {
      siteId: site.id,
      orgId,
      userId,
      role: SiteRole.MANAGER,
      assignedBy: userId,
    });

    return this.getSiteDetails(orgId, site.id);
  }

  async assignWorker(orgId: string, siteId: string, targetUserId: string, role: SiteRole, assignedBy: string) {
    const membership = await siteRepository.addMember(siteId, orgId, targetUserId, role);

    eventBus.emitEvent(Events.WORKER_JOINED_SITE, {
      siteId,
      orgId,
      userId: targetUserId,
      role,
      assignedBy,
    });

    return membership;
  }

  async getSites(orgId: string, status?: SiteStatus) {
    const sites = await siteRepository.getSites(orgId, { status });
    return sites.map((site) => this.toSiteSummary(site));
  }

  async getSiteDetails(orgId: string, siteId: string) {
    const site = await siteRepository.getSiteById(orgId, siteId);
    if (!site) {
      throw new AppError('SITE_NOT_FOUND', 'Site not found', 404);
    }
    return this.toSiteSummary(site);
  }

  async updateSiteStatus(orgId: string, siteId: string, newStatus: SiteStatus, userId: string, reason?: string) {
    const site = await this.getSiteDetails(orgId, siteId);
    const oldStatus = site.status;

    this.validateTransition(oldStatus, newStatus);

    const updatedSite = await siteRepository.updateSiteStatus(
      orgId,
      siteId,
      oldStatus,
      newStatus,
      userId,
      reason,
    );
    if (!updatedSite) {
      throw new AppError('SITE_STATUS_CONFLICT', 'The site status changed before this request completed.', 409);
    }

    eventBus.emitEvent(Events.SITE_STATUS_CHANGED, {
      siteId,
      orgId,
      oldStatus,
      newStatus,
      userId,
    });

    return this.getSiteDetails(orgId, siteId);
  }

  private validateTransition(oldStatus: SiteStatus, newStatus: SiteStatus) {
    const validTransitions: Record<SiteStatus, SiteStatus[]> = {
      DRAFT: [SiteStatus.PENDING],
      PENDING: [SiteStatus.ACTIVE],
      ACTIVE: [SiteStatus.SUSPENDED, SiteStatus.ARCHIVED],
      SUSPENDED: [SiteStatus.ACTIVE, SiteStatus.DELETED],
      ARCHIVED: [SiteStatus.DELETED],
      DELETED: [],
    };

    if (!validTransitions[oldStatus].includes(newStatus)) {
      throw new AppError(
        'INVALID_STATE_TRANSITION',
        `Invalid status transition from ${oldStatus} to ${newStatus}`,
        400,
      );
    }
  }

  private toSiteSummary(site: Awaited<ReturnType<typeof siteRepository.getSites>>[number]) {
    const manager = site.siteMembers.find((member) => member.role === SiteRole.MANAGER)?.user ?? null;
    const supervisor = site.siteMembers.find((member) => member.role === SiteRole.SUPERVISOR)?.user ?? null;
    const approvedExpenseTotal = site.expenses.reduce(
      (total, expense) => total + Number(expense.amount),
      0,
    );

    return {
      id: site.id,
      publicId: site.publicId,
      name: site.name,
      address: site.address,
      status: site.status,
      startDate: site.startDate,
      expectedEndDate: site.expectedEndDate,
      createdAt: site.createdAt,
      updatedAt: site.updatedAt,
      workerCount: site.siteAssignments.length,
      manager,
      supervisor,
      workers: site.siteAssignments.map((assignment) => assignment.staff),
      approvedExpenseTotal,
    };
  }
}

export const siteService = new SiteService();
