import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';
import { eventBus, Events } from '../lib/events.js';
import { AuditAction } from '../../generated/prisma/index.js';

const REPORTABLE_EXPENSE_STATUSES = ['APPROVED', 'REIMBURSED'] as const;

function decimalString(value: { toString(): string } | null | undefined): string {
  return value?.toString() ?? '0';
}

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
    const [org, siteLinkedExpenses, companyLevelExpenses, payRuns] = await Promise.all([
      prisma.organization.findUnique({
        where: { id: orgId },
        include: {
          settings: true,
          _count: {
            select: { users: true, sites: true, staff: true }
          }
        }
      }),
      prisma.expense.aggregate({
        where: {
          orgId,
          deletedAt: null,
          siteId: { not: null },
          status: { in: [...REPORTABLE_EXPENSE_STATUSES] },
        },
        _sum: { amount: true },
      }),
      prisma.expense.aggregate({
        where: {
          orgId,
          deletedAt: null,
          siteId: null,
          status: { in: [...REPORTABLE_EXPENSE_STATUSES] },
        },
        _sum: { amount: true },
      }),
      prisma.payRun.aggregate({
        where: { orgId, deletedAt: null },
        _count: { _all: true },
        _sum: { totalAmount: true },
      }),
    ]);
    if (!org) throw new AppError('ORG_NOT_FOUND', 'Company not found', 404);

    return {
      ...org,
      financialSummary: {
        expenses: {
          includedStatuses: [...REPORTABLE_EXPENSE_STATUSES],
          siteLinkedTotal: decimalString(siteLinkedExpenses._sum.amount),
          companyLevelTotal: decimalString(companyLevelExpenses._sum.amount),
        },
        payRuns: {
          recordedCount: payRuns._count._all,
          recordedTotal: decimalString(payRuns._sum.totalAmount),
        },
      },
    };
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
