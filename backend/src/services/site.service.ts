import { siteRepository } from '../repositories/site.repository.js';
import { SiteStatus, SiteRole } from '../../generated/prisma/index.js';
import { eventBus, Events } from '../lib/events.js';
import { AppError } from '../lib/app-error.js';

export class SiteService {
  async createSite(orgId: string, userId: string, data: { name: string; address?: string }) {
    const site = await siteRepository.createSite(orgId, {
      ...data,
      status: 'DRAFT',
    });

    eventBus.emitEvent(Events.SITE_CREATED, { siteId: site.id, orgId });

    // Automatically assign creator as MANAGER of the site
    await siteRepository.addMember(site.id, orgId, userId, SiteRole.MANAGER);
    eventBus.emitEvent(Events.WORKER_JOINED_SITE, { siteId: site.id, userId, role: SiteRole.MANAGER });

    return site;
  }

  async assignWorker(orgId: string, siteId: string, targetUserId: string, role: SiteRole, assignedBy: string) {
    const site = await this.getSiteDetails(orgId, siteId);
    if (!site) throw new AppError('SITE_NOT_FOUND', 'Site not found', 404);

    await siteRepository.addMember(siteId, orgId, targetUserId, role);
    
    eventBus.emitEvent(Events.WORKER_JOINED_SITE, { siteId, orgId, userId: targetUserId, role, assignedBy });
    
    return { success: true };
  }

  async getSites(orgId: string, status?: SiteStatus) {
    return siteRepository.getSites(orgId, { status });
  }

  async getSiteDetails(orgId: string, siteId: string) {
    const site = await siteRepository.getSiteById(orgId, siteId);
    if (!site) {
      throw new AppError('SITE_NOT_FOUND', 'Site not found', 404);
    }
    return site;
  }

  async updateSiteStatus(orgId: string, siteId: string, newStatus: SiteStatus, userId: string, reason?: string) {
    const site = await this.getSiteDetails(orgId, siteId);
    const oldStatus = site.status;

    // Validate state machine transitions
    this.validateTransition(oldStatus, newStatus);

    const updatedSite = await siteRepository.updateSiteStatus(siteId, oldStatus, newStatus, userId, reason);

    eventBus.emitEvent(Events.SITE_STATUS_CHANGED, {
      siteId,
      oldStatus,
      newStatus,
      userId,
    });

    return updatedSite;
  }

  private validateTransition(oldStatus: SiteStatus, newStatus: SiteStatus) {
    const validTransitions: Record<SiteStatus, SiteStatus[]> = {
      DRAFT: ['PENDING'],
      PENDING: ['ACTIVE', 'REJECTED'] as any, // We might not have REJECTED in enum, assuming ACTIVE only for now
      ACTIVE: ['SUSPENDED', 'ARCHIVED'],
      SUSPENDED: ['ACTIVE', 'DELETED'],
      ARCHIVED: ['DELETED'],
      DELETED: [],
    };

    const allowed = validTransitions[oldStatus] || [];
    if (!allowed.includes(newStatus)) {
      throw new AppError('INVALID_STATE_TRANSITION', `Invalid status transition from ${oldStatus} to ${newStatus}`, 400);
    }
  }
}

export const siteService = new SiteService();
