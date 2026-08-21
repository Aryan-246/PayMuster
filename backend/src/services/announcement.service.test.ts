import assert from 'node:assert/strict';
import test, { afterEach } from 'node:test';

import { AppError } from '../lib/app-error.js';
import { prisma } from '../lib/prisma.js';
import { AnnouncementService } from './announcement.service.js';

const mutablePrisma = prisma as unknown as {
    $transaction: typeof prisma.$transaction;
};
const notificationDelegate = prisma.notification as unknown as {
    findMany: typeof prisma.notification.findMany;
    count: typeof prisma.notification.count;
};

const originalTransaction = mutablePrisma.$transaction;
const originalFindMany = notificationDelegate.findMany;
const originalCount = notificationDelegate.count;

const actorId = '11111111-1111-4111-8111-111111111111';
const organizationId = '22222222-2222-4222-8222-222222222222';
const recipientId = '33333333-3333-4333-8333-333333333333';
const secondRecipientId = '44444444-4444-4444-8444-444444444444';
const announcementId = '55555555-5555-4555-8555-555555555555';

function assertAppError(
    error: unknown,
    expected: { code: string; status: number },
): boolean {
    assert.ok(error instanceof AppError);
    assert.equal(error.code, expected.code);
    assert.equal(error.status, expected.status);
    return true;
}

afterEach(() => {
    mutablePrisma.$transaction = originalTransaction;
    notificationDelegate.findMany = originalFindMany;
    notificationDelegate.count = originalCount;
});

test('role dispatch scopes recipients to the organization and role', async () => {
    const calls: Array<{ operation: string; args: any }> = [];
    const transactionClient = {
        organization: { findFirst: async () => ({ id: organizationId }) },
        user: {
            findMany: async (args: unknown) => {
                calls.push({ operation: 'user.findMany', args });
                return [{ id: recipientId, orgId: organizationId }];
            },
        },
        announcementCampaign: { create: async (args: unknown) => { calls.push({ operation: 'campaign.create', args }); return {}; } },
        notification: { createMany: async (args: unknown) => { calls.push({ operation: 'notification.createMany', args }); return { count: 1 }; } },
        auditLog: { create: async (args: unknown) => { calls.push({ operation: 'auditLog.create', args }); return {}; } },
    };
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) => callback(transactionClient)) as any;

    const result = await new AnnouncementService().dispatch(actorId, {
        audience: 'ROLE',
        type: 'WARNING',
        orgId: organizationId,
        audienceRole: 'STAFF',
        title: 'Role notice',
        body: 'Staff-only notice',
    });

    assert.equal(result.recipientCount, 1);
    const query = calls.find((call) => call.operation === 'user.findMany')!.args;
    assert.deepEqual(query.where, {
        orgId: organizationId,
        role: 'STAFF',
        deletedAt: null,
        isActive: true,
        isDisabled: false,
        status: { in: ['PENDING', 'VERIFIED'] },
    });
});

test('user dispatch validates an active target and delivers only to that user', async () => {
    const calls: Array<{ operation: string; args: any }> = [];
    const transactionClient = {
        user: {
            findFirst: async () => ({ id: recipientId, orgId: organizationId }),
            findMany: async (args: unknown) => { calls.push({ operation: 'user.findMany', args }); return [{ id: recipientId, orgId: organizationId }]; },
        },
        announcementCampaign: { create: async () => ({}) },
        notification: { createMany: async (args: unknown) => { calls.push({ operation: 'notification.createMany', args }); return { count: 1 }; } },
        auditLog: { create: async () => ({}) },
    };
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) => callback(transactionClient)) as any;

    const result = await new AnnouncementService().dispatch(actorId, {
        audience: 'USER',
        type: 'EMERGENCY',
        audienceUserId: recipientId,
        title: 'Direct notice',
        body: 'Direct user notice',
    });

    assert.equal(result.recipientCount, 1);
    const query = calls.find((call) => call.operation === 'user.findMany')!.args;
    assert.equal(query.where.id, recipientId);
});

test('system dispatch selects only eligible users and commits recipient notifications before campaign audit', async () => {
    const calls: Array<{ operation: string; args: unknown }> = [];
    const transactionClient = {
        organization: {
            findFirst: async () => {
                assert.fail('system dispatch must not resolve an organization');
            },
        },
        user: {
            findMany: async (args: unknown) => {
                calls.push({ operation: 'user.findMany', args });
                return [
                    { id: recipientId, orgId: organizationId },
                    { id: secondRecipientId, orgId: null },
                ];
            },
        },
        announcementCampaign: {
            create: async (args: unknown) => {
                calls.push({ operation: 'announcementCampaign.create', args });
                return {};
            },
        },
        notification: {
            createMany: async (args: unknown) => {
                calls.push({ operation: 'notification.createMany', args });
                return { count: 2 };
            },
        },
        auditLog: {
            create: async (args: unknown) => {
                calls.push({ operation: 'auditLog.create', args });
                return {};
            },
        },
    };
    mutablePrisma.$transaction = (async (
        callback: (tx: typeof transactionClient) => unknown,
    ) => callback(transactionClient)) as unknown as typeof prisma.$transaction;

    const result = await new AnnouncementService().dispatch(
        actorId,
        {
            audience: 'SYSTEM',
            type: 'INFORMATION',
            title: 'Service notice',
            body: 'Payroll will be briefly unavailable.',
            deepLink: '/app/notices',
        },
        {
            requestId: 'request-123',
            ipAddress: '203.0.113.10',
            userAgent: 'PayMuster-Test/1.0',
        },
    );

    assert.deepEqual(calls.map((call) => call.operation), [
        'user.findMany',
        'announcementCampaign.create',
        'notification.createMany',
        'auditLog.create',
    ]);
    assert.equal(result.recipientCount, 2);
    assert.deepEqual(result.recipientIds, [recipientId, secondRecipientId]);
    assert.equal(result.orgId, null);

    const recipientQuery = calls[0].args as {
        where: Record<string, unknown>;
        select: Record<string, boolean>;
        orderBy: Record<string, string>;
    };
    assert.equal('orgId' in recipientQuery.where, false);
    assert.equal(recipientQuery.where.deletedAt, null);
    assert.equal(recipientQuery.where.isActive, true);
    assert.equal(recipientQuery.where.isDisabled, false);
    assert.deepEqual(recipientQuery.where.status, { in: ['PENDING', 'VERIFIED'] });
    assert.deepEqual(recipientQuery.select, { id: true, orgId: true });
    assert.deepEqual(recipientQuery.orderBy, { id: 'asc' });

    const notificationWrite = calls[2].args as {
        data: Array<Record<string, unknown>>;
    };
    assert.deepEqual(notificationWrite.data, [
        {
            orgId: organizationId,
            userId: recipientId,
            campaignId: result.campaignId,
            title: 'Service notice',
            body: 'Payroll will be briefly unavailable.',
            type: 'ANNOUNCEMENT',
            deepLink: '/app/notices',
        },
        {
            orgId: null,
            userId: secondRecipientId,
            campaignId: result.campaignId,
            title: 'Service notice',
            body: 'Payroll will be briefly unavailable.',
            type: 'ANNOUNCEMENT',
            deepLink: '/app/notices',
        },
    ]);

    const auditWrite = calls[3].args as {
        data: {
            action: string;
            entityType: string;
            entityId: string;
            changes: Record<string, unknown>;
            userId: string;
            orgId: string | null;
            requestId: string;
            ipAddress: string;
            userAgent: string;
        };
    };
    assert.equal(auditWrite.data.action, 'CREATE');
    assert.equal(auditWrite.data.entityType, 'AnnouncementCampaign');
    assert.equal(auditWrite.data.entityId, result.campaignId);
    assert.equal(auditWrite.data.userId, actorId);
    assert.equal(auditWrite.data.orgId, null);
    assert.equal(auditWrite.data.requestId, 'request-123');
    assert.equal(auditWrite.data.ipAddress, '203.0.113.10');
    assert.equal(auditWrite.data.userAgent, 'PayMuster-Test/1.0');
    assert.deepEqual(auditWrite.data.changes, {
        type: 'INFORMATION',
        audience: 'SYSTEM',
        orgId: null,
        audienceRole: null,
        audienceUserId: null,
        recipientCount: 2,
        deepLink: '/app/notices',
    });
});

test('organization dispatch validates the organization and scopes every recipient lookup to it', async () => {
    const calls: Array<{ operation: string; args: unknown }> = [];
    const transactionClient = {
        organization: {
            findFirst: async (args: unknown) => {
                calls.push({ operation: 'organization.findFirst', args });
                return { id: organizationId };
            },
        },
        user: {
            findMany: async (args: unknown) => {
                calls.push({ operation: 'user.findMany', args });
                return [{ id: recipientId, orgId: organizationId }];
            },
        },
        announcementCampaign: {
            create: async (args: unknown) => {
                calls.push({ operation: 'announcementCampaign.create', args });
                return {};
            },
        },
        notification: {
            createMany: async (args: unknown) => {
                calls.push({ operation: 'notification.createMany', args });
                return { count: 1 };
            },
        },
        auditLog: {
            create: async (args: unknown) => {
                calls.push({ operation: 'auditLog.create', args });
                return {};
            },
        },
    };
    mutablePrisma.$transaction = (async (
        callback: (tx: typeof transactionClient) => unknown,
    ) => callback(transactionClient)) as unknown as typeof prisma.$transaction;

    const result = await new AnnouncementService().dispatch(actorId, {
        audience: 'ORGANIZATION',
        type: 'INFORMATION',
        orgId: organizationId,
        title: 'Site notice',
        body: 'Attendance approval closes at 5 PM.',
    });

    assert.deepEqual(calls.map((call) => call.operation), [
        'organization.findFirst',
        'user.findMany',
        'announcementCampaign.create',
        'notification.createMany',
        'auditLog.create',
    ]);
    assert.equal(result.orgId, organizationId);
    assert.equal(result.recipientCount, 1);

    const organizationQuery = calls[0].args as { where: Record<string, unknown> };
    assert.deepEqual(organizationQuery.where, {
        id: organizationId,
        deletedAt: null,
        status: { not: 'DELETED' },
    });

    const recipientQuery = calls[1].args as { where: Record<string, unknown> };
    assert.equal(recipientQuery.where.orgId, organizationId);
    assert.equal(recipientQuery.where.isActive, true);
    assert.equal(recipientQuery.where.isDisabled, false);
    assert.equal(recipientQuery.where.deletedAt, null);
    assert.deepEqual(recipientQuery.where.status, { in: ['PENDING', 'VERIFIED'] });

    const notificationWrite = calls[3].args as {
        data: Array<{ userId: string; orgId: string }>;
    };
    assert.deepEqual(notificationWrite.data.map(({ userId, orgId }) => ({ userId, orgId })), [
        { userId: recipientId, orgId: organizationId },
    ]);
});

test('organization dispatch fails before recipient, notification, or audit access when the organization is unavailable', async () => {
    let sideEffectCount = 0;
    const transactionClient = {
        organization: { findFirst: async () => null },
        user: { findMany: async () => { sideEffectCount += 1; return []; } },
        notification: { createMany: async () => { sideEffectCount += 1; return {}; } },
        auditLog: { create: async () => { sideEffectCount += 1; return {}; } },
    };
    mutablePrisma.$transaction = (async (
        callback: (tx: typeof transactionClient) => unknown,
    ) => callback(transactionClient)) as unknown as typeof prisma.$transaction;

    await assert.rejects(
        new AnnouncementService().dispatch(actorId, {
            audience: 'ORGANIZATION',
            type: 'INFORMATION',
            orgId: organizationId,
            title: 'Unavailable organization',
            body: 'This must not be delivered.',
        }),
        (error) => assertAppError(error, { code: 'ORGANIZATION_NOT_FOUND', status: 404 }),
    );
    assert.equal(sideEffectCount, 0);
});

test('dispatch rollback leaves no committed notifications or audit evidence when the transaction fails', async () => {
    const committed: string[] = [];
    const staged: string[] = [];
    const transactionClient = {
        organization: { findFirst: async () => ({ id: organizationId }) },
        user: { findMany: async () => [{ id: recipientId, orgId: organizationId }] },
        announcementCampaign: {
            create: async () => {
                staged.push('campaign');
                return {};
            },
        },
        notification: {
            createMany: async () => {
                staged.push('notification');
                return { count: 1 };
            },
        },
        auditLog: {
            create: async () => {
                staged.push('audit');
                throw new Error('simulated audit persistence failure');
            },
        },
    };
    mutablePrisma.$transaction = (async (
        callback: (tx: typeof transactionClient) => unknown,
    ) => {
        try {
            const result = await callback(transactionClient);
            committed.push(...staged);
            return result;
        } catch (error) {
            staged.length = 0;
            throw error;
        }
    }) as unknown as typeof prisma.$transaction;

    await assert.rejects(
        new AnnouncementService().dispatch(actorId, {
            audience: 'ORGANIZATION',
            type: 'INFORMATION',
            orgId: organizationId,
            title: 'Atomic delivery',
            body: 'No partial campaign may survive.',
        }),
        /simulated audit persistence failure/,
    );
    assert.deepEqual(committed, []);
    assert.deepEqual(staged, []);
});

test('recipient listing is scoped to the authenticated user and returns bounded announcement fields', async () => {
    const calls: Array<{ operation: string; args: unknown }> = [];
    const createdAt = new Date('2026-08-17T12:00:00.000Z');
    notificationDelegate.findMany = (async (args: unknown) => {
        calls.push({ operation: 'notification.findMany', args });
        return [{
            id: announcementId,
            title: 'Service notice',
            body: 'Payroll will be briefly unavailable.',
            deepLink: '/app/notices',
            readAt: null,
            createdAt,
        }];
    }) as unknown as typeof prisma.notification.findMany;
    let countCall = 0;
    notificationDelegate.count = (async (args: unknown) => {
        calls.push({ operation: 'notification.count', args });
        countCall += 1;
        return countCall === 1 ? 1 : 1;
    }) as unknown as typeof prisma.notification.count;

    const result = await new AnnouncementService().listForRecipient(recipientId, 2, 25);

    assert.equal(result.total, 1);
    assert.equal(result.unread, 1);
    assert.equal(result.page, 2);
    assert.equal(result.totalPages, 1);
    assert.equal(result.announcements.length, 1);

    const listQuery = calls[0].args as {
        where: Record<string, unknown>;
        select: Record<string, boolean>;
        skip: number;
        take: number;
    };
    assert.deepEqual(listQuery.where, {
        userId: recipientId,
        type: 'ANNOUNCEMENT',
        deletedAt: null,
    });
    assert.deepEqual(listQuery.select, {
        id: true,
        title: true,
        body: true,
        type: true,
        deepLink: true,
        readAt: true,
        createdAt: true,
        campaignId: true,
        campaign: { select: { type: true } },
    });
    assert.equal(listQuery.skip, 25);
    assert.equal(listQuery.take, 25);

    const unreadQuery = calls[2].args as { where: Record<string, unknown> };
    assert.deepEqual(unreadQuery.where, {
        userId: recipientId,
        type: 'ANNOUNCEMENT',
        deletedAt: null,
        readAt: null,
    });
});

test('cross-user acknowledgement returns not found and writes no state or audit data', async () => {
    let sideEffectCount = 0;
    const transactionClient = {
        notification: {
            findFirst: async (args: unknown) => {
                const query = args as { where: Record<string, unknown> };
                assert.equal(query.where.userId, recipientId);
                assert.equal(query.where.id, announcementId);
                return null;
            },
            updateMany: async () => { sideEffectCount += 1; return { count: 0 }; },
        },
        auditLog: { create: async () => { sideEffectCount += 1; return {}; } },
    };
    mutablePrisma.$transaction = (async (
        callback: (tx: typeof transactionClient) => unknown,
    ) => callback(transactionClient)) as unknown as typeof prisma.$transaction;

    await assert.rejects(
        new AnnouncementService().acknowledge(recipientId, announcementId),
        (error) => assertAppError(error, { code: 'ANNOUNCEMENT_NOT_FOUND', status: 404 }),
    );
    assert.equal(sideEffectCount, 0);
});

test('first acknowledgement conditionally changes state and writes exactly one recipient audit', async () => {
    const calls: Array<{ operation: string; args: unknown }> = [];
    const transactionClient = {
        notification: {
            findFirst: async (args: unknown) => {
                calls.push({ operation: 'notification.findFirst', args });
                return { id: announcementId, orgId: organizationId, readAt: null };
            },
            updateMany: async (args: unknown) => {
                calls.push({ operation: 'notification.updateMany', args });
                return { count: 1 };
            },
        },
        auditLog: {
            create: async (args: unknown) => {
                calls.push({ operation: 'auditLog.create', args });
                return {};
            },
        },
    };
    mutablePrisma.$transaction = (async (
        callback: (tx: typeof transactionClient) => unknown,
    ) => callback(transactionClient)) as unknown as typeof prisma.$transaction;

    const result = await new AnnouncementService().acknowledge(
        recipientId,
        announcementId,
        {
            requestId: 'request-456',
            ipAddress: '203.0.113.11',
            userAgent: 'PayMuster-Test/1.0',
        },
    );

    assert.equal(result.changed, true);
    assert.ok(result.acknowledgedAt instanceof Date);
    assert.deepEqual(calls.map((call) => call.operation), [
        'notification.findFirst',
        'notification.updateMany',
        'auditLog.create',
    ]);

    const transition = calls[1].args as {
        where: Record<string, unknown>;
        data: { readAt: Date };
    };
    assert.deepEqual(transition.where, {
        id: announcementId,
        userId: recipientId,
        type: 'ANNOUNCEMENT',
        deletedAt: null,
        readAt: null,
    });
    assert.equal(transition.data.readAt, result.acknowledgedAt);

    const audit = calls[2].args as { data: Record<string, unknown> };
    assert.equal(audit.data.action, 'UPDATE');
    assert.equal(audit.data.entityType, 'Announcement');
    assert.equal(audit.data.entityId, announcementId);
    assert.equal(audit.data.userId, recipientId);
    assert.equal(audit.data.targetId, recipientId);
    assert.equal(audit.data.orgId, organizationId);
    assert.deepEqual(audit.data.changes, { acknowledged: true });
    assert.equal(audit.data.requestId, 'request-456');
});

test('repeated acknowledgement is side-effect free and returns the stored timestamp', async () => {
    const acknowledgedAt = new Date('2026-08-17T12:30:00.000Z');
    let sideEffectCount = 0;
    const transactionClient = {
        notification: {
            findFirst: async () => ({
                id: announcementId,
                orgId: organizationId,
                readAt: acknowledgedAt,
            }),
            updateMany: async () => { sideEffectCount += 1; return { count: 0 }; },
        },
        auditLog: { create: async () => { sideEffectCount += 1; return {}; } },
    };
    mutablePrisma.$transaction = (async (
        callback: (tx: typeof transactionClient) => unknown,
    ) => callback(transactionClient)) as unknown as typeof prisma.$transaction;

    const result = await new AnnouncementService().acknowledge(recipientId, announcementId);

    assert.equal(result.changed, false);
    assert.equal(result.acknowledgedAt, acknowledgedAt);
    assert.equal(sideEffectCount, 0);
});

test('a losing concurrent acknowledgement writes no audit and resolves to the winning timestamp', async () => {
    const winningTimestamp = new Date('2026-08-17T12:45:00.000Z');
    let findCount = 0;
    let auditCount = 0;
    const transactionClient = {
        notification: {
            findFirst: async () => {
                findCount += 1;
                if (findCount === 1) {
                    return { id: announcementId, orgId: organizationId, readAt: null };
                }
                return { readAt: winningTimestamp };
            },
            updateMany: async () => ({ count: 0 }),
        },
        auditLog: {
            create: async () => {
                auditCount += 1;
                return {};
            },
        },
    };
    mutablePrisma.$transaction = (async (
        callback: (tx: typeof transactionClient) => unknown,
    ) => callback(transactionClient)) as unknown as typeof prisma.$transaction;

    const result = await new AnnouncementService().acknowledge(recipientId, announcementId);

    assert.equal(result.changed, false);
    assert.equal(result.acknowledgedAt, winningTimestamp);
    assert.equal(findCount, 2);
    assert.equal(auditCount, 0);
});
