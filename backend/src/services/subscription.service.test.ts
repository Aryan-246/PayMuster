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

test('global subscription switch OFF grants unrestricted access without reading database', async () => {
    SubscriptionService.setGlobalSubscriptionSwitch(false);
    try {
        const service = new SubscriptionService({
            subscription: {
                findFirst: async () => {
                    assert.fail('Database must not be read when global switch is OFF');
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
    } finally {
        SubscriptionService.setGlobalSubscriptionSwitch(true);
    }
});

test('Super Admin can grant and revoke unlimited access with audit trail', async () => {
    let unlimitedState = false;
    const service = new SubscriptionService({
        $transaction: async (cb: any) => cb({
            subscription: {
                findFirst: async () => ({ id: subscriptionId, orgId, unlimitedAccess: unlimitedState }),
                update: async (args: any) => {
                    unlimitedState = args.data.unlimitedAccess;
                    return { id: subscriptionId, ...args.data };
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
    assert.equal(unlimitedState, true);

    // Super Admin revokes unlimited access
    const revoked = await service.revokeUnlimitedAccess(orgId, 'super-admin-1', 'SUPER_ADMIN');
    assert.equal(revoked.unlimitedAccess, false);
    assert.equal(unlimitedState, false);
});
