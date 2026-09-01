import assert from 'node:assert/strict';
import test from 'node:test';
import { AdminSubscriptionService } from './admin-subscription.service.js';
import { AppError } from '../lib/app-error.js';

const orgId = '11111111-1111-4111-8111-111111111111';
const adminId = '99999999-9999-4999-8999-999999999999';
const ownerId = '88888888-8888-4888-8888-888888888888';

function makeDb(options: {
    org?: { id: string; name: string } | null;
    existingEntitlement?: { id: string; key: string; source: string; orgId: string } | null;
    owners?: Array<{ id: string }>;
} = {}) {
    const {
        org = { id: orgId, name: 'Acme Construction' },
        existingEntitlement = null,
        owners = [{ id: ownerId }],
    } = options;

    const state = {
        createdEntitlements: [] as Array<any>,
        deletedEntitlements: [] as Array<string>,
        notifications: [] as Array<any>[],
        auditRows: [] as Array<any>,
    };

    const db = {
        state,
        $transaction: async (fn: (tx: unknown) => Promise<unknown>) => fn(db),
        organization: {
            findUnique: async () => org,
        },
        entitlement: {
            findUnique: async () => existingEntitlement,
            create: async (args: { data: Record<string, unknown> }) => {
                state.createdEntitlements.push(args.data);
                return { id: 'ent-1', ...args.data };
            },
            delete: async (args: { where: { id: string } }) => {
                state.deletedEntitlements.push(args.where.id);
                return {};
            },
        },
        user: {
            findMany: async () => owners,
        },
        notification: {
            createMany: async (args: { data: Array<any> }) => {
                state.notifications.push(args.data);
                return { count: args.data.length };
            },
        },
        auditLog: {
            create: async (args: { data: Record<string, unknown> }) => {
                state.auditRows.push(args.data);
                return {};
            },
        },
    };
    return db;
}

// ---------------------------------------------------------------------------
// grantOffer
// ---------------------------------------------------------------------------

test('grantOffer rejects a missing org or key', async () => {
    const service = new AdminSubscriptionService(makeDb() as never);
    await assert.rejects(
        service.grantOffer({ orgId: ' ', adminId, key: 'offer:x', value: 'unlimited' }),
        (err) => err instanceof AppError && err.code === 'ORG_REQUIRED',
    );
    await assert.rejects(
        service.grantOffer({ orgId, adminId, key: '  ', value: 'unlimited' }),
        (err) => err instanceof AppError && err.code === 'VALIDATION_ERROR',
    );
});

test('grantOffer rejects an unknown organization', async () => {
    const service = new AdminSubscriptionService(makeDb({ org: null }) as never);
    await assert.rejects(
        service.grantOffer({ orgId, adminId, key: 'offer:promo', value: 100 }),
        (err) => err instanceof AppError && err.code === 'ORG_NOT_FOUND' && err.status === 404,
    );
});

test('grantOffer rejects a duplicate active offer with 409 OFFER_EXISTS', async () => {
    const service = new AdminSubscriptionService(
        makeDb({ existingEntitlement: { id: 'ent-existing', key: 'offer:promo', source: 'OFFER', orgId } }) as never,
    );
    await assert.rejects(
        service.grantOffer({ orgId, adminId, key: 'offer:promo', value: 100 }),
        (err) => err instanceof AppError && err.code === 'OFFER_EXISTS' && err.status === 409,
    );
});

test('grantOffer refuses to overwrite a PLAN-sourced entitlement key (409 OFFER_KEY_CONFLICT)', async () => {
    const service = new AdminSubscriptionService(
        makeDb({ existingEntitlement: { id: 'ent-plan', key: 'mail_supply', source: 'PLAN', orgId } }) as never,
    );
    await assert.rejects(
        service.grantOffer({ orgId, adminId, key: 'mail_supply', value: 100 }),
        (err) => err instanceof AppError && err.code === 'OFFER_KEY_CONFLICT' && err.status === 409,
    );
});

test('grantOffer creates an OFFER entitlement, notifies owners and audits', async () => {
    const db = makeDb();
    const service = new AdminSubscriptionService(db as never);
    const expiresAt = new Date('2026-12-31T00:00:00.000Z');

    const entitlement = await service.grantOffer({
        orgId,
        adminId,
        key: 'offer:diwali',
        value: 'unlimited',
        expiresAt,
        note: 'Diwali promo',
    });

    assert.equal(entitlement.source, 'OFFER');
    assert.equal(db.state.createdEntitlements.length, 1);
    assert.equal(db.state.createdEntitlements[0].key, 'offer:diwali');
    assert.equal(db.state.createdEntitlements[0].value, true);
    assert.equal(db.state.createdEntitlements[0].expiresAt, expiresAt);
    // Owner notification (action → reaction).
    assert.equal(db.state.notifications.length, 1);
    assert.equal(db.state.notifications[0][0].type, 'SUBSCRIPTION_UPDATE');
    assert.equal(db.state.notifications[0][0].userId, ownerId);
    // Audit row.
    assert.equal(db.state.auditRows.length, 1);
    assert.equal(db.state.auditRows[0].entityType, 'Entitlement');
    assert.equal(db.state.auditRows[0].changes.source, 'OFFER');
});

test('grantOffer maps a numeric value straight through (mail quota lift)', async () => {
    const db = makeDb();
    const service = new AdminSubscriptionService(db as never);

    await service.grantOffer({ orgId, adminId, key: 'offer:bonus-mail', value: 50 });

    assert.equal(db.state.createdEntitlements[0].value, 50);
});

// ---------------------------------------------------------------------------
// revokeOffer
// ---------------------------------------------------------------------------

test('revokeOffer rejects missing inputs and unknown offers', async () => {
    const service = new AdminSubscriptionService(makeDb() as never);
    await assert.rejects(
        service.revokeOffer({ orgId: '', key: 'offer:x', adminId }),
        (err) => err instanceof AppError && err.code === 'ORG_REQUIRED',
    );
    await assert.rejects(
        service.revokeOffer({ orgId, key: '', adminId }),
        (err) => err instanceof AppError && err.code === 'VALIDATION_ERROR',
    );
    // No entitlement at all.
    await assert.rejects(
        service.revokeOffer({ orgId, key: 'offer:missing', adminId }),
        (err) => err instanceof AppError && err.code === 'OFFER_NOT_FOUND' && err.status === 404,
    );
});

test('revokeOffer refuses to delete a PLAN-sourced entitlement', async () => {
    const service = new AdminSubscriptionService(
        makeDb({ existingEntitlement: { id: 'ent-plan', key: 'mail_supply', source: 'PLAN', orgId } }) as never,
    );
    await assert.rejects(
        service.revokeOffer({ orgId, key: 'mail_supply', adminId }),
        (err) => err instanceof AppError && err.code === 'OFFER_NOT_FOUND',
    );
});

test('revokeOffer deletes the OFFER row, notifies owners and audits', async () => {
    const db = makeDb({
        existingEntitlement: { id: 'ent-offer', key: 'offer:diwali', source: 'OFFER', orgId },
    });
    const service = new AdminSubscriptionService(db as never);

    const result = await service.revokeOffer({ orgId, key: 'offer:diwali', adminId });

    assert.deepEqual(result, { orgId, key: 'offer:diwali', revoked: true });
    assert.deepEqual(db.state.deletedEntitlements, ['ent-offer']);
    assert.equal(db.state.notifications.length, 1);
    assert.equal(db.state.notifications[0][0].type, 'SUBSCRIPTION_UPDATE');
    assert.equal(db.state.auditRows.length, 1);
    assert.equal(db.state.auditRows[0].action, 'DELETE');
    assert.equal(db.state.auditRows[0].changes.revoked, true);
});

// ---------------------------------------------------------------------------
// listSubscribers / getSubscriberDetail — org-centric subscriber management
// ---------------------------------------------------------------------------

const otherOrgId = '33333333-3333-4333-8333-333333333333';

function makeSubscriberDb(options: {
    orgs?: Array<{
        id: string;
        name: string;
        publicId: string;
        createdAt: Date;
        deletedAt?: Date | null;
        subscriptions?: Array<Record<string, unknown>>;
    }>;
    owners?: Array<{ id: string; orgId: string; publicId: string; firstName: string; lastName: string; email: string }>;
    mailUsage?: { quantity: number } | null;
} = {}) {
    const orgs = options.orgs ?? [];
    const owners = options.owners ?? [];
    const subscriptions = orgs.flatMap((o) => (o.subscriptions ?? []).map((s) => ({ orgId: o.id, ...s })));

    return {
        organization: {
            findMany: async () => orgs.map((o) => ({ ...o, subscriptions: o.subscriptions ?? [] })),
            count: async (args: { where?: Record<string, unknown> } = {}) => {
                const where = args.where ?? {};
                if (where.subscriptions && (where.subscriptions as any).none) {
                    const excludedStatuses = (where.subscriptions as any).none.status.in as string[];
                    return orgs.filter(
                        (o) => !(o.subscriptions ?? []).some((s: any) => excludedStatuses.includes(s.status)),
                    ).length;
                }
                return orgs.filter((o) => !o.deletedAt).length;
            },
            findUnique: async (args: { where: { id: string } }) =>
                orgs.find((o) => o.id === args.where.id) ?? null,
        },
        subscription: {
            count: async (args: { where?: Record<string, unknown> } = {}) => {
                const where: any = args.where ?? {};
                return subscriptions.filter((s: any) => {
                    if (where.status && where.status.in) {
                        if (!where.status.in.includes(s.status)) return false;
                    } else if (where.status && where.status !== s.status) return false;
                    if (where.unlimitedAccess !== undefined && where.unlimitedAccess !== s.unlimitedAccess) return false;
                    return true;
                }).length;
            },
            findFirst: async (args: { where?: Record<string, unknown> } = {}) => {
                const rows = subscriptions.filter((s: any) => !args.where || s.orgId === args.where.orgId);
                return rows.length > 0 ? rows[rows.length - 1] : null;
            },
            findMany: async (args: { where?: Record<string, unknown> } = {}) =>
                subscriptions.filter((s: any) => !args.where || s.orgId === args.where.orgId),
        },
        user: {
            findMany: async (args: { where: Record<string, unknown> } = { where: {} }) =>
                owners.filter((o) => (args.where.orgId ? (args.where.orgId as any).in?.includes(o.orgId) ?? o.orgId === args.where.orgId : true)),
        },
        ownerRequest: { findMany: async () => [], findFirst: async () => null },
        usageRecord: { findUnique: async () => options.mailUsage ?? null },
    };
}

test('listSubscribers is org-centric: organizations without subscriptions appear (bug fix)', async () => {
    // Regression for the reported bug: platform had orgs/owners/users but the
    // subscriber screen showed "0 Total / 0 Active / No subscribers" because
    // the query read only the subscription table.
    const now = new Date();
    const service = new AdminSubscriptionService(makeSubscriberDb({
        orgs: [
            {
                id: orgId,
                name: 'Acme Construction',
                publicId: 'PM-CMP-000001',
                createdAt: now,
                subscriptions: [{ id: 'sub-1', status: 'ACTIVE', unlimitedAccess: false, plan: { code: 'FREE', name: 'Free' } }],
            },
            {
                id: otherOrgId,
                name: 'Globex Industries',
                publicId: 'PM-CMP-000002',
                createdAt: now,
                subscriptions: [],
            },
        ],
        owners: [{ id: ownerId, orgId, publicId: 'PM-USR-000001', firstName: 'Jane', lastName: 'Owner', email: 'jane@acme.test' }],
    }) as never);

    const result = await service.listSubscribers({});

    assert.equal(result.subscribers.length, 2);
    assert.equal(result.total, 2);
    assert.equal(result.summary.total, 2);
    assert.equal(result.summary.noSubscriptionCount, 1);
    const globex = result.subscribers.find((s: any) => s.orgId === otherOrgId) as any;
    assert.equal(globex.status, 'NO_SUBSCRIPTION');
    assert.equal(globex.plan, null);
    assert.equal(globex.unlimitedAccess, false);
    // The org WITH a subscription keeps its real data.
    const acme = result.subscribers.find((s: any) => s.orgId === orgId) as any;
    assert.equal(acme.status, 'ACTIVE');
    assert.equal(acme.plan.code, 'FREE');
    assert.equal(acme.owner.email, 'jane@acme.test');
});

test('listSubscribers filters: status NONE returns only orgs without an active subscription', async () => {
    const now = new Date();
    const service = new AdminSubscriptionService(makeSubscriberDb({
        orgs: [
            { id: orgId, name: 'Acme', publicId: 'PM-CMP-000001', createdAt: now, subscriptions: [{ id: 'sub-1', status: 'ACTIVE', unlimitedAccess: false }] },
            { id: otherOrgId, name: 'Globex', publicId: 'PM-CMP-000002', createdAt: now, subscriptions: [] },
            { id: '44444444-4444-4444-8444-444444444444', name: 'Initech', publicId: 'PM-CMP-000003', createdAt: now, subscriptions: [{ id: 'sub-2', status: 'EXPIRED', unlimitedAccess: false }] },
        ],
    }) as never);

    const result = await service.listSubscribers({ status: 'NONE' });

    assert.deepEqual(result.subscribers.map((s: any) => s.org.name).sort(), ['Globex', 'Initech']);
});

test('listSubscribers pagination and unlimited filter still work', async () => {
    const now = new Date();
    const service = new AdminSubscriptionService(makeSubscriberDb({
        orgs: [
            { id: orgId, name: 'Acme', publicId: 'PM-CMP-000001', createdAt: now, subscriptions: [{ id: 'sub-1', status: 'ACTIVE', unlimitedAccess: true }] },
            { id: otherOrgId, name: 'Globex', publicId: 'PM-CMP-000002', createdAt: now, subscriptions: [] },
        ],
    }) as never);

    const unlimitedOnly = await service.listSubscribers({ unlimited: 'GRANTED' });
    assert.equal(unlimitedOnly.subscribers.length, 1);
    assert.equal(unlimitedOnly.subscribers[0].orgId, orgId);

    const paged = await service.listSubscribers({ page: 2, limit: 1 });
    assert.equal(paged.subscribers.length, 1);
    assert.equal(paged.page, 2);
    assert.equal(paged.totalPages, 2);
});

test('getSubscriberDetail returns a displayable no-subscription state instead of a 404 dead end', async () => {
    // Regression for the Owners screen bug: tapping "Subscription" for an org
    // without one threw 404 "No subscription found for this organization."
    const now = new Date();
    const service = new AdminSubscriptionService(makeSubscriberDb({
        orgs: [{ id: orgId, name: 'Globex Industries', publicId: 'PM-CMP-000002', createdAt: now, subscriptions: [] }],
        owners: [],
    }) as never);

    const detail = await service.getSubscriberDetail(orgId);

    assert.equal(detail.subscription, null);
    assert.equal(detail.noSubscription, true);
    assert.equal(detail.provisionable, true);
    assert.equal(detail.org.name, 'Globex Industries');
    assert.deepEqual(detail.history, []);
    assert.equal(detail.mailUsage.sentThisMonth, 0);
});

test('getSubscriberDetail 404s only for an unknown organization', async () => {
    const service = new AdminSubscriptionService(makeSubscriberDb({ orgs: [] }) as never);
    await assert.rejects(
        service.getSubscriberDetail('55555555-5555-4555-8555-555555555555'),
        (err) => err instanceof AppError && err.code === 'ORG_NOT_FOUND' && err.status === 404,
    );
});
