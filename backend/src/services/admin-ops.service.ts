import { prisma } from '../lib/prisma.js';

/** Injectable database surface (defaults to the real Prisma client). */
type AdminOpsDb = {
    paymentEvent: any;
    invoice: any;
    subscription: any;
    mailDispatch: any;
    announcementCampaign: any;
    notification: any;
    user: any;
    organization: any;
    review: any;
    auditLog: any;
    usageRecord: any;
    site: any;
    ownerRequest: any;
    staffDocument: any;
    attendanceRecord: any;
    plan: any;
};

function monthWindow(): { periodStart: Date; periodEnd: Date } {
    const now = new Date();
    const periodStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
    const periodEnd = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1));
    return { periodStart, periodEnd };
}

function dayKey(date: Date): string {
    return date.toISOString().slice(0, 10);
}

function lastNDays(n: number): string[] {
    const days: string[] = [];
    const today = new Date();
    for (let i = n - 1; i >= 0; i--) {
        const d = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate() - i));
        days.push(dayKey(d));
    }
    return days;
}

/**
 * Admin Operations Service — platform-level views over billing, mail,
 * announcements, and real report aggregations. Read-only; every list is
 * paginated and every number is derived from real rows — nothing is
 * fabricated or estimated.
 */
export class AdminOpsService {
    private readonly db: AdminOpsDb;

    constructor(db: AdminOpsDb = prisma as unknown as AdminOpsDb) {
        this.db = db;
    }

    async listPayments(filters: { status?: string; provider?: string; search?: string; page?: number; limit?: number }) {
        const page = filters.page ?? 1;
        const limit = Math.min(filters.limit ?? 25, 100);
        const where: Record<string, unknown> = {};

        if (filters.status && filters.status !== 'ALL') where.status = filters.status;
        if (filters.provider && filters.provider !== 'ALL') where.provider = filters.provider;
        if (filters.search && filters.search.trim().length > 0) {
            const q = filters.search.trim();
            where.OR = [
                { providerEventId: { contains: q, mode: 'insensitive' } },
                { eventType: { contains: q, mode: 'insensitive' } },
                { org: { name: { contains: q, mode: 'insensitive' } } },
                { org: { publicId: { contains: q, mode: 'insensitive' } } },
            ];
        }

        const [events, total, statusGrouped] = await Promise.all([
            this.db.paymentEvent.findMany({
                where,
                include: {
                    org: { select: { id: true, publicId: true, name: true } },
                    subscription: { select: { id: true, status: true, plan: { select: { code: true, name: true } } } },
                },
                orderBy: { createdAt: 'desc' },
                skip: (page - 1) * limit,
                take: limit,
            }),
            this.db.paymentEvent.count({ where }),
            this.db.paymentEvent.groupBy({ by: ['status'], _count: { _all: true } }),
        ]);

        const byStatus: Record<string, number> = {};
        for (const g of statusGrouped as Array<{ status: string; _count: { _all: number } }>) {
            byStatus[g.status] = g._count._all;
        }

        return {
            payments: events,
            total,
            page,
            totalPages: Math.max(1, Math.ceil(total / limit)),
            summary: { total, byStatus },
        };
    }

    async getPaymentDetail(id: string) {
        const event = await this.db.paymentEvent.findUnique({
            where: { id },
            include: {
                org: { select: { id: true, publicId: true, name: true } },
                subscription: {
                    select: {
                        id: true,
                        status: true,
                        unlimitedAccess: true,
                        currentPeriodEnd: true,
                        plan: { select: { code: true, name: true, amountMinor: true, currency: true } },
                    },
                },
            },
        });
        if (!event) return null;
        const invoices = await this.db.invoice.findMany({
            where: { orgId: event.orgId ?? undefined, subscriptionId: event.subscriptionId ?? undefined },
            orderBy: { createdAt: 'desc' },
            take: 10,
        });
        return { event, invoices };
    }

    async getMailOverview() {
        const { periodStart, periodEnd } = monthWindow();

        const [dispatches, totalDispatches, totalSent, totalFailed, orgCount, userCount, monthUsage] = await Promise.all([
            this.db.mailDispatch.findMany({
                orderBy: { createdAt: 'desc' },
                take: 50,
                include: {
                    org: { select: { id: true, publicId: true, name: true } },
                },
            }),
            this.db.mailDispatch.count(),
            this.db.mailDispatch.aggregate({ _sum: { sent: true } }),
            this.db.mailDispatch.aggregate({ _sum: { failed: true } }),
            this.db.organization.count({ where: { deletedAt: null } }),
            this.db.user.count({ where: { deletedAt: null, isDisabled: false } }),
            this.db.usageRecord.findMany({
                where: { metric: 'mail_supply', periodStart, periodEnd },
                select: { orgId: true, quantity: true },
            }),
        ]);

        const orgsUsingMail = monthUsage.length;
        const mailSentThisMonth = monthUsage.reduce((sum: number, r: { quantity: unknown }) => sum + Number(r.quantity ?? 0), 0);

        return {
            quota: {
                periodStart,
                periodEnd,
                freePlanMonthlyLimit: 10,
            },
            summary: {
                totalDispatches,
                totalSent: Number(totalSent._sum.sent ?? 0),
                totalFailed: Number(totalFailed._sum.failed ?? 0),
                mailSentThisMonth,
                orgsUsingMail,
                orgCount,
                userCount,
            },
            dispatches,
        };
    }

    async listAnnouncements(filters: { search?: string; page?: number; limit?: number }) {
        const page = filters.page ?? 1;
        const limit = Math.min(filters.limit ?? 25, 100);
        const where: Record<string, unknown> = {};
        if (filters.search && filters.search.trim().length > 0) {
            const q = filters.search.trim();
            where.OR = [
                { title: { contains: q, mode: 'insensitive' } },
                { body: { contains: q, mode: 'insensitive' } },
                { organization: { name: { contains: q, mode: 'insensitive' } } },
            ];
        }

        const [campaigns, total] = await Promise.all([
            this.db.announcementCampaign.findMany({
                where,
                include: {
                    organization: { select: { id: true, publicId: true, name: true } },
                    actor: { select: { id: true, publicId: true, firstName: true, lastName: true, email: true } },
                    _count: { select: { notifications: true } },
                },
                orderBy: { createdAt: 'desc' },
                skip: (page - 1) * limit,
                take: limit,
            }),
            this.db.announcementCampaign.count({ where }),
        ]);

        // Acknowledgement rate per campaign: notifications of type ANNOUNCEMENT
        // that the recipient has actually READ (readAt set).
        const campaignIds = campaigns.map((c: any) => c.id);
        const ackGroups = campaignIds.length > 0
            ? await this.db.notification.groupBy({
                by: ['campaignId'],
                where: { campaignId: { in: campaignIds }, type: 'ANNOUNCEMENT', readAt: { not: null } },
                _count: { _all: true },
            })
            : [];
        const ackByCampaign = new Map<string, number>(
            (ackGroups as Array<{ campaignId: string | null; _count: { _all: number } }>)
                .filter((g) => g.campaignId)
                .map((g) => [g.campaignId as string, g._count._all]),
        );

        // The Prisma relation is `organization`; expose it as `org` for the
        // API consumers (consistent with the other admin list payloads).
        const announcements = campaigns.map((c: any) => ({
            ...c,
            org: c.organization ?? null,
            acknowledgementCount: ackByCampaign.get(c.id) ?? 0,
        }));

        return {
            announcements,
            total,
            page,
            totalPages: Math.max(1, Math.ceil(total / limit)),
        };
    }

    /**
     * Real 30-day report: daily counts derived from actual rows. Server-side
     * aggregation; no client-side fabrication.
     */
    async getReportsOverview() {
        const since = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

        const [
            users,
            orgs,
            subscriptions,
            paymentEvents,
            mailDispatches,
            auditEvents,
            reviews,
            attendance,
        ] = await Promise.all([
            this.db.user.findMany({ where: { createdAt: { gte: since } }, select: { createdAt: true } }),
            this.db.organization.findMany({ where: { createdAt: { gte: since } }, select: { createdAt: true } }),
            this.db.subscription.findMany({ where: { createdAt: { gte: since } }, select: { createdAt: true, status: true } }),
            this.db.paymentEvent.findMany({ where: { createdAt: { gte: since } }, select: { createdAt: true, status: true } }),
            this.db.mailDispatch.findMany({ where: { createdAt: { gte: since } }, select: { createdAt: true, sent: true, failed: true } }),
            this.db.auditLog.findMany({ where: { createdAt: { gte: since } }, select: { createdAt: true } }),
            this.db.review.findMany({ where: { createdAt: { gte: since } }, select: { createdAt: true, status: true } }),
            this.db.attendanceRecord.findMany({ where: { createdAt: { gte: since } }, select: { createdAt: true } }),
        ]);

        const days = lastNDays(30);
        const emptySeries = () => Object.fromEntries(days.map((d) => [d, 0]));
        const series = {
            users: emptySeries(),
            companies: emptySeries(),
            subscriptions: emptySeries(),
            payments: emptySeries(),
            mail: emptySeries(),
            auditEvents: emptySeries(),
            reviews: emptySeries(),
            attendance: emptySeries(),
        };

        const bump = (map: Record<string, number>, date: Date) => {
            const key = dayKey(date);
            if (key in map) map[key] += 1;
        };
        users.forEach((u: { createdAt: Date }) => bump(series.users, u.createdAt));
        orgs.forEach((o: { createdAt: Date }) => bump(series.companies, o.createdAt));
        subscriptions.forEach((s: { createdAt: Date }) => bump(series.subscriptions, s.createdAt));
        paymentEvents.forEach((p: { createdAt: Date }) => bump(series.payments, p.createdAt));
        mailDispatches.forEach((m: { createdAt: Date }) => bump(series.mail, m.createdAt));
        auditEvents.forEach((a: { createdAt: Date }) => bump(series.auditEvents, a.createdAt));
        reviews.forEach((r: { createdAt: Date }) => bump(series.reviews, r.createdAt));
        attendance.forEach((a: { createdAt: Date }) => bump(series.attendance, a.createdAt));

        const totals = {
            users: users.length,
            companies: orgs.length,
            subscriptions: subscriptions.length,
            payments: paymentEvents.length,
            mailDispatches: mailDispatches.length,
            mailSent: mailDispatches.reduce((s: number, m: { sent: number }) => s + m.sent, 0),
            auditEvents: auditEvents.length,
            reviews: reviews.length,
            attendance: attendance.length,
        };

        return {
            window: { days: 30, since: since.toISOString() },
            totals,
            series,
        };
    }
}

export const adminOpsService = new AdminOpsService();
