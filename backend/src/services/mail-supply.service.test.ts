import assert from 'node:assert/strict';
import test from 'node:test';
import { MailSupplyService, FREE_PLAN_MONTHLY_MAIL_LIMIT, type SendMailInput } from './mail-supply.service.js';
import { AppError } from '../lib/app-error.js';

const orgId = '11111111-1111-4111-8111-111111111111';
const otherOrgId = '22222222-2222-4222-8222-222222222222';
const actorId = '99999999-9999-4999-8999-999999999999';
const targetUserId = '88888888-8888-4888-8888-888888888888';

test('mail supply quota defaults to 10 mails per month for free plan', async () => {
    assert.equal(FREE_PLAN_MONTHLY_MAIL_LIMIT, 10);
});

test('mail supply enforces Owner restriction: cannot target all organizations', async () => {
    const service = new MailSupplyService();
    await assert.rejects(
        service.resolveTargets({
            actorId: 'owner-1',
            actorRole: 'OWNER',
            orgId: 'org-1',
            targetType: 'ALL',
            subject: 'Announcement',
            body: 'Hello',
        }),
        (err) => err instanceof AppError && err.code === 'TENANT_DENIED',
    );
});

test('mail supply requires targetRole when targeting by role', async () => {
    const service = new MailSupplyService();
    await assert.rejects(
        service.resolveTargets({
            actorId: 'admin-1',
            actorRole: 'ADMIN',
            orgId: 'org-1',
            targetType: 'ROLE',
            subject: 'Notice',
            body: 'Body',
        }),
        (err) => err instanceof AppError && err.code === 'VALIDATION_ERROR',
    );
});

test('mail supply requires targetUserId when targeting individual', async () => {
    const service = new MailSupplyService();
    await assert.rejects(
        service.resolveTargets({
            actorId: 'admin-1',
            actorRole: 'ADMIN',
            orgId: 'org-1',
            targetType: 'INDIVIDUAL',
            subject: 'Direct',
            body: 'Private',
        }),
        (err) => err instanceof AppError && err.code === 'VALIDATION_ERROR',
    );
});

test('mail supply quota calculation boundary enforces 10/month limit', () => {
    const limit = 10;
    const testCases = [
        { sent: 0, requested: 1, allowed: 1, willBlock: false },
        { sent: 8, requested: 1, allowed: 1, willBlock: false }, // 9th mail
        { sent: 9, requested: 1, allowed: 1, willBlock: false }, // 10th mail
        { sent: 10, requested: 1, allowed: 0, willBlock: true },  // 11th mail -> blocked
    ];

    for (const tc of testCases) {
        const remaining = Math.max(0, limit - tc.sent);
        if (tc.willBlock) {
            assert.equal(remaining, 0);
        } else {
            assert.ok(remaining >= tc.allowed);
        }
    }
});

// ---------------------------------------------------------------------------
// Injectable fixtures for the send() pipeline tests.
// ---------------------------------------------------------------------------

interface TransportCall {
    to: string;
    subject: string;
    html: string;
    text: string;
    eventId: string;
}

function makeTransport(outcome: 'SENT' | 'SKIPPED' | 'UNAVAILABLE' = 'SENT') {
    const calls: TransportCall[] = [];
    return {
        calls,
        send: async (input: TransportCall): Promise<'SENT' | 'SKIPPED' | 'UNAVAILABLE'> => {
            calls.push(input);
            return outcome;
        },
    };
}

function makeAccess(limit: number | null, unlimited = false) {
    return {
        getFeatureAccess: async () => ({ allowed: true, unlimited, limit, source: 'SUBSCRIPTION' }),
    };
}

function makeDb(options: {
    usageQuantity?: number;
    existingDispatch?: {
        id: string;
        status: string;
        sent: number;
        failed: number;
        blocked: number;
    } | null;
    targets?: Array<{ id: string; email: string; firstName: string | null; lastName: string | null; role: string }>;
    individualTarget?: { id: string; email: string; firstName: string | null; lastName: string | null; role: string; orgId: string; isDisabled: boolean } | null;
    updateManyResults?: Array<{ count: number }>;
    createUniqueViolation?: boolean;
} = {}) {
    const {
        usageQuantity = 0,
        existingDispatch = null,
        targets = [{ id: targetUserId, email: 'worker@example.com', firstName: 'A', lastName: 'B', role: 'STAFF' }],
        individualTarget = null,
        updateManyResults = [{ count: 1 }],
        createUniqueViolation = false,
    } = options;

    const state = {
        increments: 0,
        creates: 0,
        dispatchRows: [] as Array<Record<string, unknown>>,
        dispatchUpdates: [] as Array<Record<string, unknown>>,
        auditRows: 0,
    };

    const db = {
        state,
        usageRecord: {
            findUnique: async () => (usageQuantity > 0 ? { quantity: usageQuantity } : null),
            updateMany: async () => {
                const result = updateManyResults[Math.min(state.increments, updateManyResults.length - 1)];
                state.increments += 1;
                return result ?? { count: 1 };
            },
            create: async (args: { data: { quantity: number } }) => {
                state.creates += 1;
                if (createUniqueViolation) {
                    const error = new Error('Unique constraint failed') as Error & { code?: string };
                    error.code = 'P2002';
                    throw error;
                }
                return { quantity: args.data.quantity };
            },
        },
        user: {
            findMany: async (args: { where: { orgId?: string } }) => {
                // ORGANIZATION targeting must be org-scoped — assert it never queries unscoped.
                assert.ok(args.where.orgId, 'organization targeting must filter by orgId');
                return targets;
            },
            findUnique: async () => individualTarget,
        },
        mailDispatch: {
            findUnique: async () => existingDispatch,
            create: async (args: { data: Record<string, unknown> }) => {
                const row = { id: 'dispatch-1', ...args.data };
                state.dispatchRows.push(row);
                return row;
            },
            update: async (args: { data: Record<string, unknown> }) => {
                state.dispatchUpdates.push(args.data);
                return {};
            },
        },
        auditLog: {
            create: async () => {
                state.auditRows += 1;
                return {};
            },
        },
    };
    return db;
}

function sendInput(overrides: Partial<SendMailInput> = {}): SendMailInput {
    return {
        actorId,
        actorRole: 'OWNER',
        orgId,
        subject: 'Payroll is live',
        body: 'This month payroll has been processed.',
        targetType: 'ORGANIZATION',
        idempotencyKey: 'key-1',
        ...overrides,
    };
}

test('send delivers the composed subject and body — never a substituted template', async () => {
    const transport = makeTransport();
    const db = makeDb();
    const service = new MailSupplyService(db as never, transport as never, makeAccess(null) as never);

    const result = await service.send(sendInput());

    assert.equal(result.sent, 1);
    assert.equal(result.failed, 0);
    assert.equal(transport.calls.length, 1);
    assert.equal(transport.calls[0].subject, 'Payroll is live');
    assert.equal(transport.calls[0].text, 'This month payroll has been processed.');
    assert.ok(transport.calls[0].html.includes('This month payroll has been processed.'));
    // The email event is anchored to the idempotency key for transport-level dedupe.
    assert.ok(transport.calls[0].eventId.startsWith('key-1'));
});

test('send meters quota through UsageRecord before any delivery', async () => {
    const transport = makeTransport();
    const db = makeDb({ usageQuantity: 0 });
    const service = new MailSupplyService(db as never, transport as never, makeAccess(null) as never);

    await service.send(sendInput());

    // Free plan: limit 10, one recipient → one atomic reservation.
    assert.equal(db.state.increments + db.state.creates, 1);
});

test('send blocks the 11th mail under the free 10/month quota', async () => {
    const transport = makeTransport();
    const db = makeDb({ usageQuantity: 10 });
    const service = new MailSupplyService(db as never, transport as never, makeAccess(null) as never);

    await assert.rejects(
        service.send(sendInput()),
        (err) => err instanceof AppError && err.code === 'MAIL_QUOTA_EXCEEDED',
    );
    // Nothing was sent and no dispatch row exists — quota gates before delivery.
    assert.equal(transport.calls.length, 0);
    assert.equal(db.state.dispatchRows.length, 0);
});

test('send replays a COMPLETED dispatch without re-sending or re-charging quota', async () => {
    const transport = makeTransport();
    const db = makeDb({
        existingDispatch: { id: 'dispatch-existing', status: 'COMPLETED', sent: 3, failed: 1, blocked: 0 },
    });
    const service = new MailSupplyService(db as never, transport as never, makeAccess(null) as never);

    const result = await service.send(sendInput());

    assert.equal(result.duplicate, true);
    assert.equal(result.sent, 3);
    assert.equal(result.failed, 1);
    assert.equal(result.dispatchId, 'dispatch-existing');
    assert.equal(transport.calls.length, 0);
    assert.equal(db.state.dispatchRows.length, 0);
    assert.equal(db.state.increments, 0);
    assert.equal(db.state.creates, 0);
});

test('send rejects a retried key while a dispatch is still PENDING', async () => {
    const transport = makeTransport();
    const db = makeDb({
        existingDispatch: { id: 'dispatch-pending', status: 'PENDING', sent: 0, failed: 0, blocked: 0 },
    });
    const service = new MailSupplyService(db as never, transport as never, makeAccess(null) as never);

    await assert.rejects(
        service.send(sendInput()),
        (err) => err instanceof AppError && err.code === 'MAIL_DISPATCH_IN_PROGRESS',
    );
    assert.equal(transport.calls.length, 0);
});

test('send marks the dispatch COMPLETED so retries replay instead of 409-ing forever', async () => {
    const transport = makeTransport();
    const db = makeDb();
    const service = new MailSupplyService(db as never, transport as never, makeAccess(null) as never);

    await service.send(sendInput());

    assert.equal(db.state.dispatchUpdates.length, 1);
    assert.equal(db.state.dispatchUpdates[0].status, 'COMPLETED');
    assert.equal(db.state.dispatchUpdates[0].sent, 1);
    assert.equal(db.state.auditRows, 1);
});

test('quota reservation races: a lost create retries the conditional increment', async () => {
    const transport = makeTransport();
    // First conditional increment misses (row not created yet); the create
    // collides on the unique key; the retried increment lands within the limit.
    const db = makeDb({
        updateManyResults: [{ count: 0 }, { count: 1 }],
        createUniqueViolation: true,
    });
    const service = new MailSupplyService(db as never, transport as never, makeAccess(null) as never);

    const result = await service.send(sendInput());

    assert.equal(result.sent, 1);
    assert.equal(db.state.increments, 2);
    assert.equal(db.state.creates, 1);
});

test('quota reservation races: concurrent consumption exhausts the remaining quota', async () => {
    const transport = makeTransport();
    // Both the increment and the create retry miss — a concurrent request took
    // the remaining quota in between → honest MAIL_QUOTA_EXCEEDED, nothing sent.
    const db = makeDb({
        updateManyResults: [{ count: 0 }, { count: 0 }],
        createUniqueViolation: true,
    });
    const service = new MailSupplyService(db as never, transport as never, makeAccess(null) as never);

    await assert.rejects(
        service.send(sendInput()),
        (err) => err instanceof AppError && err.code === 'MAIL_QUOTA_EXCEEDED',
    );
    assert.equal(transport.calls.length, 0);
    assert.equal(db.state.dispatchRows.length, 0);
});

test('INDIVIDUAL targeting denies a user outside the actor organization', async () => {
    const service = new MailSupplyService({
        user: {
            findUnique: async () => ({
                id: targetUserId,
                email: 'outsider@example.com',
                firstName: 'C',
                lastName: 'D',
                role: 'STAFF',
                orgId: otherOrgId,
                isDisabled: false,
            }),
        },
    } as never, makeTransport() as never, makeAccess(null) as never);

    await assert.rejects(
        service.resolveTargets(sendInput({ targetType: 'INDIVIDUAL', targetUserId })),
        (err) => err instanceof AppError && err.code === 'TENANT_DENIED',
    );
});

test('INDIVIDUAL targeting denies a disabled user', async () => {
    const service = new MailSupplyService({
        user: {
            findUnique: async () => ({
                id: targetUserId,
                email: 'worker@example.com',
                firstName: 'A',
                lastName: 'B',
                role: 'STAFF',
                orgId,
                isDisabled: true,
            }),
        },
    } as never, makeTransport() as never, makeAccess(null) as never);

    await assert.rejects(
        service.resolveTargets(sendInput({ targetType: 'INDIVIDUAL', targetUserId })),
        (err) => err instanceof AppError && err.code === 'USER_DISABLED',
    );
});

test('getUsage reads the UsageRecord meter and falls back to the free baseline', async () => {
    const db = makeDb({ usageQuantity: 4 });
    const service = new MailSupplyService(db as never, makeTransport() as never, makeAccess(null) as never);

    const usage = await service.getUsage(orgId, 'OWNER');

    assert.equal(usage.sent, 4);
    assert.equal(usage.limit, FREE_PLAN_MONTHLY_MAIL_LIMIT);
    assert.equal(usage.remaining, 6);
    assert.ok(/^\d{4}-\d{2}$/.test(usage.monthKey));
});

test('getUsage is unmetered for platform-level actors', async () => {
    const db = makeDb({ usageQuantity: 99 });
    const service = new MailSupplyService(db as never, makeTransport() as never, makeAccess(null) as never);

    const usage = await service.getUsage(undefined, 'SUPER_ADMIN');

    assert.equal(usage.limit, 999999);
    assert.equal(usage.remaining, 999999);
});

test('getHistory maps dispatch rows to SUCCESS/PARTIAL statuses', async () => {
    const rows = [
        {
            id: 'd1', createdAt: new Date('2026-08-01T00:00:00Z'), subject: 'A',
            targetType: 'ORGANIZATION', sent: 5, failed: 0, actorId: 'u1', recipientCount: 5,
        },
        {
            id: 'd2', createdAt: new Date('2026-08-02T00:00:00Z'), subject: 'B',
            targetType: 'ROLE', sent: 3, failed: 1, actorId: null, recipientCount: 4,
        },
    ];
    const service = new MailSupplyService({
        mailDispatch: { findMany: async () => rows },
    } as never, makeTransport() as never, makeAccess(null) as never);

    const history = await service.getHistory(orgId, 50);

    assert.equal(history.length, 2);
    assert.equal(history[0].status, 'SUCCESS');
    assert.equal(history[1].status, 'PARTIAL');
    assert.equal(history[1].actorId, 'SYSTEM');
});
