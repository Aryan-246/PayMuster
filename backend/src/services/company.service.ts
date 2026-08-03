import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';
import { eventBus, Events } from '../lib/events.js';
import { AuditAction } from '../../generated/prisma/index.js';

export class CompanyService {
  async lookupByCode(code: string) {
    const org = await prisma.organization.findFirst({
      where: {
        OR: [
          { referenceCode: code },
          { joinCode: code }
        ]
      },
      select: { id: true, name: true }
    });
    return org;
  }

  async getOverview(orgId: string) {
    const org = await prisma.organization.findUnique({
      where: { id: orgId },
      include: {
        settings: true,
        _count: {
          select: { users: true, sites: true, staff: true }
        }
      }
    });
    if (!org) throw new AppError('ORG_NOT_FOUND', 'Company not found', 404);
    return org;
  }

  async updateSettings(orgId: string, settings: any, userId: string) {
    const updated = await prisma.companySettings.upsert({
      where: { orgId },
      update: settings,
      create: { orgId, ...settings },
    });

    eventBus.emitEvent('AuditLog', {
      orgId,
      userId,
      action: AuditAction.UPDATE,
      entityType: 'CompanySettings',
      entityId: updated.id,
      changes: settings,
    });

    return updated;
  }
}

export const companyService = new CompanyService();
