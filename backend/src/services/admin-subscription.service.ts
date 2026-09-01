import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';

/** Injectable database surface (defaults to the real Prisma client). */
type AdminSubDb = {
    $transaction: any;
    plan: any;
    subscription: any;
    entitlement: any;
    usageRecord: any;
    invoice: any;
    paymentEvent: any;
    organization: any;
    user: any;
    ownerRequest: any;
    auditLog: any;
    notification: any;
};

const ACTIVE_SUBSCRIPTION_STATUSES = ['TRIALING', 'ACTIVE', 'PAST_DUE'] as const;
const MAIL_METRIC = 'mail_supply';

function monthWindow(): { periodStart: Date; periodEnd: Date } {
    const now = new Date();
    const periodStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
    const periodEnd = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1));
    return { periodStart, periodEnd };
}

/**
 * Admin Subscription Service — the SUPER_ADMIN platform view of every
 * organization's subscription lifecycle: subscriber list, detail snapshot
 * (plan, entitlements/offers, usage, invoices, payment events), and
 * offer/free-access grants stored as OFFER-sourced Entitlement rows.
 *
 * All mutations audit + notify the org's owners (action → reaction); billing
 * history is never rewritten — grants/revoke only flip entitlement state.
 */
export class AdminSubscriptionService {
    private readonly db: AdminSubDb;

    constructor(db: AdminSubDb = prisma as unknown as AdminSubDb) {
        this.db = db;
    }

    /**
     * The subscriber list is ORGANIZATION-centric, not subscription-centric:
     * every active organization appears, including those without any
     * subscription record (shown as NO_SUBSCRIPTION). Previously the query
     * read only the subscription table, so a platform whose orgs had never
     * started a trial/plan displayed "0 subscribers" despite containing
     * companies, owners and users.
     */
    async listSubscribers(filters: {
        status?: string;
        planCode?: string;
        trial?: string;
        unlimited?: string;
        search?: string;
        page?: number;
        limit?: number;
    }) {
        const page = filters.page ?? 1;
        const limit = Math.min(filters.limit ?? 25, 100);

        const orgWhere: Record<string, unknown> = { deletedAt: null };
        if (filters.search && filters.search.trim().length > 0) {
            const q = filters.search.trim();
            orgWhere.OR = [
                { name: { contains: q, mode: 'insensitive' } },
                { publicId: { contains: q, mode: 'insensitive' } },
            ];
        }

        const [orgs, orgTotal, activeCount, trialCount, unlimitedCount, paidCount, orgsWithoutSubscription] = await Promise.all([
            // Latest subscription row per org (createdAt desc, take 1). An org
            // can hold at most one active subscription (createTrial guards it),
            // so the newest row is always the current state.
            this.db.organization.findMany({
                where: orgWhere,
                include: {
                    subscriptions: {
                        orderBy: { createdAt: 'desc' },
                        take: 1,
                        include: { plan: { select: { id: true, code: true, name: true, amountMinor: true, currency: true, interval: true } } },
                    },
                },
                orderBy: { createdAt: 'desc' },
            }),
            this.db.organization.count({ where: orgWhere }),
            this.db.subscription.count({ where: { status: { in: [...ACTIVE_SUBSCRIPTION_STATUSES] } } }),
            this.db.subscription.count({ where: { status: 'TRIALING', trialEndsAt: { gt: new Date() } } }),
            this.db.subscription.count({ where: { unlimitedAccess: true } }),
            this.db.subscription.count({ where: { status: 'ACTIVE' } }),
            this.db.organization.count({
                where: {
                    deletedAt: null,
                    subscriptions: { none: { status: { in: [...ACTIVE_SUBSCRIPTION_STATUSES] } } },
                },
            }),
        ]);

        const now = new Date();
        const matchesFilters = (subscription: any | null): boolean => {
            const status = filters.status && filters.status !== 'ALL' ? filters.status : undefined;
            if (status === 'NONE') {
                if (subscription && ACTIVE_SUBSCRIPTION_STATUSES.includes(subscription.status)) return false;
            } else if (status) {
                if (!subscription || subscription.status !== status) return false;
            }
            if (filters.trial === 'ACTIVE') {
                if (!subscription?.trialEndsAt || subscription.trialEndsAt <= now) return false;
            } else if (filters.trial === 'EXPIRED') {
                if (!subscription?.trialEndsAt || subscription.trialEndsAt > now) return false;
            } else if (filters.trial === 'NONE') {
                if (subscription?.trialEndsAt) return false;
            }
            if (filters.unlimited === 'GRANTED') {
                if (!subscription?.unlimitedAccess) return false;
            } else if (filters.unlimited === 'STANDARD') {
                if (subscription?.unlimitedAccess) return false;
            }
            if (filters.planCode && filters.planCode !== 'ALL') {
                if (subscription?.plan?.code !== filters.planCode) return false;
            }
            return true;
        };

        // (org, currentSubscription) pairs passing every filter.
        const entries = (orgs as any[])
            .map((org) => ({ org, subscription: org.subscriptions?.[0] ?? null }))
            .filter(({ subscription }) => matchesFilters(subscription));

        const total = entries.length;
        const paged = entries.slice((page - 1) * limit, (page - 1) * limit + limit);

        // Owner enrichment: the org's OWNER user + the PM-OWN id from the
        // approved OwnerRequest (owner identity = User role OWNER + Organization).
        const orgIds = paged.map((e) => e.org.id);
        const [ownerUsers, ownerRequests] = await Promise.all([
            orgIds.length > 0
                ? this.db.user.findMany({
                    where: { orgId: { in: orgIds }, role: 'OWNER', deletedAt: null },
                    select: { id: true, orgId: true, publicId: true, firstName: true, lastName: true, email: true },
                })
                : [],
            orgIds.length > 0
                ? this.db.ownerRequest.findMany({
                    where: { status: 'APPROVED', user: { orgId: { in: orgIds } } },
                    select: { publicId: true, user: { select: { orgId: true } } },
                })
                : [],
        ]);
        const ownerByOrg = new Map<string, any>(ownerUsers.map((u: any) => [u.orgId, u]));
        const ownerRequestByOrg = new Map<string, { publicId: string }>(
            ownerRequests.map((r: any) => [r.user.orgId, { publicId: r.publicId }]),
        );

        const rows = paged.map(({ org, subscription }) => ({
            id: subscription?.id ?? null,
            orgId: org.id,
            org: { id: org.id, publicId: org.publicId, name: org.name },
            owner: ownerByOrg.get(org.id) ?? null,
            ownerRequestId: ownerRequestByOrg.get(org.id)?.publicId ?? null,
            plan: subscription?.plan
                ? { ...subscription.plan, amountMinor: subscription.plan.amountMinor != null ? String(subscription.plan.amountMinor) : null }
                : null,
            status: subscription?.status ?? 'NO_SUBSCRIPTION',
            provider: subscription?.provider ?? null,
            providerSubscriptionId: subscription?.providerSubscriptionId ?? null,
            trialEndsAt: subscription?.trialEndsAt ?? null,
            cancelAtPeriodEnd: subscription?.cancelAtPeriodEnd ?? false,
            unlimitedAccess: subscription?.unlimitedAccess ?? false,
            currentPeriodStart: subscription?.currentPeriodStart ?? null,
            currentPeriodEnd: subscription?.currentPeriodEnd ?? null,
            createdAt: subscription?.createdAt ?? org.createdAt,
            updatedAt: subscription?.updatedAt ?? null,
        }));

        return {
            subscribers: rows,
            total,
            page,
            totalPages: Math.max(1, Math.ceil(total / limit)),
            summary: {
                total: orgTotal,
                activeCount,
                trialCount,
                unlimitedCount,
                paidCount,
                noSubscriptionCount: orgsWithoutSubscription,
            },
        };
    }

    /**
     * Detail snapshot for one organization. A missing subscription is a real,
     * displayable state (200 + subscription: null) — not a 404 — so the admin
     * can see the org, its owners, and act (e.g. grant unlimited access, which
     * provisions a subscription). 404 is reserved for an unknown organization.
     */
    async getSubscriberDetail(orgId: string) {
        const [org, owners, ownerRequest] = await Promise.all([
            this.db.organization.findUnique({
                where: { id: orgId },
                select: { id: true, publicId: true, name: true, joinCode: true, status: true, createdAt: true, deletedAt: true },
            }),
            this.db.user.findMany({
                where: { orgId, role: 'OWNER', deletedAt: null },
                select: { id: true, publicId: true, firstName: true, lastName: true, email: true, createdAt: true },
            }),
            this.db.ownerRequest.findFirst({
                where: { status: 'APPROVED', user: { orgId } },
                select: { publicId: true, createdAt: true },
            }),
        ]);
        if (!org || org.deletedAt) {
            throw new AppError('ORG_NOT_FOUND', 'Organization not found.', 404);
        }

        const subscription = await this.db.subscription.findFirst({
            where: { orgId },
            orderBy: { createdAt: 'desc' },
            include: {
                plan: true,
                entitlements: { orderBy: { createdAt: 'desc' } },
                invoices: { orderBy: { createdAt: 'desc' }, take: 20 },
                paymentEvents: { orderBy: { createdAt: 'desc' }, take: 20 },
                usageRecords: { orderBy: { periodStart: 'desc' }, take: 12 },
            },
        });
        const history = await this.db.subscription.findMany({
            where: { orgId },
            orderBy: { createdAt: 'desc' },
            take: 10,
            select: { id: true, status: true, planId: true, createdAt: true, updatedAt: true, unlimitedAccess: true, trialEndsAt: true },
        });

        // Mail usage for the current month (the quota the org is living on).
        const { periodStart, periodEnd } = monthWindow();
        const mailUsage = await this.db.usageRecord.findUnique({
            where: {
                orgId_metric_periodStart_periodEnd: {
                    orgId,
                    metric: MAIL_METRIC,
                    periodStart,
                    periodEnd,
                },
            },
            select: { quantity: true },
        });

        return {
            subscription,
            noSubscription: !subscription,
            // Unlimited access can be granted even without an existing
            // subscription — the grant provisions one (see subscription.service).
            provisionable: true,
            org,
            owners,
            ownerRequest,
            history,
            mailUsage: {
                sentThisMonth: Number(mailUsage?.quantity ?? 0),
                periodStart,
                periodEnd,
            },
        };
    }

    /**
     * Grant an offer / free-access entitlement to an org. Stored as an
     * Entitlement row with source='OFFER' and optional expiry — the same rows
     * the entitlement resolver reads, so the grant takes effect immediately
     * everywhere it is consumed, and expiry returns the org to plan state
     * without any code change. Billing history is never rewritten.
     */
    async grantOffer(input: {
        orgId: string;
        adminId: string;
        key: string;
        value: 'unlimited' | number | boolean;
        expiresAt?: Date | null;
        note?: string;
        requestId?: string;
    }) {
        if (!input.orgId?.trim()) throw new AppError('ORG_REQUIRED', 'Organization is required.', 400);
        if (!input.key?.trim()) throw new AppError('VALIDATION_ERROR', 'An entitlement key is required.', 400);

        const key = input.key.trim();
        let value: unknown;
        if (input.value === 'unlimited') value = true;
        else value = input.value;

        const result = await this.db.$transaction(async (tx: any) => {
            const org = await tx.organization.findUnique({
                where: { id: input.orgId },
                select: { id: true, name: true },
            });
            if (!org) throw new AppError('ORG_NOT_FOUND', 'Organization not found.', 404);

            // OFFER rows are keyed apart from PLAN rows so a plan re-sync never
            // collides: `offer:<name>` namespace via the caller-provided key.
            const existing = await tx.entitlement.findUnique({
                where: { orgId_key: { orgId: input.orgId, key } },
            });
            if (existing && existing.source === 'OFFER') {
                throw new AppError('OFFER_EXISTS', 'An active offer with this key already exists for this organization.', 409);
            }
            if (existing && existing.source === 'PLAN') {
                throw new AppError(
                    'OFFER_KEY_CONFLICT',
                    'This key is reserved by the current plan entitlement; choose a different offer key.',
                    409,
                );
            }

            const entitlement = await tx.entitlement.create({
                data: {
                    orgId: input.orgId,
                    key,
                    value,
                    source: 'OFFER',
                    expiresAt: input.expiresAt ?? null,
                },
            });

            const owners = await tx.user.findMany({
                where: { orgId: input.orgId, role: 'OWNER', deletedAt: null },
                select: { id: true },
            });
            if (owners.length > 0) {
                await tx.notification.createMany({
                    data: owners.map((owner: { id: string }) => ({
                        orgId: input.orgId,
                        userId: owner.id,
                        title: 'Free access granted',
                        body: `PayMuster has granted your company a special offer${input.expiresAt ? ` until ${input.expiresAt.toISOString().slice(0, 10)}` : ''}.`,
                        type: 'SUBSCRIPTION_UPDATE',
                        deepLink: null,
                    })),
                });
            }

            await tx.auditLog.create({
                data: {
                    action: 'CREATE',
                    entityType: 'Entitlement',
                    entityId: entitlement.id,
                    orgId: input.orgId,
                    userId: input.adminId,
                    changes: {
                        key,
                        value,
                        source: 'OFFER',
                        expiresAt: input.expiresAt?.toISOString() ?? null,
                        note: input.note ?? null,
                    },
                    requestId: input.requestId,
                },
            });

            return entitlement;
        });

        return result;
    }

    /** Revoke an OFFER entitlement (expires it immediately) + notify + audit. */
    async revokeOffer(input: { orgId: string; key: string; adminId: string; requestId?: string }) {
        const key = input.key?.trim();
        if (!input.orgId?.trim()) throw new AppError('ORG_REQUIRED', 'Organization is required.', 400);
        if (!key) throw new AppError('VALIDATION_ERROR', 'An entitlement key is required.', 400);

        return this.db.$transaction(async (tx: any) => {
            const existing = await tx.entitlement.findUnique({
                where: { orgId_key: { orgId: input.orgId, key } },
            });
            if (!existing || existing.source !== 'OFFER') {
                throw new AppError('OFFER_NOT_FOUND', 'No active offer with this key for this organization.', 404);
            }

            await tx.entitlement.delete({ where: { id: existing.id } });

            const owners = await tx.user.findMany({
                where: { orgId: input.orgId, role: 'OWNER', deletedAt: null },
                select: { id: true },
            });
            if (owners.length > 0) {
                await tx.notification.createMany({
                    data: owners.map((owner: { id: string }) => ({
                        orgId: input.orgId,
                        userId: owner.id,
                        title: 'Offer ended',
                        body: 'A special access offer for your company has ended. Normal plan limits now apply.',
                        type: 'SUBSCRIPTION_UPDATE',
                        deepLink: null,
                    })),
                });
            }

            await tx.auditLog.create({
                data: {
                    action: 'DELETE',
                    entityType: 'Entitlement',
                    entityId: existing.id,
                    orgId: input.orgId,
                    userId: input.adminId,
                    changes: { key, revoked: true },
                    requestId: input.requestId,
                },
            });

            return { orgId: input.orgId, key, revoked: true };
        });
    }

    async listPlans() {
        const plans = await this.db.plan.findMany({
            where: { isActive: true },
            orderBy: { amountMinor: 'asc' },
            select: { id: true, code: true, name: true, amountMinor: true, currency: true, interval: true, trialDays: true, featureLimits: true },
        });
        // amountMinor is a BigInt — JSON.stringify cannot serialize BigInts.
        return (plans as Array<Record<string, unknown>>).map((p) => ({
            ...p,
            amountMinor: p.amountMinor != null ? String(p.amountMinor) : null,
        }));
    }
}

export const adminSubscriptionService = new AdminSubscriptionService();
