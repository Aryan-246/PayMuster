import { AppError } from '../lib/app-error.js';
import { prisma } from '../lib/prisma.js';

const ACTIVE_SUBSCRIPTION_STATUSES = ['TRIALING', 'ACTIVE', 'PAST_DUE'] as const;

// Persisted, server-authoritative global subscription switch. Stored as a single
// system_settings row so the state survives restarts and is shared across every
// backend instance, exactly like the maintenance-mode flag.
const GLOBAL_SUBSCRIPTION_SWITCH_KEY = 'GLOBAL_SUBSCRIPTION_ENABLED';
const SWITCH_CACHE_TTL_MS = 30_000;
const SYSTEM_SETTINGS_AUDIT_ENTITY_ID = '00000000-0000-0000-0000-000000000000';

type JsonObject = Record<string, unknown>;

type BillingDb = {
    $transaction<T>(callback: (tx: BillingDb) => Promise<T>, options?: unknown): Promise<T>;
    plan: any;
    subscription: any;
    entitlement: any;
    usageRecord: any;
    invoice: any;
    paymentEvent: any;
    user: any;
    organization: any;
    systemSettings?: any;
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
    private readonly db: BillingDb;
    // Short-lived, in-process read cache for the persisted global switch. The
    // system_settings row is the source of truth shared by every backend
    // instance; the cache only spares frequent entitlement checks a database
    // round-trip, mirroring maintenance-service's 30s window.
    private switchCache: { value: boolean; fetchedAt: number } | null = null;

    constructor(db: BillingDb = prisma as unknown as BillingDb) {
        this.db = db;
    }

    /**
     * Server-authoritative global subscription switch, persisted in system_settings.
     * OFF: all users get unrestricted subscription feature access while normal RBAC remains active.
     * ON: normal subscription checking resumes.
     * Toggling OFF does NOT delete or cancel existing subscriptions; switching ON again
     * resumes the pre-existing subscription/plan/trial/entitlement state untouched.
     * Defaults to ON (enforcement enabled) when the row has never been written, and
     * survives process restarts because the state lives in the database.
     */
    async getGlobalSubscriptionSwitch(): Promise<boolean> {
        const now = Date.now();
        if (this.switchCache && now - this.switchCache.fetchedAt < SWITCH_CACHE_TTL_MS) {
            return this.switchCache.value;
        }
        const setting = await this.db.systemSettings.findUnique({
            where: { key: GLOBAL_SUBSCRIPTION_SWITCH_KEY },
        });
        // Absence of the row means enforcement has never been disabled: default ON.
        const value = setting ? setting.value !== 'false' : true;
        this.switchCache = { value, fetchedAt: now };
        return value;
    }

    async setGlobalSubscriptionSwitch(enabled: boolean, actorId: string, actorRole?: string): Promise<boolean> {
        if (actorRole && actorRole !== 'ADMIN' && actorRole !== 'SUPER_ADMIN') {
            throw new AppError('UNAUTHORIZED', 'Only Admin or Super Admin can toggle the global subscription switch.', 403);
        }
        assertNonBlank(actorId, 'ACTOR_REQUIRED', 'An actor identity is required to change the global subscription switch.');

        const value = enabled ? 'true' : 'false';
        await this.db.$transaction(async (tx) => {
            await tx.systemSettings.upsert({
                where: { key: GLOBAL_SUBSCRIPTION_SWITCH_KEY },
                update: { value, updatedBy: actorId },
                create: { key: GLOBAL_SUBSCRIPTION_SWITCH_KEY, value, updatedBy: actorId },
            });
            if (tx.auditLog) {
                await tx.auditLog.create({
                    data: {
                        action: 'UPDATE',
                        entityType: 'SystemSettings',
                        entityId: SYSTEM_SETTINGS_AUDIT_ENTITY_ID,
                        changes: { key: GLOBAL_SUBSCRIPTION_SWITCH_KEY, enabled },
                        userId: actorId,
                    },
                });
            }
        });
        // Write-through so this instance observes the change without waiting for the TTL.
        this.switchCache = { value: enabled, fetchedAt: Date.now() };
        return enabled;
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
        if (!(await this.getGlobalSubscriptionSwitch())) {
            return { allowed: true, unlimited: true, limit: null, source: 'SUBSCRIPTION' };
        }

        const now = new Date();
        const subscription = await this.db.subscription.findFirst({
            where: {
                orgId,
                status: { in: [...ACTIVE_SUBSCRIPTION_STATUSES] },
                currentPeriodEnd: { gt: now },
            },
            include: { entitlements: { where: { key } } },
            orderBy: { createdAt: 'desc' },
        });
        if (!subscription) {
            // Lazy expiry reconciliation: a row still marked TRIALING/ACTIVE/PAST_DUE
            // whose period has ended must transition to EXPIRED before access is
            // denied. Conditional updateMany → idempotent and safe under concurrency.
            await this.expireSubscriptionsForOrg(orgId);
            return { allowed: false, unlimited: false, limit: null, source: 'NONE' };
        }
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
        if (!(await this.getGlobalSubscriptionSwitch())) {
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

            // Atomic conditional increment (blueprint §R): the updateMany only
            // fires when quantity + n stays within the limit, closing the
            // check-then-increment race under concurrency and across instances.
            const usage = await this.reserveUsageAtomically(tx, input, limit, subscription.id);
            return { unlimited: false, quantity: usage };
        });
    }

    /**
     * Race-free usage reservation. First attempts a conditional increment that
     * only applies when the result stays within the limit; falls back to creating
     * the monthly row on first use, retrying the increment on unique-key races.
     */
    private async reserveUsageAtomically(
        tx: BillingDb,
        input: UsageInput,
        limit: number | null,
        subscriptionId: string,
    ): Promise<number> {
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
        const currentQuantity = Number(current?.quantity ?? 0);

        if (limit !== null && currentQuantity + input.quantity > limit) {
            throw new AppError(
                'USAGE_LIMIT_REACHED',
                `The organization has reached its plan limit of ${limit}; current usage is ${currentQuantity}.`,
                409,
            );
        }

        if (current) {
            const ceiling = limit === null ? Number.MAX_SAFE_INTEGER : limit - input.quantity;
            const updated = await tx.usageRecord.updateMany({
                where: {
                    orgId: input.orgId,
                    metric: input.metric,
                    periodStart: input.periodStart,
                    periodEnd: input.periodEnd,
                    quantity: { lte: ceiling },
                },
                data: { quantity: { increment: input.quantity }, subscriptionId },
            });
            if (updated.count === 0) {
                throw new AppError(
                    'USAGE_LIMIT_REACHED',
                    `The organization has reached its plan limit of ${limit}.`,
                    409,
                );
            }
            return currentQuantity + input.quantity;
        }

        try {
            const created = await tx.usageRecord.create({
                data: {
                    orgId: input.orgId,
                    subscriptionId,
                    metric: input.metric,
                    periodStart: input.periodStart,
                    periodEnd: input.periodEnd,
                    quantity: input.quantity,
                },
            });
            return Number(created.quantity);
        } catch (error) {
            if (!isUniqueViolation(error)) throw error;
            // A concurrent request created the row first: retry the conditional
            // increment on the now-existing row.
            const ceiling = limit === null ? Number.MAX_SAFE_INTEGER : limit - input.quantity;
            const updated = await tx.usageRecord.updateMany({
                where: {
                    orgId: input.orgId,
                    metric: input.metric,
                    periodStart: input.periodStart,
                    periodEnd: input.periodEnd,
                    quantity: { lte: ceiling },
                },
                data: { quantity: { increment: input.quantity }, subscriptionId },
            });
            if (updated.count === 0) {
                throw new AppError(
                    'USAGE_LIMIT_REACHED',
                    `The organization has reached its plan limit of ${limit}.`,
                    409,
                );
            }
            return input.quantity; // best-effort returned quantity; the row is authoritative
        }
    }

    /**
     * Idempotent expiry reconciliation (state machine, blueprint §I): transitions
     * subscriptions whose period has ended — status still TRIALING/ACTIVE/PAST_DUE —
     * to EXPIRED. A sub that ended while enforcement was OFF is expired the moment
     * enforcement resumes; currentPeriodEnd is NEVER extended (no free time for the
     * OFF window) and no payment/refund/cancellation events are emitted. The
     * conditional updateMany excludes already-EXPIRED rows, so re-running is a
     * no-op and concurrent runs converge to a single terminal state.
     */
    async reconcileExpiredSubscriptions(actorId?: string): Promise<number> {
        const now = new Date();
        return this.db.$transaction(async (tx) => {
            const result = await tx.subscription.updateMany({
                where: {
                    status: { in: [...ACTIVE_SUBSCRIPTION_STATUSES] },
                    currentPeriodEnd: { lt: now },
                },
                data: {
                    status: 'EXPIRED',
                    ...(actorId ? { changedById: actorId } : {}),
                },
            });
            if (result.count > 0 && tx.auditLog) {
                await tx.auditLog.create({
                    data: {
                        action: 'UPDATE',
                        entityType: 'Subscription',
                        entityId: SYSTEM_SETTINGS_AUDIT_ENTITY_ID,
                        changes: { from: 'ACTIVE_SET', to: 'EXPIRED', reason: 'PERIOD_ENDED', count: result.count },
                        userId: actorId ?? null,
                    },
                });
            }
            return result.count;
        });
    }

    /**
     * Lazy per-org expiry reconciliation, invoked from getFeatureAccess when an org
     * has no active-period subscription: flip any stale TRIALING/ACTIVE/PAST_DUE rows
     * whose period has ended before denying access.
     */
    private async expireSubscriptionsForOrg(orgId: string): Promise<number> {
        const now = new Date();
        return this.db.$transaction(async (tx) => {
            const result = await tx.subscription.updateMany({
                where: {
                    orgId,
                    status: { in: [...ACTIVE_SUBSCRIPTION_STATUSES] },
                    currentPeriodEnd: { lt: now },
                },
                data: { status: 'EXPIRED' },
            });
            if (result.count > 0 && tx.auditLog) {
                await tx.auditLog.create({
                    data: {
                        action: 'UPDATE',
                        entityType: 'Subscription',
                        entityId: SYSTEM_SETTINGS_AUDIT_ENTITY_ID,
                        orgId,
                        changes: { from: 'ACTIVE_SET', to: 'EXPIRED', reason: 'PERIOD_ENDED', count: result.count },
                        userId: null,
                    },
                });
            }
            return result.count;
        });
    }

    /**
     * Super Admin grants Unlimited Access to an organization/owner.
     * Preserves subscription history while setting unlimitedAccess = true.
     *
     * Business rule: an organization without any subscription record is not a
     * dead end — a subscription is provisioned first (ACTIVE, on the cheapest
     * active plan, with that plan's entitlements) and unlimited access is
     * granted on top of it. Revoking later returns the organization to real
     * plan limits instead of leaving it in limbo. Owners are notified and the
     * change is audited either way.
     */
    async grantUnlimitedAccess(orgId: string, actorId: string, actorRole: string) {
        assertNonBlank(orgId, 'ORG_REQUIRED', 'Organization is required.');
        if (actorRole !== 'SUPER_ADMIN') {
            throw new AppError('UNAUTHORIZED', 'Only Super Admin can grant unlimited access.', 403);
        }

        const result = await this.db.$transaction(async (tx) => {
            const org = await tx.organization.findUnique({ where: { id: orgId }, select: { id: true, name: true, deletedAt: true } });
            if (!org || org.deletedAt) {
                throw new AppError('ORG_NOT_FOUND', 'Organization not found.', 404);
            }

            let subscription = await tx.subscription.findFirst({
                where: { orgId, status: { in: [...ACTIVE_SUBSCRIPTION_STATUSES] } },
                orderBy: { createdAt: 'desc' },
            });
            let provisioned = false;

            if (!subscription) {
                // Provision before granting: cheapest active plan, no trial,
                // long-lived period (the unlimited flag — not the calendar —
                // is the gate; reconciliation never expires it away).
                const plan = await tx.plan.findFirst({ where: { isActive: true }, orderBy: { amountMinor: 'asc' } });
                if (!plan) {
                    throw new AppError('PLAN_NOT_FOUND', 'No active plan exists to provision a subscription for this organization.', 404);
                }
                const periodStart = new Date();
                const periodEnd = new Date(periodStart.getTime() + 100 * 365 * 24 * 60 * 60 * 1000);
                subscription = await tx.subscription.create({
                    data: {
                        orgId,
                        planId: plan.id,
                        status: 'ACTIVE',
                        provider: 'razorpay',
                        currentPeriodStart: periodStart,
                        currentPeriodEnd: periodEnd,
                        unlimitedAccess: true,
                        changedById: actorId,
                    },
                });
                provisioned = true;

                // The provisioned plan's entitlements keep the revoke path
                // coherent: unlimited off → normal plan limits apply.
                const limits = (plan.featureLimits as JsonObject) || {};
                const entries = Object.entries(limits);
                if (entries.length > 0) {
                    await tx.entitlement.createMany({
                        data: entries.map(([key, value]) => ({
                            orgId,
                            subscriptionId: subscription.id,
                            key,
                            value,
                            source: 'PLAN',
                            expiresAt: periodEnd,
                        })),
                    });
                }
            } else {
                subscription = await tx.subscription.update({
                    where: { id: subscription.id },
                    data: { unlimitedAccess: true, changedById: actorId },
                });
            }

            if (tx.notification) {
                const owners = await tx.user.findMany({
                    where: { orgId, role: 'OWNER', deletedAt: null },
                    select: { id: true },
                });
                if (owners.length > 0) {
                    await tx.notification.createMany({
                        data: owners.map((owner: { id: string }) => ({
                            orgId,
                            userId: owner.id,
                            title: 'Unlimited access granted',
                            body: 'PayMuster has granted your company unlimited access. All plan limits are lifted until further notice.',
                            type: 'SUBSCRIPTION_UPDATE',
                            deepLink: null,
                        })),
                    });
                }
            }

            if (tx.auditLog) {
                await tx.auditLog.create({
                    data: {
                        action: provisioned ? 'CREATE' : 'UPDATE',
                        entityType: 'Subscription',
                        entityId: subscription.id,
                        orgId,
                        userId: actorId,
                        changes: { unlimitedAccess: true, provisioned },
                    },
                });
            }

            return { ...subscription, provisioned };
        });

        return result;
    }

    /**
     * Super Admin revokes Unlimited Access from an organization/owner.
     * Restores the normal subscription plan entitlements (or the provisioned
     * plan's limits when the subscription was provisioned by a grant).
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

            if (tx.notification) {
                const owners = await tx.user.findMany({
                    where: { orgId, role: 'OWNER', deletedAt: null },
                    select: { id: true },
                });
                if (owners.length > 0) {
                    await tx.notification.createMany({
                        data: owners.map((owner: { id: string }) => ({
                            orgId,
                            userId: owner.id,
                            title: 'Unlimited access ended',
                            body: 'Unlimited access for your company has ended. Normal plan limits now apply.',
                            type: 'SUBSCRIPTION_UPDATE',
                            deepLink: null,
                        })),
                    });
                }
            }

            if (tx.auditLog) {
                await tx.auditLog.create({
                    data: {
                        action: 'UPDATE',
                        entityType: 'Subscription',
                        entityId: subscription.id,
                        orgId,
                        userId: actorId,
                        changes: { unlimitedAccess: false },
                    },
                });
            }

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
