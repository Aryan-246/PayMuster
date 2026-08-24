import { AppError } from '../lib/app-error.js';
import { prisma } from '../lib/prisma.js';

const ACTIVE_SUBSCRIPTION_STATUSES = ['TRIALING', 'ACTIVE', 'PAST_DUE'] as const;

type JsonObject = Record<string, unknown>;

type BillingDb = {
    $transaction<T>(callback: (tx: BillingDb) => Promise<T>, options?: unknown): Promise<T>;
    plan: any;
    subscription: any;
    entitlement: any;
    usageRecord: any;
    invoice: any;
    paymentEvent: any;
    auditLog?: any;
    notification?: any;
};

export interface CreateTrialInput {
    orgId: string;
    planCode: string;
    changedById?: string;
}

export interface UsageInput {
    orgId: string;
    metric: string;
    quantity: number;
    periodStart: Date;
    periodEnd: Date;
    actorRole?: string;
}

export interface CreateInvoiceInput {
    orgId: string;
    subscriptionId?: string;
    invoiceNumber: string;
    subtotalMinor: bigint;
    taxMinor?: bigint;
    currency?: string;
    providerInvoiceId?: string;
    providerOrderId?: string;
    dueAt?: Date;
}

export interface PaymentEventInput {
    provider: string;
    providerEventId: string;
    eventType: string;
    payload: JsonObject;
    orgId?: string;
    subscriptionId?: string;
    providerOrderId?: string;
}

export interface FeatureAccess {
    allowed: boolean;
    unlimited: boolean;
    limit: number | null;
    source: 'SUPER_ADMIN' | 'SUBSCRIPTION' | 'NONE';
}

function assertNonBlank(value: string, code: string, message: string): void {
    if (!value.trim()) throw new AppError(code, message, 400);
}

function assertPeriod(periodStart: Date, periodEnd: Date): void {
    if (!(periodStart instanceof Date) || Number.isNaN(periodStart.getTime()) ||
        !(periodEnd instanceof Date) || Number.isNaN(periodEnd.getTime()) || periodEnd <= periodStart) {
        throw new AppError('BILLING_PERIOD_INVALID', 'Usage period must contain valid ordered dates.', 400);
    }
}

function addBillingPeriod(start: Date, interval: 'MONTH' | 'YEAR'): Date {
    const end = new Date(start);
    if (interval === 'YEAR') end.setUTCFullYear(end.getUTCFullYear() + 1);
    else end.setUTCMonth(end.getUTCMonth() + 1);
    return end;
}

function isUniqueViolation(error: unknown): boolean {
    return Boolean(error && typeof error === 'object' && 'code' in error && (error as { code?: string }).code === 'P2002');
}

function numericLimit(value: unknown): number | null {
    return typeof value === 'number' && Number.isFinite(value) && value >= 0 ? value : null;
}

export class SubscriptionService {
    private static globalSubscriptionEnabled = true;
    private readonly db: BillingDb;

    constructor(db: BillingDb = prisma as unknown as BillingDb) {
        this.db = db;
    }

    /**
     * Server-authoritative global subscription switch.
     * OFF: all users get unrestricted subscription feature access while normal RBAC remains active.
     * ON: normal subscription checking resumes.
     * Toggling OFF does NOT delete or cancel existing subscriptions.
     */
    static getGlobalSubscriptionSwitch(): boolean {
        return SubscriptionService.globalSubscriptionEnabled;
    }

    static setGlobalSubscriptionSwitch(enabled: boolean, actorRole?: string): boolean {
        if (actorRole && actorRole !== 'ADMIN' && actorRole !== 'SUPER_ADMIN') {
            throw new AppError('UNAUTHORIZED', 'Only Admin or Super Admin can toggle the global subscription switch.', 403);
        }
        SubscriptionService.globalSubscriptionEnabled = enabled;
        return SubscriptionService.globalSubscriptionEnabled;
    }

    async listPlans() {
        return this.db.plan.findMany({
            where: { isActive: true },
            orderBy: { amountMinor: 'asc' },
        });
    }

    async createTrial(input: CreateTrialInput) {
        assertNonBlank(input.orgId, 'ORG_REQUIRED', 'Organization is required.');
        assertNonBlank(input.planCode, 'PLAN_REQUIRED', 'Plan code is required.');

        return this.db.$transaction(async (tx) => {
            const plan = await tx.plan.findFirst({ where: { code: input.planCode, isActive: true } });
            if (!plan) throw new AppError('PLAN_NOT_FOUND', 'The requested plan is unavailable.', 404);

            const existing = await tx.subscription.findFirst({
                where: { orgId: input.orgId, status: { in: [...ACTIVE_SUBSCRIPTION_STATUSES] } },
                orderBy: { createdAt: 'desc' },
            });
            if (existing) throw new AppError('SUBSCRIPTION_EXISTS', 'The organization already has an active subscription.', 409);

            const periodStart = new Date();
            const trialDays = plan.trialDays ?? 7;
            const trialEndsAt = trialDays > 0
                ? new Date(periodStart.getTime() + trialDays * 24 * 60 * 60 * 1000)
                : null;
            const periodEnd = trialEndsAt ?? addBillingPeriod(periodStart, plan.interval);
            const subscription = await tx.subscription.create({
                data: {
                    orgId: input.orgId,
                    planId: plan.id,
                    status: trialEndsAt ? 'TRIALING' : 'ACTIVE',
                    provider: 'razorpay',
                    currentPeriodStart: periodStart,
                    currentPeriodEnd: periodEnd,
                    trialEndsAt,
                    changedById: input.changedById,
                },
            });

            const limits = (plan.featureLimits as JsonObject) || {};
            const entries = Object.entries(limits);
            if (entries.length > 0) {
                await tx.entitlement.createMany({
                    data: entries.map(([key, value]) => ({
                        orgId: input.orgId,
                        subscriptionId: subscription.id,
                        key,
                        value,
                        source: 'PLAN',
                        expiresAt: periodEnd,
                    })),
                });
            }
            return subscription;
        });
    }

    async getFeatureAccess(orgId: string, key: string, actorRole?: string): Promise<FeatureAccess> {
        assertNonBlank(orgId, 'ORG_REQUIRED', 'Organization is required.');
        assertNonBlank(key, 'ENTITLEMENT_REQUIRED', 'Entitlement key is required.');
        if (actorRole === 'SUPER_ADMIN') {
            return { allowed: true, unlimited: true, limit: null, source: 'SUPER_ADMIN' };
        }

        // Global switch check: when subscription enforcement is OFF, unrestricted access
        if (!SubscriptionService.globalSubscriptionEnabled) {
            return { allowed: true, unlimited: true, limit: null, source: 'SUBSCRIPTION' };
        }

        const subscription = await this.db.subscription.findFirst({
            where: {
                orgId,
                status: { in: [...ACTIVE_SUBSCRIPTION_STATUSES] },
                currentPeriodEnd: { gt: new Date() },
            },
            include: { entitlements: { where: { key } } },
            orderBy: { createdAt: 'desc' },
        });
        if (!subscription) return { allowed: false, unlimited: false, limit: null, source: 'NONE' };
        if (subscription.unlimitedAccess) return { allowed: true, unlimited: true, limit: null, source: 'SUBSCRIPTION' };

        const value = subscription.entitlements[0]?.value;
        const limit = numericLimit(value);
        if (value === true || (limit === null && value !== false)) {
            return { allowed: value !== false, unlimited: false, limit, source: 'SUBSCRIPTION' };
        }
        return { allowed: value === true || limit === null || limit > 0, unlimited: false, limit, source: 'SUBSCRIPTION' };
    }

    async recordUsage(input: UsageInput) {
        assertNonBlank(input.orgId, 'ORG_REQUIRED', 'Organization is required.');
        assertNonBlank(input.metric, 'USAGE_METRIC_REQUIRED', 'Usage metric is required.');
        if (!Number.isFinite(input.quantity) || input.quantity <= 0) {
            throw new AppError('USAGE_QUANTITY_INVALID', 'Usage quantity must be positive.', 400);
        }
        assertPeriod(input.periodStart, input.periodEnd);
        if (input.actorRole === 'SUPER_ADMIN') {
            return { unlimited: true, quantity: input.quantity };
        }

        // Global switch check
        if (!SubscriptionService.globalSubscriptionEnabled) {
            return { unlimited: true, quantity: input.quantity };
        }

        return this.db.$transaction(async (tx) => {
            const subscription = await tx.subscription.findFirst({
                where: {
                    orgId: input.orgId,
                    status: { in: [...ACTIVE_SUBSCRIPTION_STATUSES] },
                    currentPeriodEnd: { gt: new Date() },
                },
                include: { entitlements: { where: { key: input.metric } } },
                orderBy: { createdAt: 'desc' },
            });
            if (!subscription) throw new AppError('SUBSCRIPTION_REQUIRED', 'An active subscription is required for this operation.', 402);
            if (subscription.unlimitedAccess) return { unlimited: true, quantity: input.quantity };

            const limit = numericLimit(subscription.entitlements[0]?.value);
            const current = await tx.usageRecord.findUnique({
                where: {
                    orgId_metric_periodStart_periodEnd: {
                        orgId: input.orgId,
                        metric: input.metric,
                        periodStart: input.periodStart,
                        periodEnd: input.periodEnd,
                    },
                },
            });
            const nextQuantity = Number(current?.quantity ?? 0) + input.quantity;
            if (limit !== null && nextQuantity > limit) {
                throw new AppError(
                    'USAGE_LIMIT_REACHED',
                    `The organization has reached its plan limit of ${limit}; current usage is ${Number(current?.quantity ?? 0)}.`,
                    409,
                );
            }

            const usage = await tx.usageRecord.upsert({
                where: {
                    orgId_metric_periodStart_periodEnd: {
                        orgId: input.orgId,
                        metric: input.metric,
                        periodStart: input.periodStart,
                        periodEnd: input.periodEnd,
                    },
                },
                create: {
                    orgId: input.orgId,
                    subscriptionId: subscription.id,
                    metric: input.metric,
                    periodStart: input.periodStart,
                    periodEnd: input.periodEnd,
                    quantity: input.quantity,
                },
                update: { quantity: { increment: input.quantity }, subscriptionId: subscription.id },
            });
            return { unlimited: false, quantity: usage.quantity };
        });
    }

    /**
     * Super Admin grants Unlimited Access to an organization/owner.
     * Preserves subscription history while setting unlimitedAccess = true.
     */
    async grantUnlimitedAccess(orgId: string, actorId: string, actorRole: string) {
        assertNonBlank(orgId, 'ORG_REQUIRED', 'Organization is required.');
        if (actorRole !== 'SUPER_ADMIN') {
            throw new AppError('UNAUTHORIZED', 'Only Super Admin can grant unlimited access.', 403);
        }

        return this.db.$transaction(async (tx) => {
            const subscription = await tx.subscription.findFirst({
                where: { orgId, status: { in: [...ACTIVE_SUBSCRIPTION_STATUSES] } },
                orderBy: { createdAt: 'desc' },
            });
            if (!subscription) {
                throw new AppError('SUBSCRIPTION_NOT_FOUND', 'No active subscription found to grant unlimited access.', 404);
            }

            const updated = await tx.subscription.update({
                where: { id: subscription.id },
                data: { unlimitedAccess: true, changedById: actorId },
            });

            return updated;
        });
    }

    /**
     * Super Admin revokes Unlimited Access from an organization/owner.
     * Restores the normal subscription plan entitlements.
     */
    async revokeUnlimitedAccess(orgId: string, actorId: string, actorRole: string) {
        assertNonBlank(orgId, 'ORG_REQUIRED', 'Organization is required.');
        if (actorRole !== 'SUPER_ADMIN') {
            throw new AppError('UNAUTHORIZED', 'Only Super Admin can revoke unlimited access.', 403);
        }

        return this.db.$transaction(async (tx) => {
            const subscription = await tx.subscription.findFirst({
                where: { orgId, status: { in: [...ACTIVE_SUBSCRIPTION_STATUSES] } },
                orderBy: { createdAt: 'desc' },
            });
            if (!subscription) {
                throw new AppError('SUBSCRIPTION_NOT_FOUND', 'No active subscription found.', 404);
            }

            const updated = await tx.subscription.update({
                where: { id: subscription.id },
                data: { unlimitedAccess: false, changedById: actorId },
            });

            return updated;
        });
    }

    async createInvoice(input: CreateInvoiceInput) {
        assertNonBlank(input.orgId, 'ORG_REQUIRED', 'Organization is required.');
        assertNonBlank(input.invoiceNumber, 'INVOICE_NUMBER_REQUIRED', 'Invoice number is required.');
        const taxMinor = input.taxMinor ?? 0n;
        if (input.subtotalMinor < 0n || taxMinor < 0n || input.subtotalMinor + taxMinor < 0n) {
            throw new AppError('INVOICE_AMOUNT_INVALID', 'Invoice amounts must be non-negative.', 400);
        }

        return this.db.invoice.create({
            data: {
                orgId: input.orgId,
                subscriptionId: input.subscriptionId,
                invoiceNumber: input.invoiceNumber,
                providerInvoiceId: input.providerInvoiceId,
                providerOrderId: input.providerOrderId,
                subtotalMinor: input.subtotalMinor,
                taxMinor,
                totalMinor: input.subtotalMinor + taxMinor,
                currency: input.currency ?? 'INR',
                status: 'OPEN',
                dueAt: input.dueAt,
            },
        });
    }

    async processPaymentEvent(input: PaymentEventInput): Promise<{ duplicate: boolean; status: string }> {
        assertNonBlank(input.provider, 'PAYMENT_PROVIDER_REQUIRED', 'Payment provider is required.');
        assertNonBlank(input.providerEventId, 'PAYMENT_EVENT_ID_REQUIRED', 'Provider event ID is required.');
        assertNonBlank(input.eventType, 'PAYMENT_EVENT_TYPE_REQUIRED', 'Payment event type is required.');

        try {
            return await this.db.$transaction(async (tx) => {
                const existing = await tx.paymentEvent.findUnique({
                    where: { provider_providerEventId: { provider: input.provider, providerEventId: input.providerEventId } },
                });
                if (existing) return { duplicate: true, status: existing.status };

                const event = await tx.paymentEvent.create({
                    data: {
                        orgId: input.orgId,
                        subscriptionId: input.subscriptionId,
                        provider: input.provider,
                        providerEventId: input.providerEventId,
                        eventType: input.eventType,
                        payload: input.payload,
                    },
                });

                const activates = input.eventType.includes('activated')
                    || input.eventType.includes('paid')
                    || input.eventType.includes('captured');
                const failed = input.eventType.includes('failed');
                const canceled = input.eventType.includes('cancel');

                if (input.subscriptionId) {
                    const subscription = await tx.subscription.findFirst({ where: { id: input.subscriptionId, ...(input.orgId ? { orgId: input.orgId } : {}) } });
                    if (!subscription) throw new AppError('PAYMENT_EVENT_TENANT_MISMATCH', 'Payment event does not belong to the organization.', 403);
                    const nextStatus = activates ? 'ACTIVE' : failed ? 'PAST_DUE' : canceled ? 'CANCELED' : null;
                    if (nextStatus) await tx.subscription.update({ where: { id: subscription.id }, data: { status: nextStatus } });
                }

                if (input.providerOrderId && (activates || canceled)) {
                    const invoice = await tx.invoice.findFirst({
                        where: {
                            providerOrderId: input.providerOrderId,
                            ...(input.orgId ? { orgId: input.orgId } : {}),
                            ...(input.subscriptionId ? { subscriptionId: input.subscriptionId } : {}),
                        },
                    });
                    if (invoice) {
                        await tx.invoice.update({
                            where: { id: invoice.id },
                            data: activates
                                ? { status: 'PAID', paidAt: new Date() }
                                : { status: 'VOID' },
                        });
                    }
                }

                const processed = activates || failed || canceled;
                await tx.paymentEvent.update({
                    where: { id: event.id },
                    data: { status: processed ? 'PROCESSED' : 'IGNORED', processedAt: new Date() },
                });
                return { duplicate: false, status: processed ? 'PROCESSED' : 'IGNORED' };
            });
        } catch (error) {
            if (!isUniqueViolation(error)) throw error;
            const existing = await this.db.paymentEvent.findUnique({
                where: { provider_providerEventId: { provider: input.provider, providerEventId: input.providerEventId } },
            });
            return { duplicate: Boolean(existing), status: existing?.status ?? 'RECEIVED' };
        }
    }
}

export const subscriptionService = new SubscriptionService();
