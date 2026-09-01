import assert from 'node:assert/strict';
import test from 'node:test';
import { AdminOpsService } from './admin-ops.service.js';

const orgId = '11111111-1111-4111-8111-111111111111';

function makeOpsDb(options: {
    paymentEvents?: Array<Record<string, unknown>>;
    paymentTotal?: number;
    paymentGroups?: Array<{ status: string; _count: { _all: number } }>;
    paymentEvent?: Record<string, unknown> | null;
    invoices?: Array<Record<string, unknown>>;
    monthUsage?: Array<{ orgId: string; quantity: unknown }>;
    dispatches?: Array<Record<string, unknown>>;
} = {}) {
    const {
        paymentEvents = [],
        paymentTotal = 0,
        paymentGroups = [],
        paymentEvent = null,
        invoices = [],
        monthUsage = [],
        dispatches = [],
    } = options;

    const state = {
        paymentWhere: null as Record<string, unknown> | null,
        usageWhere: null as Record<string, unknown> | null,
    };

    const db = {
        state,
        paymentEvent: {
            findMany: async (args: { where: Record<string, unknown> }) => {
                state.paymentWhere = args.where;
                return paymentEvents;
            },
            count: async () => paymentTotal,
            groupBy: async () => paymentGroups,
            findUnique: async () => paymentEvent,
        },
        invoice: {
            findMany: async () => invoices,
        },
        mailDispatch: {
            findMany: async () => dispatches,
            count: async () => dispatches.length,
            aggregate: async (args: { _sum: Record<string, unknown> }) => {
                const field = Object.keys(args._sum)[0];
                const sum = dispatches.reduce(
                    (s, d) => s + Number(d[field] ?? 0),
                    0,
                );
                return { _sum: { [field]: sum } };
            },
        },
        organization: {
            count: async () => 3,
            findMany: async () => [],
        },
        user: {
            count: async () => 12,
            findMany: async () => [],
        },
        usageRecord: {
            findMany: async (args: { where: Record<string, unknown> }) => {
                state.usageWhere = args.where;
                return monthUsage;
            },
        },
        announcementCampaign: {
            findMany: async () => [],
            count: async () => 0,
        },
        notification: {
            groupBy: async () => [],
        },
        subscription: {
            findMany: async () => [],
        },
        review: {
            findMany: async () => [],
        },
        auditLog: {
            findMany: async () => [],
        },
        attendanceRecord: {
            findMany: async () => [],
        },
    };
    return db;
}

// ---------------------------------------------------------------------------
// listPayments
// ---------------------------------------------------------------------------

test('listPayments passes status/provider filters into the where clause', async () => {
    const db = makeOpsDb();
    const service = new AdminOpsService(db as never);

    const result = await service.listPayments({ status: 'FAILED', provider: 'razorpay' });

    assert.equal(db.state.paymentWhere!.status, 'FAILED');
    assert.equal(db.state.paymentWhere!.provider, 'razorpay');
    assert.equal(result.totalPages, 1);
});

test('listPayments treats ALL as no filter and derives the byStatus summary', async () => {
    const db = makeOpsDb({
        paymentTotal: 7,
        paymentGroups: [
            { status: 'RECEIVED', _count: { _all: 4 } },
            { status: 'FAILED', _count: { _all: 3 } },
        ],
    });
    const service = new AdminOpsService(db as never);

    const result = await service.listPayments({ status: 'ALL' });

    assert.equal(db.state.paymentWhere!.status, undefined);
    assert.equal(result.total, 7);
    assert.deepEqual(result.summary.byStatus, { RECEIVED: 4, FAILED: 3 });
});

test('listPayments builds a search OR across reference, event type and org', async () => {
    const db = makeOpsDb();
    const service = new AdminOpsService(db as never);

    await service.listPayments({ search: 'PM-CMP-000001' });

    const orClauses = db.state.paymentWhere!.OR as Array<Record<string, unknown>>;
    assert.ok(orClauses.length >= 4);
    assert.ok(orClauses.some((c) => 'providerEventId' in c));
    assert.ok(orClauses.some((c) => 'org' in c));
});

// ---------------------------------------------------------------------------
// getPaymentDetail
// ---------------------------------------------------------------------------

test('getPaymentDetail returns null for an unknown payment', async () => {
    const service = new AdminOpsService(makeOpsDb() as never);
    assert.equal(await service.getPaymentDetail('missing'), null);
});

test('getPaymentDetail returns the event with related invoices', async () => {
    const db = makeOpsDb({
        paymentEvent: { id: 'pay-1', orgId, subscriptionId: 'sub-1', status: 'PROCESSED' },
        invoices: [{ id: 'inv-1', orgId, subscriptionId: 'sub-1' }],
    });
    const service = new AdminOpsService(db as never);

    const detail = await service.getPaymentDetail('pay-1');

    assert.equal(detail!.event.id, 'pay-1');
    assert.equal(detail!.invoices.length, 1);
});

// ---------------------------------------------------------------------------
// getMailOverview
// ---------------------------------------------------------------------------

test('getMailOverview sums real monthly usage rows and counts orgs mailing', async () => {
    const db = makeOpsDb({
        monthUsage: [
            { orgId, quantity: 6 },
            { orgId: '22222222-2222-4222-8222-222222222222', quantity: 4 },
        ],
        dispatches: [{ sent: 5, failed: 1 }, { sent: 2, failed: 0 }],
    });
    const service = new AdminOpsService(db as never);

    const overview = await service.getMailOverview();

    assert.equal(overview.summary.mailSentThisMonth, 10);
    assert.equal(overview.summary.orgsUsingMail, 2);
    assert.equal(overview.summary.totalSent, 7);
    assert.equal(overview.summary.totalFailed, 1);
    assert.equal(overview.summary.orgCount, 3);
    assert.equal(overview.summary.userCount, 12);
    assert.equal(overview.quota.freePlanMonthlyLimit, 10);
    // Monthly usage is scoped to the current month window, never all-time.
    assert.equal(db.state.usageWhere!.metric, 'mail_supply');
    assert.ok(db.state.usageWhere!.periodStart);
    assert.ok(db.state.usageWhere!.periodEnd);
});

// ---------------------------------------------------------------------------
// getReportsOverview
// ---------------------------------------------------------------------------

test('getReportsOverview buckets rows into 30 daily buckets per metric', async () => {
    const now = new Date();
    const twoDaysAgo = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - 2, 12));

    const db = makeOpsDb();
    const rows: Array<Record<string, unknown>> = [];
    // service calls findMany per entity; route each by shape is fragile, so
    // intercept via review/auditLog/attendanceRecord/etc. all returning rows
    // for their own metric is not possible with one shared stub. Instead we
    // stub each entity's findMany to return its own rows.
    (db.user as any).findMany = async () => [{ createdAt: twoDaysAgo }];
    (db.organization as any).findMany = async () => [{ createdAt: twoDaysAgo }];
    (db.subscription as any).findMany = async () => [{ createdAt: twoDaysAgo, status: 'ACTIVE' }];
    (db.paymentEvent as any).findMany = async () => [{ createdAt: twoDaysAgo, status: 'RECEIVED' }];
    (db.mailDispatch as any).findMany = async () => [{ createdAt: twoDaysAgo, sent: 2, failed: 0 }];
    (db.auditLog as any).findMany = async () => [{ createdAt: twoDaysAgo }];
    (db.review as any).findMany = async () => [{ createdAt: twoDaysAgo, status: 'PENDING' }];
    (db.attendanceRecord as any).findMany = async () => [{ createdAt: twoDaysAgo }];

    const service = new AdminOpsService(db as never);
    const report = await service.getReportsOverview();

    assert.equal(report.window.days, 30);
    assert.equal(Object.keys(report.series.users).length, 30);
    const expectedDay = twoDaysAgo.toISOString().slice(0, 10);
    assert.equal(report.series.users[expectedDay], 1);
    assert.equal(report.series.companies[expectedDay], 1);
    assert.equal(report.series.subscriptions[expectedDay], 1);
    assert.equal(report.series.payments[expectedDay], 1);
    assert.equal(report.series.mail[expectedDay], 1);
    assert.equal(report.series.auditEvents[expectedDay], 1);
    assert.equal(report.series.reviews[expectedDay], 1);
    assert.equal(report.series.attendance[expectedDay], 1);
    assert.equal(report.totals.users, 1);
    assert.equal(report.totals.mailSent, 2);
});

test('getReportsOverview returns honest zeros for an empty platform', async () => {
    const service = new AdminOpsService(makeOpsDb() as never);
    const report = await service.getReportsOverview();

    assert.equal(report.totals.users, 0);
    assert.equal(report.totals.companies, 0);
    assert.equal(report.totals.mailSent, 0);
    // Every one of the 30 buckets exists and is zero — no gaps, no fabrication.
    for (const day of Object.keys(report.series.users)) {
        assert.equal(report.series.users[day] ?? 0, 0);
    }
    assert.equal(Object.keys(report.series.users).length, 30);
});
