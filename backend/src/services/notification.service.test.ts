import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { NotificationService } from './notification.service.js';
import { AppError } from '../lib/app-error.js';
import type { prisma } from '../lib/prisma.js';

// Minimal fake of the Prisma client surface the service touches. Each method
// records its args so tests assert tenant/user scoping and read-state guards.
function makeDb(overrides: {
    findMany?: unknown[];
    count?: number;
    unread?: number;
    findFirst?: unknown;
    updateMany?: { count: number };
    create?: unknown;
} = {}) {
    const calls: Record<string, any> = {};
    const delegate = {
        findMany: async (args: any) => { calls.findMany = args; return overrides.findMany ?? []; },
        count: async (args: any) => {
            calls.count = args;
            // The service calls count twice: once for the page total, once for
            // the unread badge (which adds readAt: null).
            return args.where.readAt === null ? (overrides.unread ?? 0) : (overrides.count ?? 0);
        },
        findFirst: async (args: any) => { calls.findFirst = args; return overrides.findFirst ?? null; },
        updateMany: async (args: any) => { calls.updateMany = args; return overrides.updateMany ?? { count: 0 }; },
        create: async (args: any) => { calls.create = args; return overrides.create ?? {}; },
    };
    const tx = {
        ...delegate,
        notification: delegate,
        auditLog: { create: async (args: any) => { calls.auditCreate = args; return {}; } },
    };
    const db = {
        notification: delegate,
        auditLog: { create: async (args: any) => { calls.auditCreate = args; return {}; } },
        $transaction: async (fn: (tx: any) => unknown) => fn(tx),
    };
    return { db: db as unknown as typeof prisma, calls };
}

describe('NotificationService', () => {
    test('listForUser scopes to the user AND org, and reports the unread badge count', async () => {
        const { db, calls } = makeDb({ findMany: [{ id: 'n1' }], count: 1, unread: 3 });
        const service = new NotificationService(db);

        const result = await service.listForUser('user-1', 'org-1', { page: 1, limit: 50, unreadOnly: false });

        assert.equal(calls.findMany.where.userId, 'user-1');
        assert.equal(calls.findMany.where.orgId, 'org-1');
        assert.equal(calls.findMany.where.deletedAt, null);
        // The badge count is always over ALL notifications, never the unreadOnly filter.
        assert.equal(calls.count.where.readAt, null);
        assert.deepEqual(result.notifications, [{ id: 'n1' }]);
        assert.equal(result.total, 1);
        assert.equal(result.unread, 3);
    });

    test('listForUser with unreadOnly only filters the page, not the badge count', async () => {
        const { db, calls } = makeDb({ count: 7 });
        const service = new NotificationService(db);

        await service.listForUser('user-1', 'org-1', { page: 2, limit: 10, unreadOnly: true });

        assert.equal(calls.findMany.where.readAt, null);
        assert.equal(calls.findMany.skip, 10);
        assert.equal(calls.findMany.take, 10);
        // badge count has no readAt filter of its own beyond unread
        assert.equal(calls.count.where.readAt, null);
    });

    test('markRead rejects with 404 when the notification belongs to someone else', async () => {
        const { db, calls } = makeDb({ findFirst: null });
        const service = new NotificationService(db);

        await assert.rejects(
            () => service.markRead('user-1', 'org-1', 'n-1'),
            (error: unknown) => {
                assert.ok(error instanceof AppError);
                assert.equal(error.code, 'NOTIFICATION_NOT_FOUND');
                assert.equal(error.status, 404);
                return true;
            },
        );
        // The lookup was scoped to user AND org — cross-tenant or cross-user ids
        // are indistinguishable from missing ones.
        assert.equal(calls.findFirst.where.userId, 'user-1');
        assert.equal(calls.findFirst.where.orgId, 'org-1');
    });

    test('markRead is idempotent for an already-read notification', async () => {
        const readAt = new Date('2026-01-01T00:00:00Z');
        const { db, calls } = makeDb({ findFirst: { id: 'n1', readAt } });
        const service = new NotificationService(db);

        const result = await service.markRead('user-1', 'org-1', 'n1');

        assert.equal(result.changed, false);
        assert.equal(result.readAt, readAt);
        // No write happened.
        assert.equal(calls.updateMany, undefined);
    });

    test('markRead transitions an unread notification and writes an audit row', async () => {
        const { db, calls } = makeDb({ findFirst: { id: 'n1', readAt: null }, updateMany: { count: 1 } });
        const service = new NotificationService(db);

        const result = await service.markRead('user-1', 'org-1', 'n1');

        assert.equal(result.changed, true);
        // The guarded update can only match a still-unread row.
        assert.equal(calls.updateMany.where.readAt, null);
        assert.equal(calls.updateMany.where.userId, 'user-1');
        assert.ok(calls.updateMany.data.readAt instanceof Date);
        assert.equal(calls.auditCreate.data.entityType, 'Notification');
        assert.equal(calls.auditCreate.data.orgId, 'org-1');
    });

    test('markRead surfaces a conflict when the guarded transition loses the race', async () => {
        const { db } = makeDb({
            findFirst: { id: 'n1', readAt: null },
            updateMany: { count: 0 },
        });
        const service = new NotificationService(db);

        await assert.rejects(
            () => service.markRead('user-1', 'org-1', 'n1'),
            (error: unknown) => {
                assert.ok(error instanceof AppError);
                assert.equal(error.code, 'NOTIFICATION_READ_CONFLICT');
                assert.equal(error.status, 409);
                return true;
            },
        );
    });

    test('markAllRead updates every unread row scoped to user and org', async () => {
        const { db, calls } = makeDb({ updateMany: { count: 5 } });
        const service = new NotificationService(db);

        const result = await service.markAllRead('user-1', 'org-1');

        assert.equal(result.updated, 5);
        assert.equal(calls.updateMany.where.userId, 'user-1');
        assert.equal(calls.updateMany.where.orgId, 'org-1');
        assert.equal(calls.updateMany.where.readAt, null);
        assert.equal(calls.auditCreate.data.changes.readAll, true);
        assert.equal(calls.auditCreate.data.changes.count, 5);
    });

    test('markAllRead with nothing unread writes no audit row', async () => {
        const { db, calls } = makeDb({ updateMany: { count: 0 } });
        const service = new NotificationService(db);

        const result = await service.markAllRead('user-1', 'org-1');

        assert.equal(result.updated, 0);
        assert.equal(calls.auditCreate, undefined);
    });
});
