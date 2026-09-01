import assert from 'node:assert/strict';
import test from 'node:test';

import { AppError } from '../lib/app-error.js';
import { SubscriptionService } from './subscription.service.js';

const orgId = '11111111-1111-4111-8111-111111111111';
const otherOrgId = '22222222-2222-4222-8222-222222222222';
const subscriptionId = '33333333-3333-4333-8333-333333333333';

function errorWithCode(promise: Promise<unknown>, code: string): Promise<void> {
    return promise.then(
        () => assert.fail(`Expected ${code} to be thrown`),
        (error: unknown) => {
            assert.ok(error instanceof AppError);
            assert.equal(error.code, code);
        },
    );
}

test('Super Admin feature access is unlimited without reading tenant billing state', async () => {
    let reads = 0;
    const service = new SubscriptionService({
        subscription: { findFirst: async () => { reads += 1; throw new Error('must not read billing state'); } },
    } as any);

    const access = await service.getFeatureAccess(orgId, 'staff.seats', 'SUPER_ADMIN');

    assert.deepEqual(access, { allowed: true, unlimited: true, limit: null, source: 'SUPER_ADMIN' });
    assert.equal(reads, 0);
});

test('trial creation scopes the existing-subscription check and created row to the organization', async () => {
    const calls: Array<{ delegate: string; args: any }> = [];
    const tx = {
        plan: {
            findFirst: async (args: any) => {
                calls.push({ delegate: 'plan.findFirst', args });
                return {
                    id: '44444444-4444-4444-8444-444444444444',
                    code: 'starter',
                    trialDays: 14,
                    interval: 'MONTH',
                    featureLimits: { 'staff.seats': 10 },
                };
            },
        },
        subscription: {
            findFirst: async (args: any) => {
                calls.push({ delegate: 'subscription.findFirst', args });
                return null;
            },
            create: async (args: any) => {
                calls.push({ delegate: 'subscription.create', args });
                return { id: subscriptionId, ...args.data };
            },
        },
        entitlement: {
            createMany: async (args: any) => {
                calls.push({ delegate: 'entitlement.createMany', args });
                return { count: args.data.length };
            },
        },
    };
    const service = new SubscriptionService({
        $transaction: async (callback: (client: any) => Promise<unknown>) => callback(tx),
    } as any);

    const result = await service.createTrial({ orgId, planCode: 'starter' });

    assert.equal(result.orgId, orgId);
    assert.deepEqual(calls[1].args.where, {
        orgId,
        status: { in: ['TRIALING', 'ACTIVE', 'PAST_DUE'] },
    });
    assert.equal(calls[2].args.data.orgId, orgId);
    assert.equal(calls[3].args.data[0].orgId, orgId);
    assert.equal(calls[3].args.data[0].key, 'staff.seats');
});

test('usage rejects a tenant once its entitlement limit would be exceeded', async () => {
    const periodStart = new Date('2026-08-01T00:00:00.000Z');
    const periodEnd = new Date('2026-09-01T00:00:00.000Z');
    const tx = {
        subscription: {
            findFirst: async (args: any) => {
                assert.equal(args.where.orgId, orgId);
                return {
                    id: subscriptionId,
                    orgId,
                    unlimitedAccess: false,
                    entitlements: [{ key: 'staff.seats', value: 5 }],
                };
            },
        },
        usageRecord: {
            findUnique: async () => ({ quantity: 5 }),
            upsert: async () => assert.fail('must not write after limit is reached'),
        },
    };
    const service = new SubscriptionService({
        systemSettings: { findUnique: async () => null },
        $transaction: async (callback: (client: any) => Promise<unknown>) => callback(tx),
    } as any);

    await errorWithCode(service.recordUsage({
        orgId,
        metric: 'staff.seats',
        quantity: 1,
        periodStart,
        periodEnd,
    }), 'USAGE_LIMIT_REACHED');
});

test('payment events are idempotent by provider event ID and do not replay mutations', async () => {
    let creates = 0;
    let updates = 0;
    const service = new SubscriptionService({
        $transaction: async (callback: (client: any) => Promise<unknown>) => callback({
            paymentEvent: {
                findUnique: async () => ({ id: 'event-id', status: 'PROCESSED' }),
                create: async () => { creates += 1; return { id: 'new-event' }; },
                update: async () => { updates += 1; return {}; },
            },
        }),
    } as any);

    const result = await service.processPaymentEvent({
        provider: 'razorpay',
        providerEventId: 'evt_123',
        eventType: 'subscription.activated',
        orgId,
        subscriptionId,
        payload: { safe: true },
    });

    assert.deepEqual(result, { duplicate: true, status: 'PROCESSED' });
    assert.equal(creates, 0);
    assert.equal(updates, 0);
});

test('captured payment settles only the tenant invoice linked to the provider order', async () => {
    const calls: Array<{ delegate: string; args: any }> = [];
    const service = new SubscriptionService({
        $transaction: async (callback: (client: any) => Promise<unknown>) => callback({
            paymentEvent: {
                findUnique: async () => null,
                create: async (args: any) => {
                    calls.push({ delegate: 'paymentEvent.create', args });
                    return { id: 'event-id' };
                },
                update: async (args: any) => {
                    calls.push({ delegate: 'paymentEvent.update', args });
                    return {};
                },
            },
            subscription: {
                findFirst: async (args: any) => {
                    calls.push({ delegate: 'subscription.findFirst', args });
                    return { id: subscriptionId, orgId };
                },
                update: async (args: any) => {
                    calls.push({ delegate: 'subscription.update', args });
                    return {};
                },
            },
            invoice: {
                findFirst: async (args: any) => {
                    calls.push({ delegate: 'invoice.findFirst', args });
                    return { id: 'invoice-id', orgId, subscriptionId };
                },
                update: async (args: any) => {
                    calls.push({ delegate: 'invoice.update', args });
                    return {};
                },
            },
        }),
    } as any);

    const result = await service.processPaymentEvent({
        provider: 'razorpay',
        providerEventId: 'evt_captured',
        eventType: 'payment.captured',
        orgId,
        subscriptionId,
        providerOrderId: 'order_123',
        payload: { safe: true },
    });

    assert.deepEqual(result, { duplicate: false, status: 'PROCESSED' });
    assert.deepEqual(
        calls.find((call) => call.delegate === 'invoice.findFirst')?.args.where,
        { providerOrderId: 'order_123', orgId, subscriptionId },
    );
    assert.equal(
        calls.find((call) => call.delegate === 'subscription.update')?.args.data.status,
        'ACTIVE',
    );
    const invoiceUpdate = calls.find((call) => call.delegate === 'invoice.update')?.args;
    assert.equal(invoiceUpdate.data.status, 'PAID');
    assert.ok(invoiceUpdate.data.paidAt instanceof Date);
});

test('failed payment moves access to past due without settling the invoice', async () => {
    let invoiceReads = 0;
    const service = new SubscriptionService({
        $transaction: async (callback: (client: any) => Promise<unknown>) => callback({
            paymentEvent: {
                findUnique: async () => null,
                create: async () => ({ id: 'event-id' }),
                update: async () => ({}),
            },
            subscription: {
                findFirst: async () => ({ id: subscriptionId, orgId }),
                update: async (args: any) => {
                    assert.equal(args.data.status, 'PAST_DUE');
                    return {};
                },
            },
            invoice: {
                findFirst: async () => {
                    invoiceReads += 1;
                    return null;
                },
                update: async () => assert.fail('failed payment must not settle an invoice'),
            },
        }),
    } as any);

    await service.processPaymentEvent({
        provider: 'razorpay',
        providerEventId: 'evt_failed',
        eventType: 'payment.failed',
        orgId,
        subscriptionId,
        providerOrderId: 'order_123',
        payload: { safe: true },
    });

    assert.equal(invoiceReads, 0);
});

test('payment event subscription lookup rejects a cross-tenant mutation', async () => {
    const service = new SubscriptionService({
        $transaction: async (callback: (client: any) => Promise<unknown>) => callback({
            paymentEvent: {
                findUnique: async () => null,
                create: async () => ({ id: 'event-id' }),
                update: async () => ({}),
            },
            subscription: {
                findFirst: async (args: any) => {
                    assert.deepEqual(args.where, { id: subscriptionId, orgId });
                    return null;
                },
            },
        }),
    } as any);

    await errorWithCode(service.processPaymentEvent({
        provider: 'razorpay',
        providerEventId: 'evt_cross_tenant',
        eventType: 'subscription.activated',
        orgId,
        subscriptionId,
        payload: { safe: true },
    }), 'PAYMENT_EVENT_TENANT_MISMATCH');
    assert.notEqual(orgId, otherOrgId);
});

test('persisted global switch OFF grants unrestricted access without reading subscription state', async () => {
    const service = new SubscriptionService({
        systemSettings: { findUnique: async () => ({ key: 'GLOBAL_SUBSCRIPTION_ENABLED', value: 'false' }) },
        subscription: {
            findFirst: async () => {
                assert.fail('Subscription state must not be read when the global switch is OFF');
            },
        },
    } as any);

    const access = await service.getFeatureAccess(orgId, 'staff.seats', 'STAFF');
    assert.deepEqual(access, { allowed: true, unlimited: true, limit: null, source: 'SUBSCRIPTION' });

    const usage = await service.recordUsage({
        orgId,
        metric: 'staff.seats',
        quantity: 5,
        periodStart: new Date('2026-08-01T00:00:00Z'),
        periodEnd: new Date('2026-09-01T00:00:00Z'),
        actorRole: 'STAFF',
    });
    assert.deepEqual(usage, { unlimited: true, quantity: 5 });
});

test('global switch defaults to ON (enforcement) when the setting row is absent', async () => {
    let reads = 0;
    const service = new SubscriptionService({
        systemSettings: { findUnique: async () => { reads += 1; return null; } },
    } as any);

    assert.equal(await service.getGlobalSubscriptionSwitch(), true);
    assert.equal(reads, 1);
});

test('setting the global switch persists to system_settings and writes an audit log', async () => {
    const calls: Array<{ delegate: string; args: any }> = [];
    const tx = {
        systemSettings: {
            upsert: async (args: any) => {
                calls.push({ delegate: 'systemSettings.upsert', args });
                return { key: args.where.key, value: args.create.value };
            },
        },
        auditLog: {
            create: async (args: any) => {
                calls.push({ delegate: 'auditLog.create', args });
                return { id: 'audit-1' };
            },
        },
    };
    const service = new SubscriptionService({
        systemSettings: { findUnique: async () => assert.fail('write-through cache must serve reads immediately after a set') },
        $transaction: async (callback: (client: any) => Promise<unknown>) => callback(tx),
    } as any);

    const result = await service.setGlobalSubscriptionSwitch(false, 'super-admin-1', 'SUPER_ADMIN');
    assert.equal(result, false);

    const upsert = calls.find((c) => c.delegate === 'systemSettings.upsert')?.args;
    assert.equal(upsert.where.key, 'GLOBAL_SUBSCRIPTION_ENABLED');
    assert.equal(upsert.update.value, 'false');
    assert.equal(upsert.create.value, 'false');
    assert.equal(upsert.update.updatedBy, 'super-admin-1');
    assert.equal(upsert.create.updatedBy, 'super-admin-1');

    const audit = calls.find((c) => c.delegate === 'auditLog.create')?.args;
    assert.equal(audit.data.entityType, 'SystemSettings');
    assert.equal(audit.data.action, 'UPDATE');
    assert.equal(audit.data.userId, 'super-admin-1');
    assert.deepEqual(audit.data.changes, { key: 'GLOBAL_SUBSCRIPTION_ENABLED', enabled: false });

    // Write-through: the just-set value is served from the cache without another DB read.
    assert.equal(await service.getGlobalSubscriptionSwitch(), false);
});

test('non-admin actors cannot toggle the global subscription switch', async () => {
    const service = new SubscriptionService({
        $transaction: async () => assert.fail('must not open a transaction for an unauthorized actor'),
    } as any);

    await errorWithCode(
        service.setGlobalSubscriptionSwitch(false, 'staff-1', 'STAFF'),
        'UNAUTHORIZED',
    );
});

test('the global switch read is cached within its TTL to avoid repeated database reads', async () => {
    let reads = 0;
    const service = new SubscriptionService({
        systemSettings: { findUnique: async () => { reads += 1; return { value: 'true' }; } },
    } as any);

    assert.equal(await service.getGlobalSubscriptionSwitch(), true);
    assert.equal(await service.getGlobalSubscriptionSwitch(), true);
    assert.equal(reads, 1);
});

test('Super Admin can grant and revoke unlimited access with audit trail', async () => {
    let unlimitedState = false;
    const notifications: any[] = [];
    const auditRows: any[] = [];
    const service = new SubscriptionService({
        $transaction: async (cb: any) => cb({
            organization: {
                findUnique: async () => ({ id: orgId, name: 'Acme Construction', deletedAt: null }),
            },
            subscription: {
                findFirst: async () => ({ id: subscriptionId, orgId, unlimitedAccess: unlimitedState }),
                update: async (args: any) => {
                    unlimitedState = args.data.unlimitedAccess;
                    return { id: subscriptionId, ...args.data };
                },
            },
            user: { findMany: async () => [{ id: 'owner-1' }] },
            notification: {
                createMany: async (args: any) => {
                    notifications.push(args.data);
                    return { count: args.data.length };
                },
            },
            auditLog: {
                create: async (args: any) => {
                    auditRows.push(args.data);
                    return {};
                },
            },
        }),
    } as any);

    // Non-super-admin cannot grant
    await assert.rejects(
        service.grantUnlimitedAccess(orgId, 'admin-1', 'ADMIN'),
        (err) => err instanceof AppError && err.code === 'UNAUTHORIZED',
    );

    // Super Admin grants unlimited access
    const granted = await service.grantUnlimitedAccess(orgId, 'super-admin-1', 'SUPER_ADMIN');
    assert.equal(granted.unlimitedAccess, true);
    assert.equal(granted.provisioned, false);
    assert.equal(unlimitedState, true);
    // Owner notification + audit (action → reaction + evidence).
    assert.equal(notifications.length, 1);
    assert.equal(notifications[0][0].title, 'Unlimited access granted');
    assert.equal(auditRows.length, 1);
    assert.equal(auditRows[0].entityType, 'Subscription');
    assert.equal(auditRows[0].changes.unlimitedAccess, true);

    // Super Admin revokes unlimited access
    const revoked = await service.revokeUnlimitedAccess(orgId, 'super-admin-1', 'SUPER_ADMIN');
    assert.equal(revoked.unlimitedAccess, false);
    assert.equal(unlimitedState, false);
    assert.equal(notifications.length, 2);
    assert.equal(notifications[1][0].title, 'Unlimited access ended');
    assert.equal(auditRows.length, 2);
});

test('grantUnlimitedAccess provisions a subscription when none exists (no dead end)', async () => {
    const created: any[] = [];
    const createdEntitlements: any[] = [];
    const notifications: any[] = [];
    const auditRows: any[] = [];
    let activeSubscription: any = null;
    const service = new SubscriptionService({
        $transaction: async (cb: any) => cb({
            organization: {
                findUnique: async () => ({ id: orgId, name: 'Acme Construction', deletedAt: null }),
            },
            subscription: {
                findFirst: async () => activeSubscription,
                create: async (args: any) => {
                    activeSubscription = { id: subscriptionId, ...args.data };
                    created.push(args.data);
                    return activeSubscription;
                },
                update: async (args: any) => ({ ...activeSubscription, ...args.data }),
            },
            plan: {
                findFirst: async () => ({
                    id: 'plan-free',
                    code: 'FREE',
                    name: 'Free',
                    isActive: true,
                    amountMinor: 0n,
                    interval: 'MONTH',
                    featureLimits: { mail_supply: 10 },
                }),
            },
            entitlement: {
                createMany: async (args: any) => {
                    createdEntitlements.push(...args.data);
                    return { count: args.data.length };
                },
            },
            user: { findMany: async () => [{ id: 'owner-1' }] },
            notification: {
                createMany: async (args: any) => {
                    notifications.push(args.data);
                    return { count: args.data.length };
                },
            },
            auditLog: {
                create: async (args: any) => {
                    auditRows.push(args.data);
                    return {};
                },
            },
        }),
    } as any);

    // The blocker this fixes: an org with NO subscription record used to get
    // a bare 404 with no admin path forward. Now the grant provisions first.
    const granted = await service.grantUnlimitedAccess(orgId, 'super-admin-1', 'SUPER_ADMIN');

    assert.equal(granted.unlimitedAccess, true);
    assert.equal(granted.provisioned, true);
    assert.equal(created.length, 1);
    assert.equal(created[0].status, 'ACTIVE');
    assert.equal(created[0].unlimitedAccess, true);
    assert.equal(created[0].planId, 'plan-free');
    // Provisioned with the plan's entitlements so revoke lands on real limits.
    assert.deepEqual(createdEntitlements.map((e: any) => e.key), ['mail_supply']);
    assert.equal(createdEntitlements[0].source, 'PLAN');
    // Owners notified + audited as a CREATE (provisioned).
    assert.equal(notifications.length, 1);
    assert.equal(auditRows[0].action, 'CREATE');
    assert.equal(auditRows[0].changes.provisioned, true);
});

test('grantUnlimitedAccess fails honestly when the org is unknown or no plan exists', async () => {
    const missingOrg = new SubscriptionService({
        $transaction: async (cb: any) => cb({
            organization: { findUnique: async () => null },
        }),
    } as any);
    await assert.rejects(
        missingOrg.grantUnlimitedAccess(orgId, 'super-admin-1', 'SUPER_ADMIN'),
        (err) => err instanceof AppError && err.code === 'ORG_NOT_FOUND' && err.status === 404,
    );

    const noPlan = new SubscriptionService({
        $transaction: async (cb: any) => cb({
            organization: { findUnique: async () => ({ id: orgId, name: 'Acme', deletedAt: null }) },
            subscription: { findFirst: async () => null },
            plan: { findFirst: async () => null },
        }),
    } as any);
    await assert.rejects(
        noPlan.grantUnlimitedAccess(orgId, 'super-admin-1', 'SUPER_ADMIN'),
        (err) => err instanceof AppError && err.code === 'PLAN_NOT_FOUND',
    );
});

test('revokeUnlimitedAccess still 404s when there is no active subscription', async () => {
    const service = new SubscriptionService({
        $transaction: async (cb: any) => cb({
            subscription: { findFirst: async () => null },
        }),
    } as any);
    await assert.rejects(
        service.revokeUnlimitedAccess(orgId, 'super-admin-1', 'SUPER_ADMIN'),
        (err) => err instanceof AppError && err.code === 'SUBSCRIPTION_NOT_FOUND' && err.status === 404,
    );
});
