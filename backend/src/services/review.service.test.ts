import assert from 'node:assert/strict';
import test from 'node:test';
import { ReviewService } from './review.service.js';
import { AppError } from '../lib/app-error.js';

const orgId = '11111111-1111-4111-8111-111111111111';
const otherOrgId = '22222222-2222-4222-8222-222222222222';
const userId = '99999999-9999-4999-8999-999999999999';
const adminId = '88888888-8888-4888-8888-888888888888';
const reviewId = '77777777-7777-4777-8777-777777777777';

function makeReviewDb(options: {
    user?: { id: string; orgId: string; deletedAt?: Date | null; isDisabled?: boolean } | null;
    existingReview?: { id: string; status: string } | null;
    reviewRow?: Record<string, unknown>;
    publishedRatings?: number[];
    statusGroups?: Array<{ status: string; _count: { _all: number } }>;
} = {}) {
    const {
        user = { id: userId, orgId, deletedAt: null, isDisabled: false },
        existingReview = null,
        reviewRow = { id: reviewId, publicId: 'PM-REV-000001', status: 'PENDING', userId, orgId, rating: 4, adminResponse: null },
        publishedRatings = [],
        statusGroups = [],
    } = options;

    const state = {
        createdReviews: [] as Array<any>,
        updatedReviews: [] as Array<any>,
        notifications: [] as Array<any>,
        auditRows: [] as Array<any>,
        listWhere: null as Record<string, unknown> | null,
        publishedWhere: null as Record<string, unknown> | null,
    };

    const db = {
        state,
        $transaction: async (fn: (tx: unknown) => Promise<unknown>) => fn(db),
        user: {
            findUnique: async () => user,
        },
        review: {
            findFirst: async () => existingReview,
            findUnique: async (args: { where: { id: string } }) =>
                args.where.id === reviewId ? reviewRow : null,
            findMany: async (args: { where: Record<string, unknown> }) => {
                if (args.where && args.where.status === 'PUBLISHED') {
                    state.publishedWhere = args.where;
                    return publishedRatings.map((rating) => ({ rating }));
                }
                state.listWhere = args.where;
                return [];
            },
            count: async () => 0,
            groupBy: async () => statusGroups,
            create: async (args: { data: Record<string, unknown> }) => {
                state.createdReviews.push(args.data);
                return { id: reviewId, ...args.data };
            },
            update: async (args: { where: { id: string }; data: Record<string, unknown> }) => {
                state.updatedReviews.push(args.data);
                return { ...reviewRow, ...args.data };
            },
        },
        notification: {
            create: async (args: { data: Record<string, unknown> }) => {
                state.notifications.push(args.data);
                return {};
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
// submit
// ---------------------------------------------------------------------------

test('review submit rejects non-integer and out-of-range ratings', async () => {
    const service = new ReviewService(makeReviewDb() as never);
    for (const rating of [0, 6, 4.5, -1]) {
        await assert.rejects(
            service.submit({ userId, orgId, rating, text: 'Great company overall.' }),
            (err) => err instanceof AppError && err.code === 'VALIDATION_ERROR',
        );
    }
});

test('review submit enforces the 5–2000 character text bounds', async () => {
    const service = new ReviewService(makeReviewDb() as never);
    await assert.rejects(
        service.submit({ userId, orgId, rating: 4, text: 'bad' }),
        (err) => err instanceof AppError && err.code === 'VALIDATION_ERROR',
    );
    await assert.rejects(
        service.submit({ userId, orgId, rating: 4, text: 'x'.repeat(2001) }),
        (err) => err instanceof AppError && err.code === 'VALIDATION_ERROR',
    );
});

test('review submit rejects a user who belongs to another organization (tenant isolation)', async () => {
    const service = new ReviewService(
        makeReviewDb({ user: { id: userId, orgId: otherOrgId, deletedAt: null, isDisabled: false } }) as never,
    );
    await assert.rejects(
        service.submit({ userId, orgId, rating: 5, text: 'Great company overall.' }),
        (err) => err instanceof AppError && err.code === 'TENANT_DENIED' && err.status === 403,
    );
});

test('review submit rejects disabled or deleted authors', async () => {
    for (const overrides of [{ isDisabled: true }, { deletedAt: new Date() }]) {
        const service = new ReviewService(
            makeReviewDb({
                user: { id: userId, orgId, deletedAt: null, isDisabled: false, ...overrides },
            }) as never,
        );
        await assert.rejects(
            service.submit({ userId, orgId, rating: 5, text: 'Great company overall.' }),
            (err) => err instanceof AppError && err.code === 'USER_NOT_FOUND',
        );
    }
});

test('review submit rejects a duplicate active review with 409 REVIEW_DUPLICATE', async () => {
    const service = new ReviewService(
        makeReviewDb({ existingReview: { id: 'existing-1', status: 'PENDING' } }) as never,
    );
    await assert.rejects(
        service.submit({ userId, orgId, rating: 4, text: 'Great company overall.' }),
        (err) => err instanceof AppError && err.code === 'REVIEW_DUPLICATE' && err.status === 409,
    );
});

test('review submit creates a PENDING review and an audit row', async () => {
    const db = makeReviewDb();
    const service = new ReviewService(db as never);

    const review = await service.submit({ userId, orgId, rating: 5, text: 'Great company overall.' });

    assert.equal(review.status, 'PENDING');
    assert.equal(db.state.createdReviews.length, 1);
    assert.equal(db.state.createdReviews[0].status, 'PENDING');
    assert.ok(db.state.createdReviews[0].publicId);
    assert.equal(db.state.auditRows.length, 1);
    assert.equal(db.state.auditRows[0].entityType, 'Review');
});

// ---------------------------------------------------------------------------
// public listing + summaries
// ---------------------------------------------------------------------------

test('listPublished only ever queries PUBLISHED reviews', async () => {
    const db = makeReviewDb();
    const service = new ReviewService(db as never);

    await service.listPublished(orgId);

    assert.ok(db.state.publishedWhere);
    assert.equal(db.state.publishedWhere.status, 'PUBLISHED');
    assert.equal(db.state.publishedWhere.orgId, orgId);
});

test('rating summary derives average and distribution from PUBLISHED rows only', async () => {
    const db = makeReviewDb({
        publishedRatings: [5, 4, 4, 1],
        statusGroups: [
            { status: 'PUBLISHED', _count: { _all: 4 } },
            { status: 'PENDING', _count: { _all: 3 } },
            { status: 'HIDDEN', _count: { _all: 2 } },
            { status: 'FLAGGED', _count: { _all: 1 } },
        ],
    });
    const service = new ReviewService(db as never);

    const summary = await service.getRatingSummary();

    assert.equal(summary.total, 10);
    assert.equal(summary.publishedCount, 4);
    assert.equal(summary.pendingCount, 3);
    assert.equal(summary.hiddenCount, 2);
    assert.equal(summary.flaggedCount, 1);
    assert.equal(summary.average, 3.5);
    assert.deepEqual(summary.distribution, { 1: 1, 2: 0, 3: 0, 4: 2, 5: 1 });
});

test('rating summary is honest when nothing is published', async () => {
    const service = new ReviewService(
        makeReviewDb({ statusGroups: [{ status: 'PENDING', _count: { _all: 2 } }] }) as never,
    );
    const summary = await service.getRatingSummary();
    assert.equal(summary.average, 0);
    assert.equal(summary.publishedCount, 0);
    assert.equal(summary.total, 2);
});

// ---------------------------------------------------------------------------
// detail + moderation
// ---------------------------------------------------------------------------

test('getDetail throws REVIEW_NOT_FOUND for an unknown id', async () => {
    const service = new ReviewService(makeReviewDb() as never);
    await assert.rejects(
        service.getDetail('00000000-0000-4000-8000-000000000000'),
        (err) => err instanceof AppError && err.code === 'REVIEW_NOT_FOUND' && err.status === 404,
    );
});

test('moderate PUBLISH transitions status, notifies the submitter and audits', async () => {
    const db = makeReviewDb({ reviewRow: { id: reviewId, publicId: 'PM-REV-000001', status: 'PENDING', userId, orgId, rating: 4, adminResponse: null } });
    const service = new ReviewService(db as never);

    const updated = await service.moderate({ reviewId, adminId, action: 'PUBLISH' });

    assert.equal(updated.status, 'PUBLISHED');
    assert.equal(db.state.updatedReviews[0].status, 'PUBLISHED');
    assert.equal(db.state.updatedReviews[0].moderatedById, adminId);
    assert.equal(db.state.notifications.length, 1);
    assert.equal(db.state.notifications[0].type, 'REVIEW_MODERATION');
    assert.equal(db.state.notifications[0].userId, userId);
    assert.equal(db.state.auditRows.length, 1);
    assert.equal(db.state.auditRows[0].changes.status, 'PUBLISHED');
    assert.equal(db.state.auditRows[0].changes.previousStatus, 'PENDING');
});

test('moderate rejects a redundant transition with 409 REVIEW_STATE_CONFLICT', async () => {
    const service = new ReviewService(
        makeReviewDb({ reviewRow: { id: reviewId, publicId: 'PM-REV-000001', status: 'PUBLISHED', userId, orgId, rating: 4, adminResponse: null } }) as never,
    );
    await assert.rejects(
        service.moderate({ reviewId, adminId, action: 'PUBLISH' }),
        (err) => err instanceof AppError && err.code === 'REVIEW_STATE_CONFLICT' && err.status === 409,
    );
});

test('moderate RESPOND requires a non-empty response', async () => {
    const service = new ReviewService(makeReviewDb() as never);
    await assert.rejects(
        service.moderate({ reviewId, adminId, action: 'RESPOND' }),
        (err) => err instanceof AppError && err.code === 'VALIDATION_ERROR',
    );
});

test('moderate RESPOND stores the admin response and notifies the submitter', async () => {
    const db = makeReviewDb({ reviewRow: { id: reviewId, publicId: 'PM-REV-000001', status: 'PUBLISHED', userId, orgId, rating: 4, adminResponse: null } });
    const service = new ReviewService(db as never);

    await service.moderate({ reviewId, adminId, action: 'RESPOND', response: 'Thank you for the feedback.' });

    assert.equal(db.state.updatedReviews[0].adminResponse, 'Thank you for the feedback.');
    // RESPOND never changes the moderation status.
    assert.equal(db.state.updatedReviews[0].status, 'PUBLISHED');
    assert.equal(db.state.notifications.length, 1);
    assert.ok(String(db.state.notifications[0].body).includes('Thank you'));
});
